-- Allow users to freely change their own check-in result for any scheduled
-- occurrence. This supports cancelling a completed check-in by saving it as
-- `uncompleted`, including once plans that were auto-ended after completion.

create or replace function private.validate_plan_write()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  has_checkins boolean;
  reopens_auto_ended_once boolean;
begin
  if not private.is_active_couple_member(new.couple_id, new.creator_id) then
    raise exception 'plan creator must belong to an active couple';
  end if;

  if tg_op = 'UPDATE' then
    reopens_auto_ended_once :=
      old.status = 'ended'
      and old.repeat_type = 'once'
      and new.status = 'active'
      and new.ended_at is null
      and new.id = old.id
      and new.couple_id = old.couple_id
      and new.creator_id = old.creator_id
      and new.plan_type = old.plan_type
      and new.title = old.title
      and coalesce(new.description, '') = coalesce(old.description, '')
      and new.daily_task = old.daily_task
      and new.icon_key = old.icon_key
      and new.start_date = old.start_date
      and new.end_date = old.end_date
      and new.has_date_range = old.has_date_range
      and coalesce(new.remind_time, time '00:00') =
          coalesce(old.remind_time, time '00:00')
      and new.need_supervise = old.need_supervise
      and new.repeat_type = old.repeat_type
      and new.created_at = old.created_at;

    if old.status = 'ended' and not reopens_auto_ended_once then
      raise exception 'ended plans cannot be changed';
    end if;

    if new.id <> old.id
      or new.couple_id <> old.couple_id
      or new.creator_id <> old.creator_id
      or new.plan_type <> old.plan_type
      or new.created_at <> old.created_at
    then
      raise exception 'plan identity fields cannot be changed';
    end if;

    if not reopens_auto_ended_once then
      select exists (
        select 1 from public.checkins c where c.plan_id = old.id
      ) into has_checkins;

      if has_checkins and (
        new.start_date <> old.start_date
        or new.end_date < old.end_date
      ) then
        raise exception 'plan dates can only be extended after checkins exist';
      end if;
    end if;
  end if;

  return new;
end;
$$;

create or replace function private.validate_checkin_write()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  plan_row public.plans%rowtype;
begin
  new.created_at = coalesce(new.created_at, now());
  new.updated_at = coalesce(new.updated_at, now());

  select *
  into plan_row
  from public.plans p
  where p.id = new.plan_id;

  if plan_row.id is null then
    raise exception 'plan does not exist';
  end if;

  if new.couple_id <> plan_row.couple_id then
    raise exception 'checkin couple_id must match plan';
  end if;

  if not private.is_plan_available_on_date(
    plan_row.repeat_type,
    plan_row.has_date_range,
    plan_row.start_date,
    plan_row.end_date,
    new.checkin_date
  ) then
    raise exception 'plan is not scheduled on this date';
  end if;

  if not exists (
    select 1
    from public.couples c
    where c.id = plan_row.couple_id
      and c.status = 'active'
      and new.user_id in (c.user_a_id, c.user_b_id)
      and (
        plan_row.plan_type = 'shared'
        or (plan_row.plan_type = 'personal' and plan_row.creator_id = new.user_id)
      )
  ) then
    raise exception 'user cannot check in this plan';
  end if;

  if tg_op = 'INSERT' and plan_row.status <> 'active' and not exists (
    select 1
    from public.checkins c
    where c.plan_id = new.plan_id
      and c.user_id = new.user_id
      and c.checkin_date = new.checkin_date
  ) then
    raise exception 'plan is not active';
  end if;

  if tg_op = 'UPDATE' and (
    new.id <> old.id
    or new.plan_id <> old.plan_id
    or new.user_id <> old.user_id
    or new.couple_id <> old.couple_id
    or new.checkin_date <> old.checkin_date
    or new.created_at <> old.created_at
  ) then
    raise exception 'checkin identity fields cannot be changed';
  end if;

  return new;
end;
$$;

