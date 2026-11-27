grant usage on schema public to anon, authenticated;

revoke all on table
  public.profiles,
  public.meetings,
  public.meeting_participants,
  public.chat_messages
from anon;

grant select, insert, update, delete on table
  public.profiles,
  public.meetings,
  public.meeting_participants,
  public.chat_messages
to authenticated;

grant execute on function public.generate_meeting_code() to authenticated;
grant execute on function public.create_meeting(text, boolean, timestamptz) to authenticated;
grant execute on function public.join_meeting(text) to authenticated;
grant execute on function public.leave_meeting(uuid) to authenticated;

drop policy if exists "meetings_select_host_or_participant" on public.meetings;
drop policy if exists "meetings_select_member" on public.meetings;
drop policy if exists "meetings_update_host" on public.meetings;
drop policy if exists "participants_select_meeting_members" on public.meeting_participants;
drop policy if exists "participants_select_member" on public.meeting_participants;
drop policy if exists "participants_update_own" on public.meeting_participants;
drop policy if exists "chat_select_active_participants" on public.chat_messages;
drop policy if exists "chat_select_member" on public.chat_messages;
drop policy if exists "chat_insert_active_participants" on public.chat_messages;
drop policy if exists "chat_insert_member" on public.chat_messages;

drop function if exists public.is_meeting_member(uuid, uuid);
drop function if exists public.is_active_meeting_member(uuid, uuid);

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
  );
$$;

grant execute on function public.is_meeting_member(uuid) to authenticated;

create policy "meetings_select_member"
  on public.meetings
  for select
  to authenticated
  using (public.is_meeting_member(id));

create policy "meetings_update_host"
  on public.meetings
  for update
  to authenticated
  using (host_id = auth.uid())
  with check (host_id = auth.uid());

create policy "participants_select_member"
  on public.meeting_participants
  for select
  to authenticated
  using (public.is_meeting_member(meeting_id));

create policy "participants_update_own"
  on public.meeting_participants
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

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

select tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
order by tablename, policyname;
