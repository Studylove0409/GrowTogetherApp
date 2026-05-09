create table if not exists public.focus_sessions (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples (id) on delete restrict,
  plan_id uuid not null references public.plans (id) on delete restrict,
  plan_title text not null check (char_length(trim(plan_title)) > 0),
  created_by_user_id uuid not null references auth.users (id) on delete cascade,
  mode text not null check (mode in ('solo', 'couple')),
  planned_duration_minutes integer not null check (
    planned_duration_minutes between 1 and 180
  ),
  actual_duration_seconds integer not null default 0 check (
    actual_duration_seconds >= 0
  ),
  status text not null default 'waiting' check (
    status in ('waiting', 'running', 'paused', 'completed', 'cancelled', 'interrupted')
  ),
  score_delta integer not null default 0 check (score_delta >= 0),
  creator_joined_at timestamptz not null default now(),
  partner_joined_at timestamptz,
  started_at timestamptz,
  paused_at timestamptz,
  total_paused_seconds integer not null default 0 check (
    total_paused_seconds >= 0
  ),
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint focus_sessions_started_at_required check (
    status in ('waiting', 'cancelled') or started_at is not null
  ),
  constraint focus_sessions_ended_at_required check (
    (status in ('completed', 'cancelled', 'interrupted') and ended_at is not null)
    or (status in ('waiting', 'running', 'paused') and ended_at is null)
  ),
  constraint focus_sessions_pause_shape check (
    (status = 'paused' and paused_at is not null)
    or (status <> 'paused')
  )
);

create index if not exists focus_sessions_couple_created_idx
  on public.focus_sessions (couple_id, created_at desc);

create index if not exists focus_sessions_plan_created_idx
  on public.focus_sessions (plan_id, created_at desc);

create trigger focus_sessions_touch_updated_at
before update on public.focus_sessions
for each row execute function private.touch_updated_at();

create or replace function private.validate_focus_session_write()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  plan_row public.plans%rowtype;
begin
  select *
  into plan_row
  from public.plans p
  where p.id = new.plan_id;

  if plan_row.id is null or plan_row.status <> 'active' then
    raise exception 'focus sessions can only be linked to an active plan';
  end if;

  if plan_row.couple_id <> new.couple_id then
    raise exception 'focus session couple_id must match plan';
  end if;

  if not private.is_active_couple_member(new.couple_id, new.created_by_user_id) then
    raise exception 'focus session creator must belong to the active couple';
  end if;

  if not private.can_checkin_plan(new.plan_id, new.created_by_user_id) then
    raise exception 'user cannot focus for this plan';
  end if;

  if tg_op = 'UPDATE' then
    if old.status in ('completed', 'cancelled', 'interrupted') then
      raise exception 'finished focus sessions cannot be changed';
    end if;

    if new.id <> old.id
      or new.couple_id <> old.couple_id
      or new.plan_id <> old.plan_id
      or new.plan_title <> old.plan_title
      or new.created_by_user_id <> old.created_by_user_id
      or new.mode <> old.mode
      or new.planned_duration_minutes <> old.planned_duration_minutes
      or new.creator_joined_at <> old.creator_joined_at
      or new.created_at <> old.created_at
    then
      raise exception 'focus session identity fields cannot be changed';
    end if;
  end if;

  return new;
end;
$$;

create trigger focus_sessions_validate_write
before insert or update on public.focus_sessions
for each row execute function private.validate_focus_session_write();

alter table public.focus_sessions enable row level security;

create policy "Focus sessions are visible to couple members"
on public.focus_sessions for select
to authenticated
using (
  (select auth.uid()) is not null
  and private.is_active_couple_member(couple_id, (select auth.uid()))
);

create policy "Users can create focus sessions for their plans"
on public.focus_sessions for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and created_by_user_id = (select auth.uid())
  and private.is_active_couple_member(couple_id, (select auth.uid()))
  and private.can_checkin_plan(plan_id, (select auth.uid()))
);

create policy "Couple members can update active focus sessions"
on public.focus_sessions for update
to authenticated
using (
  (select auth.uid()) is not null
  and private.is_active_couple_member(couple_id, (select auth.uid()))
  and status in ('waiting', 'running', 'paused')
)
with check (
  private.is_active_couple_member(couple_id, (select auth.uid()))
);

