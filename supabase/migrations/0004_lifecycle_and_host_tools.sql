do $$
declare
  v_job_id bigint;
begin
  for v_job_id in
    select jobid
    from cron.job
    where jobname in (
      'meet_clone_minute_cleanup',
      'meet_clone_daily_purge',
      'meet_clone_inactivity_cleanup'
    )
  loop
    perform cron.unschedule(v_job_id);
  end loop;
end;
$$;

alter table public.meetings
  add column if not exists last_activity_at timestamptz not null default now();

create index if not exists idx_meetings_last_activity
  on public.meetings(status, last_activity_at, scheduled_at);

drop function if exists public.close_empty_meeting(uuid);

create or replace function public.create_meeting(
  title text,
  is_instant boolean default false,
  scheduled_at timestamptz default null
)
returns public.meetings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_code text;
  v_meeting public.meetings;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'not signed in';
  end if;

  v_code := public.generate_meeting_code();

  insert into public.meetings (
    code,
    title,
    host_id,
    is_instant,
    scheduled_at,
    status,
    last_activity_at
  )
  values (
    v_code,
    coalesce(nullif(trim(create_meeting.title), ''), 'Instant meeting'),
    v_uid,
    create_meeting.is_instant,
    create_meeting.scheduled_at,
    case when create_meeting.is_instant then 'live' else 'scheduled' end,
    now()
  )
  returning * into v_meeting;

  return v_meeting;
end;
$$;

create or replace function public.get_meeting_preview(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_code text;
  v_meeting public.meetings;
  v_host_name text;
  v_host_in_call boolean;
  v_participants jsonb;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'not signed in';
  end if;

  v_code := lower(trim(p_code));

  select m.*
  into v_meeting
  from public.meetings m
  where m.code = v_code;

  if not found then
    raise exception 'MEETING_NOT_FOUND';
  end if;

  if v_meeting.status = 'ended' then
    raise exception 'MEETING_ENDED';
  end if;

  select coalesce(p.display_name, 'Host')
  into v_host_name
  from public.profiles p
  where p.id = v_meeting.host_id;

  select exists (
    select 1
    from public.meeting_participants mp
    where mp.meeting_id = v_meeting.id
      and mp.user_id = v_meeting.host_id
      and mp.status = 'admitted'
      and mp.left_at is null
  )
  into v_host_in_call;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'display_name', coalesce(p.display_name, 'Participant'),
        'avatar_url', p.avatar_url
      )
      order by mp.joined_at asc
    ),
    '[]'::jsonb
  )
  into v_participants
  from public.meeting_participants mp
  join public.profiles p on p.id = mp.user_id
  where mp.meeting_id = v_meeting.id
    and mp.status = 'admitted'
    and mp.left_at is null
    and mp.user_id <> v_uid;

  return jsonb_build_object(
    'id', v_meeting.id,
    'code', v_meeting.code,
    'title', v_meeting.title,
    'status', v_meeting.status,
    'host_id', v_meeting.host_id,
    'host_name', coalesce(v_host_name, 'Host'),
    'host_in_call', coalesce(v_host_in_call, false),
    'is_instant', v_meeting.is_instant,
    'scheduled_at', v_meeting.scheduled_at,
    'created_at', v_meeting.created_at,
    'preview_participants', v_participants
  );
end;
$$;