create or replace function private.upsert_today_checkin(
  p_plan_id uuid,
  p_status text,
  p_mood text default null,
  p_note text default null
)
returns public.checkins
language plpgsql
security definer
set search_path = public, private
as $$
declare
  current_user_id uuid := auth.uid();
  target_date date := private.current_checkin_date();
  plan_row public.plans%rowtype;
  checkin_row public.checkins%rowtype;
  has_existing_checkin boolean;
  can_write boolean;
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  select * into plan_row from public.plans p where p.id = p_plan_id;

  if plan_row.id is null then
    raise exception 'plan does not exist';
  end if;

  select exists (
    select 1
    from public.checkins c
    where c.plan_id = p_plan_id
      and c.user_id = current_user_id
      and c.checkin_date = target_date
  ) into has_existing_checkin;

  can_write :=
    private.can_checkin_plan(p_plan_id, current_user_id)
    or (
      p_status = 'uncompleted'
      and has_existing_checkin
      and plan_row.repeat_type = 'once'
      and private.is_plan_available_on_date(
        plan_row.repeat_type,
        plan_row.has_date_range,
        plan_row.start_date,
        plan_row.end_date,
        target_date
      )
      and exists (
        select 1
        from public.couples c
        where c.id = plan_row.couple_id
          and c.status = 'active'
          and current_user_id in (c.user_a_id, c.user_b_id)
          and (
            plan_row.plan_type = 'shared'
            or (plan_row.plan_type = 'personal' and plan_row.creator_id = current_user_id)
          )
      )
    );

  if not can_write then
    raise exception 'user cannot check in this plan';
  end if;

  insert into public.checkins (
    plan_id, user_id, couple_id, checkin_date, status, mood, note
  )
  values (
    p_plan_id, current_user_id, plan_row.couple_id, target_date,
    p_status, p_mood, nullif(trim(p_note), '')
  )
  on conflict (plan_id, user_id, checkin_date) do update
  set
    status = excluded.status,
    mood = excluded.mood,
    note = excluded.note,
    updated_at = now()
  returning * into checkin_row;

  if p_status = 'uncompleted'
      and plan_row.status = 'ended'
      and plan_row.repeat_type = 'once' then
    update public.plans
    set status = 'active',
        ended_at = null
    where id = p_plan_id;
  end if;

  return checkin_row;
end;
$$;

create or replace function private.upsert_checkin_for_date(
  p_plan_id uuid,
  p_date date,
  p_status text,
  p_mood text default null,
  p_note text default null
)
returns public.checkins
language plpgsql
security definer
set search_path = public, private
as $$
declare
  current_user_id uuid := auth.uid();
  plan_row public.plans%rowtype;
  checkin_row public.checkins%rowtype;
  has_existing_checkin boolean;
  can_write boolean;
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  select * into plan_row from public.plans p where p.id = p_plan_id;

  if plan_row.id is null then
    raise exception 'plan does not exist';
  end if;

  if not private.is_plan_available_on_date(
    plan_row.repeat_type,
    plan_row.has_date_range,
    plan_row.start_date,
    plan_row.end_date,
    p_date
  ) then
    raise exception 'plan is not scheduled on this date';
  end if;

  select exists (
    select 1
    from public.checkins c
    where c.plan_id = p_plan_id
      and c.user_id = current_user_id
      and c.checkin_date = p_date
  ) into has_existing_checkin;

  can_write :=
    (
      plan_row.status = 'active'
      and exists (
        select 1 from public.couples c
        where c.id = plan_row.couple_id and c.status = 'active'
          and current_user_id in (c.user_a_id, c.user_b_id)
          and (plan_row.plan_type = 'shared'
               or (plan_row.plan_type = 'personal'
                   and plan_row.creator_id = current_user_id))
      )
    )
    or (
      p_status = 'uncompleted'
      and has_existing_checkin
      and plan_row.repeat_type = 'once'
      and exists (
        select 1 from public.couples c
        where c.id = plan_row.couple_id and c.status = 'active'
          and current_user_id in (c.user_a_id, c.user_b_id)
          and (plan_row.plan_type = 'shared'
               or (plan_row.plan_type = 'personal'
                   and plan_row.creator_id = current_user_id))
      )
    );

  if not can_write then
    raise exception 'user cannot check in this plan';
  end if;

  insert into public.checkins (
    plan_id, user_id, couple_id, checkin_date, status, mood, note
  )
  values (
    p_plan_id, current_user_id, plan_row.couple_id, p_date,
    p_status, p_mood, nullif(trim(p_note), '')
  )
  on conflict (plan_id, user_id, checkin_date) do update
    set status = excluded.status,
        mood = excluded.mood,
        note = excluded.note,
        updated_at = now()
  returning * into checkin_row;

  if p_status = 'uncompleted'
      and plan_row.status = 'ended'
      and plan_row.repeat_type = 'once' then
    update public.plans
    set status = 'active',
        ended_at = null
    where id = p_plan_id;
  end if;

  return checkin_row;
end;
$$;
