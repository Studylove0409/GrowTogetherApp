begin;

-- Cancelling a check-in should return the occurrence to the pending state.
-- We delete the current user's check-in row instead of storing a visible
-- `uncompleted` business state.

create or replace function private.cancel_checkin_for_date(
  p_plan_id uuid,
  p_user_id uuid,
  p_date date
)
returns table (
  plan_id uuid,
  checkin_date date,
  deleted boolean
)
language plpgsql
security definer
set search_path = public, private
as $$
declare
  plan_row public.plans%rowtype;
  deleted_count integer;
begin
  if p_user_id is null then
    raise exception 'authentication required';
  end if;

  select * into plan_row
  from public.plans p
  where p.id = p_plan_id
  for update;

  if plan_row.id is null then
    raise exception 'plan does not exist';
  end if;

  if not private.is_active_couple_member(plan_row.couple_id, p_user_id) then
    raise exception 'permission denied';
  end if;

  if plan_row.plan_type = 'personal' and plan_row.creator_id <> p_user_id then
    raise exception 'permission denied';
  end if;

  delete from public.checkins c
  where c.plan_id = p_plan_id
    and c.user_id = p_user_id
    and c.checkin_date = p_date;

  get diagnostics deleted_count = row_count;

  if deleted_count > 0 and plan_row.repeat_type = 'once' and plan_row.status = 'ended' then
    update public.plans
    set status = 'active',
        ended_at = null,
        updated_at = now()
    where id = p_plan_id;
  end if;

  return query select p_plan_id, p_date, deleted_count > 0;
end;
$$;

create or replace function public.cancel_today_checkin(p_plan_id uuid)
returns table (
  plan_id uuid,
  checkin_date date,
  deleted boolean
)
language sql
security definer
set search_path = public, private
as $$
  select *
  from private.cancel_checkin_for_date(
    p_plan_id,
    auth.uid(),
    private.current_checkin_date()
  );
$$;

create or replace function public.cancel_checkin_for_date(
  p_plan_id uuid,
  p_date date
)
returns table (
  plan_id uuid,
  checkin_date date,
  deleted boolean
)
language sql
security definer
set search_path = public, private
as $$
  select *
  from private.cancel_checkin_for_date(p_plan_id, auth.uid(), p_date);
$$;

grant execute on function public.cancel_today_checkin(uuid) to authenticated;
grant execute on function public.cancel_checkin_for_date(uuid, date) to authenticated;

commit;
