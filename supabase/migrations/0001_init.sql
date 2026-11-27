create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  avatar_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.meetings (
  id uuid primary key default gen_random_uuid(),
  code text unique not null check (code ~ '^[a-z]{3}-[a-z]{4}-[a-z]{3}$'),
  title text not null default 'Instant meeting',
  host_id uuid not null references public.profiles(id) on delete cascade,
  is_instant boolean not null default false,
  scheduled_at timestamptz,
  status text not null default 'scheduled' check (status in ('scheduled', 'live', 'ended')),
  created_at timestamptz not null default now()
);

create table if not exists public.meeting_participants (
  meeting_id uuid not null references public.meetings(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  is_muted boolean not null default false,
  is_camera_off boolean not null default false,
  hand_raised boolean not null default false,
  primary key (meeting_id, user_id)
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid not null references public.meetings(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(trim(body)) > 0),
  created_at timestamptz not null default now()
);

create index if not exists idx_meetings_host_id on public.meetings(host_id);
create index if not exists idx_meetings_scheduled_at on public.meetings(scheduled_at);
create index if not exists idx_meeting_participants_user_id on public.meeting_participants(user_id);
create index if not exists idx_chat_messages_meeting_created on public.chat_messages(meeting_id, created_at);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_display_name text;
begin
  v_display_name := nullif(trim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), '');
  if v_display_name is null then
    v_display_name := nullif(split_part(coalesce(new.email, ''), '@', 1), '');
  end if;

  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(v_display_name, 'User'),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.generate_meeting_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_chars constant text := 'abcdefghijklmnopqrstuvwxyz';
  v_code text;
  v_seg1 text;
  v_seg2 text;
  v_seg3 text;
  v_i integer;
begin
  loop
    v_seg1 := '';
    v_seg2 := '';
    v_seg3 := '';
    for v_i in 1..3 loop
      v_seg1 := v_seg1 || substr(v_chars, 1 + floor(random() * 26)::integer, 1);
      v_seg3 := v_seg3 || substr(v_chars, 1 + floor(random() * 26)::integer, 1);
    end loop;
    for v_i in 1..4 loop
      v_seg2 := v_seg2 || substr(v_chars, 1 + floor(random() * 26)::integer, 1);
    end loop;
    v_code := v_seg1 || '-' || v_seg2 || '-' || v_seg3;
    exit when not exists (select 1 from public.meetings where code = v_code);
  end loop;
  return v_code;
end;
$$;

create or replace function public.is_meeting_member(p_meeting_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.meeting_participants
    where meeting_id = p_meeting_id
      and user_id = p_user_id
  );
$$;

create or replace function public.is_active_meeting_member(p_meeting_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.meeting_participants
    where meeting_id = p_meeting_id
      and user_id = p_user_id
      and left_at is null
  );
$$;

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

  insert into public.meetings (code, title, host_id, is_instant, scheduled_at, status)
  values (
    v_code,
    coalesce(nullif(trim(create_meeting.title), ''), 'Instant meeting'),
    v_uid,
    create_meeting.is_instant,
    create_meeting.scheduled_at,
    case when create_meeting.is_instant then 'live' else 'scheduled' end
  )
  returning * into v_meeting;

  return v_meeting;
end;
$$;

create or replace function public.join_meeting(code text)
returns public.meetings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_code text;
  v_meeting public.meetings;
  v_active_count integer;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'not signed in';
  end if;

  v_code := lower(trim(join_meeting.code));

  select * into v_meeting
  from public.meetings m
  where m.code = v_code;

  if not found then
    raise exception 'meeting not found';
  end if;

  if v_meeting.status = 'ended' then
    raise exception 'meeting ended';
  end if;

  select count(*) into v_active_count
  from public.meeting_participants mp
  where mp.meeting_id = v_meeting.id
    and mp.left_at is null
    and mp.user_id <> v_uid;

  if v_active_count >= 5 then
    raise exception 'meeting full';
  end if;

  insert into public.meeting_participants (meeting_id, user_id, joined_at, left_at)
  values (v_meeting.id, v_uid, now(), null)
  on conflict (meeting_id, user_id) do update
    set joined_at = now(),
        left_at = null;

  if v_meeting.status = 'scheduled' then
    update public.meetings m
    set status = 'live'
    where m.id = v_meeting.id
    returning * into v_meeting;
  end if;

  return v_meeting;
end;
$$;

create or replace function public.leave_meeting(meeting_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_host_id uuid;
  v_remaining integer;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'not signed in';
  end if;

  update public.meeting_participants mp
  set left_at = now()
  where mp.meeting_id = leave_meeting.meeting_id
    and mp.user_id = v_uid;

  select m.host_id into v_host_id
  from public.meetings m
  where m.id = leave_meeting.meeting_id;

  select count(*) into v_remaining
  from public.meeting_participants mp
  where mp.meeting_id = leave_meeting.meeting_id
    and mp.left_at is null;

  if v_host_id = v_uid and v_remaining = 0 then
    update public.meetings m
    set status = 'ended'
    where m.id = leave_meeting.meeting_id;
  end if;
end;
$$;

alter table public.profiles enable row level security;
alter table public.meetings enable row level security;
alter table public.meeting_participants enable row level security;
alter table public.chat_messages enable row level security;

drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
  on public.profiles
  for select
  to authenticated
  using (true);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "meetings_select_host_or_participant" on public.meetings;
create policy "meetings_select_host_or_participant"
  on public.meetings
  for select
  to authenticated
  using (
    host_id = auth.uid()
    or public.is_meeting_member(id, auth.uid())
  );

drop policy if exists "meetings_update_host" on public.meetings;
create policy "meetings_update_host"
  on public.meetings
  for update
  to authenticated
  using (host_id = auth.uid())
  with check (host_id = auth.uid());

drop policy if exists "participants_select_meeting_members" on public.meeting_participants;
create policy "participants_select_meeting_members"
  on public.meeting_participants
  for select
  to authenticated
  using (public.is_meeting_member(meeting_id, auth.uid()));

drop policy if exists "participants_update_own" on public.meeting_participants;
create policy "participants_update_own"
  on public.meeting_participants
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "chat_select_active_participants" on public.chat_messages;
create policy "chat_select_active_participants"
  on public.chat_messages
  for select
  to authenticated
  using (public.is_active_meeting_member(meeting_id, auth.uid()));

drop policy if exists "chat_insert_active_participants" on public.chat_messages;
create policy "chat_insert_active_participants"
  on public.chat_messages
  for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and public.is_active_meeting_member(meeting_id, auth.uid())
  );

grant execute on function public.create_meeting(text, boolean, timestamptz) to authenticated;
grant execute on function public.join_meeting(text) to authenticated;
grant execute on function public.leave_meeting(uuid) to authenticated;

alter publication supabase_realtime add table public.meeting_participants;
alter publication supabase_realtime add table public.chat_messages;
