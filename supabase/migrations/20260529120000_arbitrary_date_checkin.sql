-- ============================================================
-- 1. 扩展 can_checkin_plan：接受可选 p_date 参数
--    默认 null = 今天（保持向后兼容）
-- ============================================================
create or replace function private.can_checkin_plan(
  p_plan_id uuid,
  p_user_id uuid,
  p_date date default null
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
        coalesce(p_date, private.current_checkin_date())
      )
      and p_user_id in (c.user_a_id, c.user_b_id)
      and (
        p.plan_type = 'shared'
        or (p.plan_type = 'personal' and p.creator_id = p_user_id)
      )
  );
$$;

-- ============================================================
-- 2. 修改 validate_checkin_write 触发器：
--    - 用 new.checkin_date 校验计划调度窗口（而非硬编码今天）
--    - UPDATE 仍只允许修改当日打卡
--    - INSERT 允许任意日期（由 RPC 层保证范围合法）
-- ============================================================
create or replace function private.validate_checkin_write()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  plan_couple_id uuid;
begin
  new.created_at = coalesce(new.created_at, now());
  new.updated_at = coalesce(new.updated_at, now());

  select p.couple_id
  into plan_couple_id
  from public.plans p
  where p.id = new.plan_id;

  if plan_couple_id is null then
    raise exception 'plan does not exist';
  end if;

  if new.couple_id <> plan_couple_id then
    raise exception 'checkin couple_id must match plan';
  end if;

  -- 用 checkin 自身的日期（不再硬编码今天）来校验权限
  if not private.can_checkin_plan(new.plan_id, new.user_id, new.checkin_date) then
    raise exception 'user cannot check in this plan';
  end if;

  -- UPDATE：只能在当天修改
  if tg_op = 'UPDATE' and new.checkin_date <> private.current_checkin_date() then
    raise exception 'checkins can only be changed during the current checkin day';
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

-- ============================================================
-- 3. 新 RPC：upsert_checkin_for_date
--    过去日期：INSERT only（DO NOTHING 不覆盖已有）
--    今天/未来：UPSERT（允许覆盖）
-- ============================================================
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
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  select * into plan_row from public.plans p where p.id = p_plan_id;

  if plan_row.id is null then
    raise exception 'plan does not exist';
  end if;

  if plan_row.status <> 'active' then
    raise exception 'plan is not active';
  end if;

  if not private.is_plan_available_on_date(
    plan_row.repeat_type, plan_row.has_date_range,
    plan_row.start_date, plan_row.end_date, p_date
  ) then
    raise exception 'plan is not scheduled on this date';
  end if;

  if not exists (
    select 1 from public.couples c
    where c.id = plan_row.couple_id and c.status = 'active'
      and current_user_id in (c.user_a_id, c.user_b_id)
      and (plan_row.plan_type = 'shared'
           or (plan_row.plan_type = 'personal'
               and plan_row.creator_id = current_user_id))
  ) then
    raise exception 'user cannot check in this plan';
  end if;

  -- future dates are intentionally allowed: clients may pre-checkin upcoming plan days
  if p_date < private.current_checkin_date() then
    -- 过去：只插入，不覆盖已有记录
    insert into public.checkins (
      plan_id, user_id, couple_id, checkin_date, status, mood, note
    )
    values (
      p_plan_id, current_user_id, plan_row.couple_id, p_date,
      p_status, p_mood, nullif(trim(p_note), '')
    )
    on conflict (plan_id, user_id, checkin_date) do nothing
    returning * into checkin_row;
  else
    -- 今天/未来：允许覆盖
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
  end if;

  return checkin_row;
end;
$$;

create or replace function public.upsert_checkin_for_date(
  p_plan_id uuid,
  p_date date,
  p_status text,
  p_mood text default null,
  p_note text default null
)
returns public.checkins
language sql
security invoker
set search_path = public, private
as $$
  select private.upsert_checkin_for_date(p_plan_id, p_date, p_status, p_mood, p_note);
$$;

grant execute on function public.upsert_checkin_for_date(uuid, date, text, text, text)
  to authenticated;

-- Note: the checkins RLS INSERT policy checks checkin_date = current_checkin_date(),
-- which would block non-today inserts. However, private.upsert_checkin_for_date runs
-- with SECURITY DEFINER, so it bypasses RLS entirely. No RLS policy update is needed.
