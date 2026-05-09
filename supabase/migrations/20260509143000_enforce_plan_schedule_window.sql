alter table public.plans
  add column if not exists has_date_range boolean not null default true;

alter table public.plans
  add column if not exists repeat_type text not null default 'daily';

update public.plans
set repeat_type = 'daily'
where repeat_type is null;

alter table public.plans
  drop constraint if exists plans_repeat_type_check;

alter table public.plans
  add constraint plans_repeat_type_check
  check (repeat_type in ('once', 'daily'));

create or replace function private.is_plan_available_on_date(
  p_repeat_type text,
  p_has_date_range boolean,
  p_start_date date,
  p_end_date date,
  p_date date
)
returns boolean
language sql
stable
as $$
  select case
    when p_repeat_type = 'once' then p_date = p_start_date
    when coalesce(p_has_date_range, true) then p_date between p_start_date and p_end_date
    else p_date >= p_start_date
  end;
$$;

create or replace function private.can_checkin_plan(p_plan_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  select exists (
    select 1
    from public.plans p
    join public.couples c on c.id = p.couple_id
    where p.id = p_plan_id
      and p.status = 'active'
      and c.status = 'active'
      and private.is_plan_available_on_date(
        p.repeat_type,
        p.has_date_range,
        p.start_date,
        p.end_date,
        private.current_checkin_date()
      )
      and p_user_id in (c.user_a_id, c.user_b_id)
      and (
        p.plan_type = 'shared'
        or (p.plan_type = 'personal' and p.creator_id = p_user_id)
      )
  );
$$;

create or replace function private.validate_reminder_insert()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  plan_row public.plans%rowtype;
  receiver_completed boolean;
begin
  new.created_at = now();

  if not private.are_active_partners(new.from_user_id, new.to_user_id) then
    raise exception 'reminders can only be sent to an active partner';
  end if;

  if new.plan_id is not null then
    select *
    into plan_row
    from public.plans p
    where p.id = new.plan_id;

    if plan_row.id is null
      or plan_row.status <> 'active'
      or not private.is_plan_available_on_date(
        plan_row.repeat_type,
        plan_row.has_date_range,
        plan_row.start_date,
        plan_row.end_date,
        private.current_checkin_date()
      )
    then
      raise exception 'reminders can only be linked to an active plan';
    end if;

    if plan_row.couple_id <> new.couple_id then
      raise exception 'reminder couple_id must match plan';
    end if;

    if not plan_row.need_supervise then
      raise exception 'supervision is disabled for this plan';
    end if;

    if not private.is_active_couple_member(plan_row.couple_id, new.from_user_id)
      or not private.is_active_couple_member(plan_row.couple_id, new.to_user_id)
    then
      raise exception 'reminder users must belong to the plan couple';
    end if;

    select exists (
      select 1
      from public.checkins c
      where c.plan_id = new.plan_id
        and c.user_id = new.to_user_id
        and c.checkin_date = private.current_checkin_date()
        and c.status = 'completed'
    ) into receiver_completed;

    if receiver_completed and new.type in ('gentle', 'strict') then
      raise exception 'prompt reminders are not allowed after completion';
    end if;
  else
    if new.couple_id <> private.active_couple_id_for_user(new.from_user_id) then
      raise exception 'reminder couple_id must match sender active couple';
    end if;
  end if;

  return new;
end;
$$;
