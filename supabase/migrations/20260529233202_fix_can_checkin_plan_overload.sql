-- The arbitrary-date check-in migration introduced a three-argument
-- private.can_checkin_plan(..., p_date date default null) overload.
-- Keeping that default alongside the original two-argument function makes
-- calls like private.can_checkin_plan(plan_id, user_id) ambiguous.
begin;

drop function if exists private.can_checkin_plan(uuid, uuid, date);

create function private.can_checkin_plan(
  p_plan_id uuid,
  p_user_id uuid,
  p_date date
)
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
        p_date
      )
      and p_user_id in (c.user_a_id, c.user_b_id)
      and (
        p.plan_type = 'shared'
        or (p.plan_type = 'personal' and p.creator_id = p_user_id)
      )
  );
$$;

commit;