grant select, insert, update on public.focus_sessions to authenticated;

create or replace function private.focus_actual_seconds(
  p_started_at timestamptz,
  p_paused_at timestamptz,
  p_ended_at timestamptz,
  p_total_paused_seconds integer,
  p_status text
)
returns integer
language plpgsql
stable
as $$
declare
  effective_end timestamptz;
  elapsed_seconds integer;
begin
  if p_started_at is null then
    return 0;
  end if;

  effective_end := case
    when p_status = 'paused' then coalesce(p_paused_at, now())
    else coalesce(p_ended_at, now())
  end;

  elapsed_seconds := floor(extract(epoch from effective_end - p_started_at))::integer
    - coalesce(p_total_paused_seconds, 0);

  return greatest(elapsed_seconds, 0);
end;
$$;

create or replace function private.focus_score_delta(
  p_status text,
  p_actual_duration_seconds integer
)
returns integer
language sql
immutable
as $$
  select case
    when p_status = 'completed' and p_actual_duration_seconds >= 300 then 5
    else 0
  end;
$$;

create or replace function private.create_focus_invite(
  p_plan_id uuid,
  p_planned_duration_minutes integer
)
returns public.focus_sessions
language plpgsql
security definer
set search_path = public, private
as $$
declare
  current_user_id uuid := auth.uid();
  plan_row public.plans%rowtype;
  session_row public.focus_sessions%rowtype;
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  if p_planned_duration_minutes < 1 or p_planned_duration_minutes > 180 then
    raise exception 'planned duration must be between 1 and 180 minutes';
  end if;

  select *
  into plan_row
  from public.plans p
  where p.id = p_plan_id;

  if plan_row.id is null or plan_row.status <> 'active' then
    raise exception 'focus sessions can only be linked to an active plan';
  end if;

  if not private.can_checkin_plan(p_plan_id, current_user_id) then
    raise exception 'user cannot focus for this plan';
  end if;

  insert into public.focus_sessions (
    couple_id,
    plan_id,
    plan_title,
    created_by_user_id,
    mode,
    planned_duration_minutes,
    actual_duration_seconds,
    status,
    score_delta,
    creator_joined_at
  )
  values (
    plan_row.couple_id,
    p_plan_id,
    plan_row.title,
    current_user_id,
    'couple',
    p_planned_duration_minutes,
    0,
    'waiting',
    0,
    now()
  )
  returning * into session_row;

  return session_row;
end;
$$;

create or replace function public.create_focus_invite(
  p_plan_id uuid,
  p_planned_duration_minutes integer
)
returns public.focus_sessions
language sql
security invoker
set search_path = public, private
as $$
  select private.create_focus_invite(p_plan_id, p_planned_duration_minutes);
$$;

create or replace function private.join_focus_session(p_session_id uuid)
returns public.focus_sessions
language plpgsql
security definer
set search_path = public, private
as $$
declare
  current_user_id uuid := auth.uid();
  session_row public.focus_sessions%rowtype;
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  select *
  into session_row
  from public.focus_sessions fs
  where fs.id = p_session_id
  for update;

  if session_row.id is null then
    raise exception 'focus session not found';
  end if;

  if not private.is_active_couple_member(session_row.couple_id, current_user_id) then
    raise exception 'user cannot join this focus session';
  end if;

  if session_row.created_by_user_id = current_user_id then
    raise exception 'creator has already joined this focus session';
  end if;

  if session_row.status not in ('waiting', 'running', 'paused') then
    raise exception 'focus session is not joinable';
  end if;

  if session_row.partner_joined_at is not null then
    return session_row;
  end if;

  update public.focus_sessions
  set
    partner_joined_at = now(),
    status = case when started_at is null then 'running' else status end,
    started_at = coalesce(started_at, now()),
    paused_at = case when started_at is null then null else paused_at end
  where id = p_session_id
  returning * into session_row;

  return session_row;
end;
$$;

create or replace function public.join_focus_session(p_session_id uuid)
returns public.focus_sessions
language sql
security invoker
set search_path = public, private
as $$
  select private.join_focus_session(p_session_id);
$$;

