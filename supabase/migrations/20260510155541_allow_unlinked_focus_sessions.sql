alter table public.focus_sessions
  alter column plan_id drop not null,
  alter column couple_id drop not null;

create index if not exists focus_sessions_user_created_idx
  on public.focus_sessions (created_by_user_id, created_at desc);

create or replace function private.validate_focus_session_write()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  plan_row public.plans%rowtype;
begin
  if new.plan_id is not null then
    select *
    into plan_row
    from public.plans p
    where p.id = new.plan_id;

    if plan_row.id is null or plan_row.status <> 'active' then
      raise exception 'focus sessions can only be linked to an active plan';
    end if;

    if new.couple_id is distinct from plan_row.couple_id then
      raise exception 'focus session couple_id must match plan';
    end if;

    if not private.can_checkin_plan(new.plan_id, new.created_by_user_id) then
      raise exception 'user cannot focus for this plan';
    end if;
  else
    new.plan_title := coalesce(nullif(trim(new.plan_title), ''), '普通专注');

    if new.mode = 'couple' and new.couple_id is null then
      raise exception 'couple focus requires an active couple';
    end if;
  end if;

  if new.couple_id is not null
    and not private.is_active_couple_member(new.couple_id, new.created_by_user_id)
  then
    raise exception 'focus session creator must belong to the active couple';
  end if;

  if new.mode = 'solo' and new.plan_id is null and new.couple_id is not null then
    raise exception 'unlinked solo focus must be personal';
  end if;

  if tg_op = 'UPDATE' then
    if old.status in ('completed', 'cancelled', 'interrupted') then
      raise exception 'finished focus sessions cannot be changed';
    end if;

    if new.id <> old.id
      or new.couple_id is distinct from old.couple_id
      or new.plan_id is distinct from old.plan_id
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

drop policy if exists "Focus sessions are visible to couple members"
  on public.focus_sessions;
drop policy if exists "Users can create focus sessions for their plans"
  on public.focus_sessions;
drop policy if exists "Couple members can update active focus sessions"
  on public.focus_sessions;

create policy "Focus sessions are visible to owners and couple members"
on public.focus_sessions for select
to authenticated
using (
  (select auth.uid()) is not null
  and (
    (couple_id is null and created_by_user_id = (select auth.uid()))
    or (
      couple_id is not null
      and private.is_active_couple_member(couple_id, (select auth.uid()))
    )
  )
);

create policy "Users can create focus sessions"
on public.focus_sessions for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and created_by_user_id = (select auth.uid())
  and (
    (couple_id is null and mode = 'solo')
    or (
      couple_id is not null
      and private.is_active_couple_member(couple_id, (select auth.uid()))
    )
  )
  and (
    plan_id is null
    or private.can_checkin_plan(plan_id, (select auth.uid()))
  )
);

create policy "Users can update active focus sessions"
on public.focus_sessions for update
to authenticated
using (
  (select auth.uid()) is not null
  and status in ('waiting', 'running', 'paused')
  and (
    (couple_id is null and created_by_user_id = (select auth.uid()))
    or (
      couple_id is not null
      and private.is_active_couple_member(couple_id, (select auth.uid()))
    )
  )
)
with check (
  (couple_id is null and created_by_user_id = (select auth.uid()))
  or (
    couple_id is not null
    and private.is_active_couple_member(couple_id, (select auth.uid()))
  )
);

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
  active_couple_id uuid;
  plan_row public.plans%rowtype;
  session_row public.focus_sessions%rowtype;
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  if p_planned_duration_minutes < 1 or p_planned_duration_minutes > 180 then
    raise exception 'planned duration must be between 1 and 180 minutes';
  end if;

  active_couple_id := private.active_couple_id_for_user(current_user_id);
  if active_couple_id is null then
    raise exception 'no active couple relationship';
  end if;

  if p_plan_id is not null then
    select *
    into plan_row
    from public.plans p
    where p.id = p_plan_id;

    if plan_row.id is null or plan_row.status <> 'active' then
      raise exception 'focus sessions can only be linked to an active plan';
    end if;

    if plan_row.couple_id <> active_couple_id then
      raise exception 'focus session couple_id must match plan';
    end if;

    if not private.can_checkin_plan(p_plan_id, current_user_id) then
      raise exception 'user cannot focus for this plan';
    end if;
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
    active_couple_id,
    p_plan_id,
    coalesce(plan_row.title, '普通专注'),
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
  active_couple_id uuid;
  session_couple_id uuid;
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

  active_couple_id := private.active_couple_id_for_user(current_user_id);

  if p_plan_id is not null then
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

    session_couple_id := plan_row.couple_id;
  elsif p_mode = 'couple' then
    if active_couple_id is null then
      raise exception 'no active couple relationship';
    end if;
    session_couple_id := active_couple_id;
  else
    session_couple_id := null;
  end if;

  final_actual_seconds := greatest(coalesce(p_actual_duration_seconds, 0), 0);
  final_score := case
    when p_plan_id is null then 0
    else private.focus_score_delta(final_status, final_actual_seconds)
  end;

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
    session_couple_id,
    p_plan_id,
    coalesce(plan_row.title, '普通专注'),
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

  if session_row.couple_id is null then
    if session_row.created_by_user_id <> current_user_id then
      raise exception 'user cannot finish this focus session';
    end if;
  elsif not private.is_active_couple_member(session_row.couple_id, current_user_id) then
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
  final_score := case
    when session_row.plan_id is null then 0
    else private.focus_score_delta(final_status, actual_seconds)
  end;

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
