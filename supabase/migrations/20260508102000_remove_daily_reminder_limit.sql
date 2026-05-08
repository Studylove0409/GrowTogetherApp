drop index if exists public.reminders_daily_limit_idx;

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

    if plan_row.id is null or plan_row.status <> 'active' then
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