create or replace function private.start_focus_session(p_session_id uuid)
returns public.focus_sessions
language plpgsql
security definer
set search_path = public, private
as $$
declare
  current_user_id uuid := auth.uid();
  session_row public.focus_sessions%rowtype;
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  select *
  into session_row
  from public.focus_sessions fs
  where fs.id = p_session_id
  for update;

  if session_row.id is null then
    raise exception 'focus session not found';
  end if;

  if session_row.status <> 'waiting' then
    raise exception 'only waiting focus sessions can be started';
  end if;

  if not private.is_active_couple_member(session_row.couple_id, current_user_id) then
    raise exception 'user cannot start this focus session';
  end if;

  update public.focus_sessions
  set
    status = 'running',
    started_at = now(),
    paused_at = null
  where id = p_session_id
  returning * into session_row;

  return session_row;
end;
$$;

create or replace function public.start_focus_session(p_session_id uuid)
returns public.focus_sessions
language sql
security invoker
set search_path = public, private
as $$
  select private.start_focus_session(p_session_id);
$$;

create or replace function private.pause_focus_session(p_session_id uuid)
returns public.focus_sessions
language plpgsql
security definer
set search_path = public, private
as $$
declare
  current_user_id uuid := auth.uid();
  session_row public.focus_sessions%rowtype;
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  select *
  into session_row
  from public.focus_sessions fs
  where fs.id = p_session_id
  for update;

  if session_row.id is null then
    raise exception 'focus session not found';
  end if;

  if not private.is_active_couple_member(session_row.couple_id, current_user_id) then
    raise exception 'user cannot pause this focus session';
  end if;

  if session_row.status <> 'running' then
    raise exception 'only running focus sessions can be paused';
  end if;

  update public.focus_sessions
  set status = 'paused',
      paused_at = now()
  where id = p_session_id
  returning * into session_row;

  return session_row;
end;
$$;

create or replace function public.pause_focus_session(p_session_id uuid)
returns public.focus_sessions
language sql
security invoker
set search_path = public, private
as $$
  select private.pause_focus_session(p_session_id);
$$;

create or replace function private.resume_focus_session(p_session_id uuid)
returns public.focus_sessions
language plpgsql
security definer
set search_path = public, private
as $$
declare
  current_user_id uuid := auth.uid();
  session_row public.focus_sessions%rowtype;
  paused_seconds integer;
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  select *
  into session_row
  from public.focus_sessions fs
  where fs.id = p_session_id
  for update;

  if session_row.id is null then
    raise exception 'focus session not found';
  end if;

  if not private.is_active_couple_member(session_row.couple_id, current_user_id) then
    raise exception 'user cannot resume this focus session';
  end if;

  if session_row.status <> 'paused' or session_row.paused_at is null then
    raise exception 'only paused focus sessions can be resumed';
  end if;

  paused_seconds := floor(extract(epoch from now() - session_row.paused_at))::integer;

  update public.focus_sessions
  set
    status = 'running',
    paused_at = null,
    total_paused_seconds = total_paused_seconds + greatest(paused_seconds, 0)
  where id = p_session_id
  returning * into session_row;

  return session_row;
end;
$$;

create or replace function public.resume_focus_session(p_session_id uuid)
returns public.focus_sessions
language sql
security invoker
set search_path = public, private
as $$
  select private.resume_focus_session(p_session_id);
$$;

create or replace function private.finish_focus_session(
  p_session_id uuid,
  p_status text
)
returns public.focus_sessions
language plpgsql
security definer
set search_path = public, private
as $$
declare
  current_user_id uuid := auth.uid();
  session_row public.focus_sessions%rowtype;
  actual_seconds integer;
  final_score integer;
  ended_at_value timestamptz := now();
  final_status text := p_status;
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  if final_status not in ('completed', 'cancelled', 'interrupted') then
    raise exception 'invalid final focus session status';
  end if;

  select *
  into session_row
  from public.focus_sessions fs
  where fs.id = p_session_id
  for update;

  if session_row.id is null then
    raise exception 'focus session not found';
  end if;

  if not private.is_active_couple_member(session_row.couple_id, current_user_id) then
    raise exception 'user cannot finish this focus session';
  end if;

  if session_row.status not in ('waiting', 'running', 'paused') then
    return session_row;
  end if;

  actual_seconds := case
    when final_status = 'completed'
      then session_row.planned_duration_minutes * 60
    else private.focus_actual_seconds(
      session_row.started_at,
      session_row.paused_at,
      ended_at_value,
      session_row.total_paused_seconds,
      session_row.status
    )
  end;
  final_score := private.focus_score_delta(final_status, actual_seconds);

  update public.focus_sessions
  set
    status = final_status,
    actual_duration_seconds = actual_seconds,
    score_delta = final_score,
    ended_at = ended_at_value,
    paused_at = null
  where id = p_session_id
  returning * into session_row;

  return session_row;