create or replace function public.request_join(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_code text;
  v_meeting public.meetings;
  v_existing public.meeting_participants;
  v_active_count integer;
  v_host_name text;
  v_participant_status text;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'not signed in';
  end if;

  v_code := lower(trim(p_code));

  select m.*
  into v_meeting
  from public.meetings m
  where m.code = v_code;

  if not found then
    raise exception 'MEETING_NOT_FOUND';
  end if;

  if v_meeting.status = 'ended' then
    raise exception 'MEETING_ENDED';
  end if;

  select coalesce(p.display_name, 'Host')
  into v_host_name
  from public.profiles p
  where p.id = v_meeting.host_id;

  select mp.*
  into v_existing
  from public.meeting_participants mp
  where mp.meeting_id = v_meeting.id
    and mp.user_id = v_uid;

  if v_meeting.host_id = v_uid then
    insert into public.meeting_participants (
      meeting_id, user_id, status, joined_at, left_at, last_seen_at
    )
    values (
      v_meeting.id, v_uid, 'admitted', now(), null, now()
    )
    on conflict (meeting_id, user_id) do update
      set status = 'admitted',
          joined_at = now(),
          left_at = null,
          last_seen_at = now();

    update public.meetings m
    set status = 'live',
        last_activity_at = now()
    where m.id = v_meeting.id
    returning * into v_meeting;

    v_participant_status := 'admitted';
  elsif v_existing.meeting_id is not null
    and v_existing.status = 'admitted'
    and v_existing.left_at is null then
    update public.meeting_participants mp
    set last_seen_at = now()
    where mp.meeting_id = v_meeting.id
      and mp.user_id = v_uid;

    update public.meetings m
    set status = case when m.status = 'scheduled' then 'live' else m.status end,
        last_activity_at = now()
    where m.id = v_meeting.id
    returning * into v_meeting;

    v_participant_status := 'admitted';
  else
    select count(*)
    into v_active_count
    from public.meeting_participants mp
    where mp.meeting_id = v_meeting.id
      and mp.status = 'admitted'
      and mp.left_at is null
      and mp.user_id <> v_uid;

    if v_active_count >= 5 then
      raise exception 'MEETING_FULL';
    end if;

    insert into public.meeting_participants (
      meeting_id, user_id, status, joined_at, left_at, last_seen_at
    )
    values (
      v_meeting.id, v_uid, 'waiting', now(), null, now()
    )
    on conflict (meeting_id, user_id) do update
      set status = 'waiting',
          joined_at = now(),
          left_at = null,
          last_seen_at = now();

    update public.meetings m
    set last_activity_at = now()
    where m.id = v_meeting.id
    returning * into v_meeting;

    v_participant_status := 'waiting';
  end if;

  return jsonb_build_object(
    'participant_status', v_participant_status,
    'meeting', jsonb_build_object(
      'id', v_meeting.id,
      'code', v_meeting.code,
      'title', v_meeting.title,
      'host_id', v_meeting.host_id,
      'host_name', coalesce(v_host_name, 'Host'),
      'is_instant', v_meeting.is_instant,
      'scheduled_at', v_meeting.scheduled_at,
      'status', v_meeting.status,
      'created_at', v_meeting.created_at,
      'ended_at', v_meeting.ended_at,
      'last_activity_at', v_meeting.last_activity_at
    )
  );
end;
$$;

create or replace function public.admit_participant(p_meeting_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_active_count integer;
begin
  if not public.is_meeting_host(p_meeting_id) then
    raise exception 'NOT_HOST';
  end if;

  select count(*)
  into v_active_count
  from public.meeting_participants mp
  where mp.meeting_id = p_meeting_id
    and mp.status = 'admitted'
    and mp.left_at is null
    and mp.user_id <> p_user_id;

  if v_active_count >= 5 then
    raise exception 'MEETING_FULL';
  end if;

  update public.meeting_participants mp
  set status = 'admitted',
      joined_at = now(),
      left_at = null,
      last_seen_at = now()
  where mp.meeting_id = p_meeting_id
    and mp.user_id = p_user_id;

  update public.meetings m
  set status = case when m.status = 'scheduled' then 'live' else m.status end,
      last_activity_at = now()
  where m.id = p_meeting_id;
end;
$$;

create or replace function public.admit_all_waiting(p_meeting_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_active_count integer;
  v_slots integer;
begin
  if not public.is_meeting_host(p_meeting_id) then
    raise exception 'NOT_HOST';
  end if;

  select count(*)
  into v_active_count
  from public.meeting_participants mp
  where mp.meeting_id = p_meeting_id
    and mp.status = 'admitted'
    and mp.left_at is null;

  v_slots := greatest(0, 5 - v_active_count);
  if v_slots = 0 then
    return;
  end if;

  update public.meeting_participants mp
  set status = 'admitted',
      joined_at = now(),
      left_at = null,
      last_seen_at = now()
  where mp.meeting_id = p_meeting_id
    and mp.user_id in (
      select w.user_id
      from public.meeting_participants w
      where w.meeting_id = p_meeting_id
        and w.status = 'waiting'
        and w.left_at is null
      order by w.joined_at asc
      limit v_slots
    );

  update public.meetings m
  set status = case when m.status = 'scheduled' then 'live' else m.status end,
      last_activity_at = now()
  where m.id = p_meeting_id;
end;
$$;

create or replace function public.leave_meeting(p_meeting_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'not signed in';
  end if;

  update public.meeting_participants mp
  set left_at = now()
  where mp.meeting_id = p_meeting_id
    and mp.user_id = v_uid
    and mp.status = 'admitted'
    and mp.left_at is null;

  update public.meetings m
  set last_activity_at = now()
  where m.id = p_meeting_id;
end;
$$;

create or replace function public.end_meeting(p_meeting_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_meeting_host(p_meeting_id) then
    raise exception 'NOT_HOST';
  end if;

  update public.meetings m
  set status = 'ended',
      ended_at = now(),
      last_activity_at = now()
  where m.id = p_meeting_id;

  update public.meeting_participants mp
  set left_at = now()
  where mp.meeting_id = p_meeting_id
    and mp.status = 'admitted'
    and mp.left_at is null;

  delete from public.meeting_participants mp
  where mp.meeting_id = p_meeting_id
    and mp.status = 'waiting';
end;
$$;

create or replace function public.heartbeat(p_meeting_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'not signed in';
  end if;

  update public.meeting_participants mp
  set last_seen_at = now()
  where mp.meeting_id = p_meeting_id
    and mp.user_id = v_uid
    and mp.status = 'admitted'
    and mp.left_at is null;

  update public.meetings m
  set last_activity_at = now()
  where m.id = p_meeting_id;
end;
$$;

create or replace function public.host_mute_participant(p_meeting_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_meeting_host(p_meeting_id) then
    raise exception 'NOT_HOST';
  end if;

  update public.meeting_participants mp
  set is_muted = true
  where mp.meeting_id = p_meeting_id
    and mp.user_id = p_user_id
    and mp.user_id <> auth.uid()
    and mp.status = 'admitted'
    and mp.left_at is null;
end;
$$;

create or replace function public.remove_participant(p_meeting_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_meeting_host(p_meeting_id) then
    raise exception 'NOT_HOST';
  end if;

  update public.meeting_participants mp
  set status = 'denied',
      left_at = now()
  where mp.meeting_id = p_meeting_id
    and mp.user_id = p_user_id
    and mp.user_id <> auth.uid()
    and mp.status = 'admitted'
    and mp.left_at is null;
end;
$$;

create or replace function public.my_open_meetings()
returns table (
  id uuid,
  code text,
  title text,
  status text,
  is_instant boolean,
  scheduled_at timestamptz,
  created_at timestamptz,
  last_activity_at timestamptz,
  host_id uuid,
  host_name text,
  host_in_call boolean,
  active_participant_count bigint,
  am_i_host boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    m.id,
    m.code,
    m.title,
    m.status,
    m.is_instant,
    m.scheduled_at,
    m.created_at,
    m.last_activity_at,
    m.host_id,
    coalesce(p.display_name, 'Host') as host_name,
    exists (
      select 1
      from public.meeting_participants hmp
      where hmp.meeting_id = m.id
        and hmp.user_id = m.host_id
        and hmp.status = 'admitted'
        and hmp.left_at is null
    ) as host_in_call,
    (
      select count(*)
      from public.meeting_participants amp
      where amp.meeting_id = m.id
        and amp.status = 'admitted'
        and amp.left_at is null
    ) as active_participant_count,
    (m.host_id = auth.uid()) as am_i_host
  from public.meetings m
  left join public.profiles p on p.id = m.host_id
  where auth.uid() is not null
    and m.status in ('live', 'scheduled')
    and (
      m.host_id = auth.uid()
      or exists (
        select 1
        from public.meeting_participants mp
        where mp.meeting_id = m.id
          and mp.user_id = auth.uid()
          and mp.status = 'admitted'
      )
    )
  order by m.scheduled_at asc nulls last, m.created_at desc;
$$;

create or replace function public.cleanup_meetings_and_participants()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.meeting_participants mp
  set left_at = now()
  where mp.status = 'admitted'
    and mp.left_at is null
    and mp.last_seen_at < now() - interval '90 seconds';

  delete from public.meeting_participants mp
  where mp.status = 'waiting'
    and coalesce(mp.last_seen_at, mp.joined_at) < now() - interval '10 minutes';
end;
$$;

create or replace function public.cleanup_inactive_meetings()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.meetings m
  set status = 'ended',
      ended_at = now()
  where m.status <> 'ended'
    and not exists (
      select 1
      from public.meeting_participants mp
      where mp.meeting_id = m.id
        and mp.status = 'admitted'
        and mp.left_at is null
    )
    and greatest(
      coalesce(m.last_activity_at, m.created_at),
      coalesce(m.scheduled_at, m.last_activity_at, m.created_at)
    ) < now() - interval '24 hours';
end;
$$;

grant execute on function public.create_meeting(text, boolean, timestamptz) to authenticated;
grant execute on function public.get_meeting_preview(text) to authenticated;
grant execute on function public.request_join(text) to authenticated;
grant execute on function public.admit_participant(uuid, uuid) to authenticated;
grant execute on function public.admit_all_waiting(uuid) to authenticated;
grant execute on function public.leave_meeting(uuid) to authenticated;
grant execute on function public.end_meeting(uuid) to authenticated;
grant execute on function public.heartbeat(uuid) to authenticated;
grant execute on function public.host_mute_participant(uuid, uuid) to authenticated;
grant execute on function public.remove_participant(uuid, uuid) to authenticated;
grant execute on function public.my_open_meetings() to authenticated;

do $$
begin
  perform cron.schedule(
    'meet_clone_minute_cleanup',
    '* * * * *',
    $cmd$select public.cleanup_meetings_and_participants();$cmd$
  );

  perform cron.schedule(
    'meet_clone_inactivity_cleanup',
    '*/10 * * * *',
    $cmd$select public.cleanup_inactive_meetings();$cmd$
  );

  perform cron.schedule(
    'meet_clone_daily_purge',
    '0 3 * * *',
    $cmd$delete from public.meetings where status = 'ended' and ended_at is not null and ended_at < now() - interval '7 days';$cmd$
  );
end;
$$;
