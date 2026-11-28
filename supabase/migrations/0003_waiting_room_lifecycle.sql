-- Enable pg_cron extension in Supabase Dashboard (Database -> Extensions) before running.

do $$
declare
  v_had_status boolean;
begin
  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'meeting_participants'
      and column_name = 'status'
  ) into v_had_status;

  if not v_had_status then
    alter table public.meeting_participants
      add column status text not null default 'waiting';
    update public.meeting_participants
      set status = 'admitted';
  end if;
end;
$$;

alter table public.meeting_participants
  drop constraint if exists meeting_participants_status_check;

alter table public.meeting_participants
  add constraint meeting_participants_status_check
  check (status in ('waiting', 'admitted', 'denied'));

alter table public.meeting_participants
  add column if not exists last_seen_at timestamptz not null default now();

alter table public.meetings
  add column if not exists ended_at timestamptz;

create index if not exists idx_meeting_participants_status_last_seen
  on public.meeting_participants(meeting_id, status, left_at, last_seen_at);

create index if not exists idx_meetings_status_ended_at
  on public.meetings(status, ended_at);

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'meetings'
  ) then
    alter publication supabase_realtime add table public.meetings;
  end if;
end;
$$;

drop policy if exists "meetings_select_member" on public.meetings;
drop policy if exists "meetings_update_host" on public.meetings;
drop policy if exists "participants_select_member" on public.meeting_participants;
drop policy if exists "participants_select_own" on public.meeting_participants;
drop policy if exists "participants_select_host" on public.meeting_participants;
drop policy if exists "participants_select_admitted" on public.meeting_participants;
drop policy if exists "participants_update_own" on public.meeting_participants;
drop policy if exists "chat_select_member" on public.chat_messages;
drop policy if exists "chat_insert_member" on public.chat_messages;

create or replace function public.is_meeting_host(m_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.meetings m
    where m.id = m_id
      and m.host_id = auth.uid()
  );
$$;

create or replace function public.is_meeting_member(m_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.meetings m
    where m.id = m_id
      and m.host_id = auth.uid()
  )
  or exists (
    select 1
    from public.meeting_participants mp
    where mp.meeting_id = m_id
      and mp.user_id = auth.uid()
      and mp.status = 'admitted'
      and mp.left_at is null
  );
$$;

grant execute on function public.is_meeting_host(uuid) to authenticated;
grant execute on function public.is_meeting_member(uuid) to authenticated;

create or replace function public.close_empty_meeting(m_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_instant boolean;
  v_status text;
  v_active_count integer;
begin
  select m.is_instant, m.status
  into v_is_instant, v_status
  from public.meetings m
  where m.id = m_id;

  if not found or v_status = 'ended' then
    return;
  end if;

  select count(*)
  into v_active_count
  from public.meeting_participants mp
  where mp.meeting_id = m_id
    and mp.status = 'admitted'
    and mp.left_at is null;

  if v_active_count > 0 then
    return;
  end if;

  if v_is_instant then
    update public.meetings m
    set status = 'ended',
        ended_at = now()
    where m.id = m_id;
  elsif v_status = 'live' then
    update public.meetings m
    set status = 'scheduled'
    where m.id = m_id;
  end if;
end;
$$;

create policy "meetings_select_member"
  on public.meetings
  for select
  to authenticated
  using (public.is_meeting_member(id));

create policy "meetings_update_host"
  on public.meetings
  for update
  to authenticated
  using (public.is_meeting_host(id))
  with check (public.is_meeting_host(id));

create policy "participants_select_own"
  on public.meeting_participants
  for select
  to authenticated
  using (user_id = auth.uid());

create policy "participants_select_host"
  on public.meeting_participants
  for select
  to authenticated
  using (public.is_meeting_host(meeting_id));

create policy "participants_select_admitted"
  on public.meeting_participants
  for select
  to authenticated
  using (
    public.is_meeting_member(meeting_id)
    and status = 'admitted'
  );

revoke update on table public.meeting_participants from authenticated;
grant update (is_muted, is_camera_off, hand_raised, last_seen_at)
  on table public.meeting_participants
  to authenticated;

create policy "participants_update_own"
  on public.meeting_participants
  for update
  to authenticated
  using (user_id = auth.uid() and status = 'admitted')
  with check (user_id = auth.uid() and status = 'admitted');

create policy "chat_select_member"
  on public.chat_messages
  for select
  to authenticated
  using (public.is_meeting_member(meeting_id));

create policy "chat_insert_member"
  on public.chat_messages
  for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and public.is_meeting_member(meeting_id)
  );

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

    if v_meeting.status <> 'live' then
      update public.meetings m
      set status = 'live'
      where m.id = v_meeting.id
      returning * into v_meeting;
    end if;

    v_participant_status := 'admitted';
  elsif v_existing.meeting_id is not null
    and v_existing.status = 'admitted'
    and v_existing.left_at is null then
    update public.meeting_participants mp
    set last_seen_at = now()
    where mp.meeting_id = v_meeting.id
      and mp.user_id = v_uid;

    if v_meeting.status = 'scheduled' then
      update public.meetings m
      set status = 'live'
      where m.id = v_meeting.id
      returning * into v_meeting;
    end if;

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
      'ended_at', v_meeting.ended_at
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
  set status = 'live'
  where m.id = p_meeting_id
    and m.status = 'scheduled';