end;
$$;

create or replace function public.finish_focus_session(
  p_session_id uuid,
  p_status text
)
returns public.focus_sessions
language sql
security invoker
set search_path = public, private
as $$
  select private.finish_focus_session(p_session_id, p_status);
$$;

create or replace function private.create_completed_focus_session(
  p_plan_id uuid,
  p_mode text,
  p_planned_duration_minutes integer,
  p_actual_duration_seconds integer,
  p_started_at timestamptz,
  p_ended_at timestamptz,
  p_status text
)
returns public.focus_sessions
language plpgsql
security definer
set search_path = public, private
as $$
declare
  current_user_id uuid := auth.uid();
  plan_row public.plans%rowtype;
  session_row public.focus_sessions%rowtype;
  final_status text := p_status;
  final_actual_seconds integer;
  final_score integer;
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  if p_mode not in ('solo', 'couple') then
    raise exception 'invalid focus mode';
  end if;

  if final_status not in ('completed', 'cancelled', 'interrupted') then
    raise exception 'invalid final focus session status';
  end if;

  if p_planned_duration_minutes < 1 or p_planned_duration_minutes > 180 then
    raise exception 'planned duration must be between 1 and 180 minutes';
  end if;

  select *
  into plan_row
  from public.plans p
  where p.id = p_plan_id;

  if plan_row.id is null or plan_row.status <> 'active' then
    raise exception 'focus sessions can only be linked to an active plan';
  end if;

  if not private.can_checkin_plan(p_plan_id, current_user_id) then
    raise exception 'user cannot focus for this plan';
  end if;

  final_actual_seconds := greatest(coalesce(p_actual_duration_seconds, 0), 0);
  final_score := private.focus_score_delta(final_status, final_actual_seconds);

  insert into public.focus_sessions (
    couple_id,
    plan_id,
    plan_title,
    created_by_user_id,
    mode,
    planned_duration_minutes,
    actual_duration_seconds,
    status,
    score_delta,
    creator_joined_at,
    started_at,
    ended_at
  )
  values (
    plan_row.couple_id,
    p_plan_id,
    plan_row.title,
    current_user_id,
    p_mode,
    p_planned_duration_minutes,
    final_actual_seconds,
    final_status,
    final_score,
    coalesce(p_started_at, now()),
    p_started_at,
    coalesce(p_ended_at, now())
  )
  returning * into session_row;

  return session_row;
end;
$$;

create or replace function public.create_completed_focus_session(
  p_plan_id uuid,
  p_mode text,
  p_planned_duration_minutes integer,
  p_actual_duration_seconds integer,
  p_started_at timestamptz,
  p_ended_at timestamptz,
  p_status text
)
returns public.focus_sessions
language sql
security invoker
set search_path = public, private
as $$
  select private.create_completed_focus_session(
    p_plan_id,
    p_mode,
    p_planned_duration_minutes,
    p_actual_duration_seconds,
    p_started_at,
    p_ended_at,
    p_status
  );
$$;

grant execute on function public.create_focus_invite(uuid, integer) to authenticated;
grant execute on function public.join_focus_session(uuid) to authenticated;
grant execute on function public.start_focus_session(uuid) to authenticated;
grant execute on function public.pause_focus_session(uuid) to authenticated;
grant execute on function public.resume_focus_session(uuid) to authenticated;
grant execute on function public.finish_focus_session(uuid, text) to authenticated;
grant execute on function public.create_completed_focus_session(
  uuid,
  text,
  integer,
  integer,
  timestamptz,
  timestamptz,
  text
) to authenticated;

alter publication supabase_realtime add table public.focus_sessions;