end;
$$;

create or replace function public.deny_participant(p_meeting_id uuid, p_user_id uuid)
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
  set status = 'denied'
  where mp.meeting_id = p_meeting_id
    and mp.user_id = p_user_id;
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
  set status = 'live'
  where m.id = p_meeting_id
    and m.status = 'scheduled';
end;
$$;

create or replace function public.cancel_join_request(p_meeting_id uuid)
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

  delete from public.meeting_participants mp
  where mp.meeting_id = p_meeting_id
    and mp.user_id = v_uid
    and mp.status = 'waiting';
end;
$$;

drop function if exists public.leave_meeting(uuid);
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

  perform public.close_empty_meeting(p_meeting_id);
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
      ended_at = now()
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
end;
$$;

create or replace function public.cleanup_meetings_and_participants()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_meeting_id uuid;
begin
  update public.meeting_participants mp
  set left_at = now()
  where mp.status = 'admitted'
    and mp.left_at is null
    and mp.last_seen_at < now() - interval '90 seconds';

  delete from public.meeting_participants mp
  where mp.status = 'waiting'
    and coalesce(mp.last_seen_at, mp.joined_at) < now() - interval '10 minutes';

  for v_meeting_id in
    select m.id
    from public.meetings m
    where m.status = 'live'
      and not exists (
        select 1
        from public.meeting_participants mp
        where mp.meeting_id = m.id
          and mp.status = 'admitted'
          and mp.left_at is null
      )
  loop
    perform public.close_empty_meeting(v_meeting_id);
  end loop;

  update public.meetings m
  set status = 'ended',
      ended_at = now()
  where m.is_instant = true
    and m.status <> 'ended'
    and m.created_at < now() - interval '30 minutes'
    and not exists (
      select 1
      from public.meeting_participants mp
      where mp.meeting_id = m.id
        and mp.status = 'admitted'
    );

  update public.meetings m
  set status = 'ended',
      ended_at = now()
  where m.is_instant = false
    and m.status <> 'ended'
    and m.scheduled_at is not null
    and m.scheduled_at < now() - interval '24 hours';
end;
$$;

grant execute on function public.get_meeting_preview(text) to authenticated;
grant execute on function public.request_join(text) to authenticated;
grant execute on function public.admit_participant(uuid, uuid) to authenticated;
grant execute on function public.deny_participant(uuid, uuid) to authenticated;
grant execute on function public.admit_all_waiting(uuid) to authenticated;
grant execute on function public.cancel_join_request(uuid) to authenticated;
grant execute on function public.leave_meeting(uuid) to authenticated;
grant execute on function public.end_meeting(uuid) to authenticated;
grant execute on function public.heartbeat(uuid) to authenticated;

do $$
declare
  v_job_id bigint;
begin
  for v_job_id in
    select jobid
    from cron.job
    where jobname in ('meet_clone_minute_cleanup', 'meet_clone_daily_purge')
  loop
    perform cron.unschedule(v_job_id);
  end loop;

  perform cron.schedule(
    'meet_clone_minute_cleanup',
    '* * * * *',
    $cmd$select public.cleanup_meetings_and_participants();$cmd$
  );

  perform cron.schedule(
    'meet_clone_daily_purge',
    '0 3 * * *',
    $cmd$delete from public.meetings where status = 'ended' and ended_at is not null and ended_at < now() - interval '7 days';$cmd$
  );
end;
$$;

select tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
order by tablename, policyname;
