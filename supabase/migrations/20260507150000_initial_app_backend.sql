create extension if not exists pgcrypto;

create schema if not exists private;

create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  nickname text not null default '一起进步的你',
  avatar_url text,
  invite_code text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.couples (
  id uuid primary key default gen_random_uuid(),
  user_a_id uuid not null references auth.users (id) on delete cascade,
  user_b_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'active' check (status in ('active', 'ended')),
  created_at timestamptz not null default now(),
  ended_at timestamptz,
  constraint couples_distinct_users check (user_a_id <> user_b_id),
  constraint couples_ended_at_required check (
    (status = 'active' and ended_at is null)
    or (status = 'ended' and ended_at is not null)
  )
);

create unique index couples_unique_pair_idx
  on public.couples (least(user_a_id, user_b_id), greatest(user_a_id, user_b_id))
  where status = 'active';

create table public.plans (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples (id) on delete restrict,
  creator_id uuid not null references auth.users (id) on delete cascade,
  plan_type text not null check (plan_type in ('personal', 'shared')),
  title text not null check (char_length(trim(title)) > 0),
  description text,
  daily_task text not null check (char_length(trim(daily_task)) > 0),
  icon_key text not null default 'heart',
  start_date date not null,
  end_date date not null,
  has_date_range boolean not null default true,
  remind_time time,
  need_supervise boolean not null default true,
  status text not null default 'active' check (status in ('active', 'ended')),
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint plans_date_range check (end_date >= start_date),
  constraint plans_ended_at_required check (
    (status = 'active' and ended_at is null)
    or (status = 'ended' and ended_at is not null)
  )
);

create index plans_couple_id_idx on public.plans (couple_id);
create index plans_creator_id_idx on public.plans (creator_id);

create table public.checkins (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.plans (id) on delete restrict,
  user_id uuid not null references auth.users (id) on delete cascade,
  couple_id uuid not null references public.couples (id) on delete restrict,
  checkin_date date not null,
  status text not null check (status in ('completed', 'uncompleted')),
  mood text check (mood in ('happy', 'normal', 'tired', 'great', 'need_hug')),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint checkins_one_per_day unique (plan_id, user_id, checkin_date)
);

create index checkins_couple_date_idx on public.checkins (couple_id, checkin_date);
create index checkins_plan_date_idx on public.checkins (plan_id, checkin_date);

create table public.reminders (
  id uuid primary key default gen_random_uuid(),
  from_user_id uuid not null references auth.users (id) on delete cascade,
  to_user_id uuid not null references auth.users (id) on delete cascade,
  couple_id uuid not null references public.couples (id) on delete restrict,
  plan_id uuid references public.plans (id) on delete restrict,
  type text not null check (type in ('gentle', 'strict', 'encourage', 'praise')),
  content text not null check (char_length(trim(content)) > 0),
  is_read boolean not null default false,
  delivery_channel text not null default 'in_app' check (delivery_channel in ('in_app')),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  constraint reminders_distinct_users check (from_user_id <> to_user_id),
  constraint reminders_read_at_required check (
    (is_read = false and read_at is null)
    or (is_read = true)
  )
);

create index reminders_to_user_created_idx on public.reminders (to_user_id, created_at desc);
create index reminders_from_user_created_idx on public.reminders (from_user_id, created_at desc);
create index reminders_daily_limit_idx on public.reminders (
  from_user_id,
  to_user_id,
  coalesce(plan_id, '00000000-0000-0000-0000-000000000000'::uuid),
  ((created_at at time zone 'Asia/Shanghai')::date)
);

create or replace function private.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_touch_updated_at
before update on public.profiles
for each row execute function private.touch_updated_at();

create trigger plans_touch_updated_at
before update on public.plans
for each row execute function private.touch_updated_at();

create trigger checkins_touch_updated_at
before update on public.checkins
for each row execute function private.touch_updated_at();

create or replace function private.current_checkin_date()
returns date
language sql
stable
as $$
  select (now() at time zone 'Asia/Shanghai')::date;
$$;

create or replace function private.generate_invite_code()
returns text
language plpgsql
security definer
set search_path = public, private
as $$
declare
  candidate text;
begin
  loop
    candidate := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    exit when not exists (
      select 1 from public.profiles where invite_code = candidate
    );
  end loop;

  return candidate;
end;
$$;

create or replace function private.validate_profile_write()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  if tg_op = 'INSERT' then
    new.invite_code = private.generate_invite_code();
    new.nickname = coalesce(nullif(trim(new.nickname), ''), '一起进步的你');
    new.avatar_url = nullif(trim(new.avatar_url), '');
    return new;
  end if;

  if new.user_id <> old.user_id
    or new.invite_code <> old.invite_code
    or new.created_at <> old.created_at
  then
    raise exception 'profile identity fields cannot be changed';
  end if;

  new.nickname = coalesce(nullif(trim(new.nickname), ''), old.nickname);
  new.avatar_url = nullif(trim(new.avatar_url), '');
  return new;
end;
$$;

create trigger profiles_validate_write
before insert or update on public.profiles
for each row execute function private.validate_profile_write();

create or replace function private.is_active_couple_member(p_couple_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.couples c
    where c.id = p_couple_id
      and c.status = 'active'
      and p_user_id in (c.user_a_id, c.user_b_id)
  );
$$;

create or replace function private.active_couple_id_for_user(p_user_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select c.id
  from public.couples c
  where c.status = 'active'
    and p_user_id in (c.user_a_id, c.user_b_id)
  order by c.created_at desc
  limit 1;
$$;

create or replace function private.are_active_partners(p_user_id uuid, p_partner_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.couples c
    where c.status = 'active'
      and (
        (c.user_a_id = p_user_id and c.user_b_id = p_partner_id)
        or (c.user_a_id = p_partner_id and c.user_b_id = p_user_id)
      )
  );
$$;

create or replace function private.partner_id_for_couple(p_couple_id uuid, p_user_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select case
    when c.user_a_id = p_user_id then c.user_b_id
    when c.user_b_id = p_user_id then c.user_a_id
  end
  from public.couples c
  where c.id = p_couple_id
    and c.status = 'active'
    and p_user_id in (c.user_a_id, c.user_b_id);
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
      and p_user_id in (c.user_a_id, c.user_b_id)
      and (
        p.plan_type = 'shared'
        or (p.plan_type = 'personal' and p.creator_id = p_user_id)
      )
  );
$$;

create or replace function private.validate_couple_insert()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  if new.status = 'active' and (
    private.active_couple_id_for_user(new.user_a_id) is not null
    or private.active_couple_id_for_user(new.user_b_id) is not null
  ) then
    raise exception 'user already has an active couple relationship';
  end if;

  return new;
end;
$$;

create trigger couples_validate_insert
before insert on public.couples
for each row execute function private.validate_couple_insert();

create or replace function private.validate_plan_write()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  has_checkins boolean;
begin
  if not private.is_active_couple_member(new.couple_id, new.creator_id) then
    raise exception 'plan creator must belong to an active couple';
  end if;

  if tg_op = 'UPDATE' then
    if old.status = 'ended' then
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

  return new;
end;
$$;

create trigger plans_validate_write
before insert or update on public.plans
for each row execute function private.validate_plan_write();

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

  if not private.can_checkin_plan(new.plan_id, new.user_id) then
    raise exception 'user cannot check in this plan';
  end if;

  if new.checkin_date <> private.current_checkin_date() then
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

create trigger checkins_validate_write
before insert or update on public.checkins
for each row execute function private.validate_checkin_write();

create or replace function private.validate_reminder_insert()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  plan_row public.plans%rowtype;
  receiver_completed boolean;
  daily_count integer;
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

  select count(*)
  into daily_count
  from public.reminders r
  where r.from_user_id = new.from_user_id
    and r.to_user_id = new.to_user_id
    and coalesce(r.plan_id, '00000000-0000-0000-0000-000000000000'::uuid)
      = coalesce(new.plan_id, '00000000-0000-0000-0000-000000000000'::uuid)
    and (r.created_at at time zone 'Asia/Shanghai')::date = private.current_checkin_date();

  if daily_count >= 3 then
    raise exception 'daily reminder limit reached';
  end if;

  return new;
end;
$$;

create trigger reminders_validate_insert
before insert on public.reminders
for each row execute function private.validate_reminder_insert();

create or replace function private.validate_reminder_update()
returns trigger
language plpgsql
as $$
begin
  if new.id <> old.id
    or new.from_user_id <> old.from_user_id
    or new.to_user_id <> old.to_user_id
    or new.couple_id <> old.couple_id
    or new.plan_id is distinct from old.plan_id
    or new.type <> old.type
    or new.content <> old.content
    or new.delivery_channel <> old.delivery_channel
    or new.created_at <> old.created_at
  then
    raise exception 'only reminder read state can be changed';
  end if;

  if new.is_read = true and new.read_at is null then
    new.read_at = now();
  end if;

  if new.is_read = false and old.is_read = true then
    raise exception 'read reminders cannot be marked unread';
  end if;

  return new;
end;
$$;

create trigger reminders_validate_update
before update on public.reminders
for each row execute function private.validate_reminder_update();

alter table public.profiles enable row level security;
alter table public.couples enable row level security;
alter table public.plans enable row level security;
alter table public.checkins enable row level security;
alter table public.reminders enable row level security;

create policy "Profiles are visible to self and active partner"
on public.profiles for select
to authenticated
using (
  (select auth.uid()) is not null
  and (
    user_id = (select auth.uid())
    or private.are_active_partners((select auth.uid()), user_id)
  )
);

create policy "Users can create their own profile"
on public.profiles for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and user_id = (select auth.uid())
);

create policy "Users can update their own profile"
on public.profiles for update
to authenticated
using (
  (select auth.uid()) is not null
  and user_id = (select auth.uid())
)
with check (
  user_id = (select auth.uid())
);

create policy "Couples are visible to members"
on public.couples for select
to authenticated
using (
  (select auth.uid()) is not null
  and (select auth.uid()) in (user_a_id, user_b_id)
);

create policy "Plans are visible to couple members"
on public.plans for select
to authenticated
using (
  (select auth.uid()) is not null
  and private.is_active_couple_member(couple_id, (select auth.uid()))
);

create policy "Plan creators can insert plans"
on public.plans for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and creator_id = (select auth.uid())
  and private.is_active_couple_member(couple_id, (select auth.uid()))
);

create policy "Plan creators can update active plans"
on public.plans for update
to authenticated
using (
  (select auth.uid()) is not null
  and creator_id = (select auth.uid())
  and status = 'active'
)
with check (
  creator_id = (select auth.uid())
);

create policy "Checkins are visible to couple members"
on public.checkins for select
to authenticated
using (
  (select auth.uid()) is not null
  and private.is_active_couple_member(couple_id, (select auth.uid()))
);

create policy "Users can insert their own current-day checkins"
on public.checkins for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and user_id = (select auth.uid())
  and checkin_date = private.current_checkin_date()
  and private.can_checkin_plan(plan_id, (select auth.uid()))
);

create policy "Users can update their own current-day checkins"
on public.checkins for update
to authenticated
using (
  (select auth.uid()) is not null
  and user_id = (select auth.uid())
  and checkin_date = private.current_checkin_date()
)
with check (
  user_id = (select auth.uid())
  and checkin_date = private.current_checkin_date()
  and private.can_checkin_plan(plan_id, (select auth.uid()))
);

create policy "Reminders are visible to sender and receiver"
on public.reminders for select
to authenticated
using (
  (select auth.uid()) is not null
  and (select auth.uid()) in (from_user_id, to_user_id)
);

create policy "Users can send reminders to their partner"
on public.reminders for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and from_user_id = (select auth.uid())
  and private.are_active_partners(from_user_id, to_user_id)
);

create policy "Receivers can mark reminders read"
on public.reminders for update
to authenticated
using (
  (select auth.uid()) is not null
  and to_user_id = (select auth.uid())
)
with check (
  to_user_id = (select auth.uid())
);

create or replace function private.create_profile_for_current_user(
  p_nickname text default null,
  p_avatar_url text default null
)
returns public.profiles
language plpgsql
security definer
set search_path = public, private
as $$
declare
  current_user_id uuid := auth.uid();
  profile_row public.profiles%rowtype;
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  insert into public.profiles (user_id, nickname, avatar_url, invite_code)
  values (
    current_user_id,
    coalesce(nullif(trim(p_nickname), ''), '一起进步的你'),
    nullif(trim(p_avatar_url), ''),
    ''
  )
  on conflict (user_id) do update
  set
    nickname = coalesce(nullif(trim(p_nickname), ''), public.profiles.nickname),
    avatar_url = coalesce(nullif(trim(p_avatar_url), ''), public.profiles.avatar_url),
    updated_at = now()
  returning * into profile_row;

  return profile_row;
end;
$$;

create or replace function public.create_profile_for_current_user(
  p_nickname text default null,
  p_avatar_url text default null
)
returns public.profiles
language sql
security invoker
set search_path = public, private
as $$
  select private.create_profile_for_current_user(p_nickname, p_avatar_url);
$$;

create or replace function private.bind_partner_by_invite_code(p_invite_code text)
returns public.couples
language plpgsql
security definer
set search_path = public, private
as $$
declare
  current_user_id uuid := auth.uid();
  target_user_id uuid;
  couple_row public.couples%rowtype;
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  select p.user_id
  into target_user_id
  from public.profiles p
  where p.invite_code = upper(trim(p_invite_code));

  if target_user_id is null then
    raise exception 'invite code not found';
  end if;

  if target_user_id = current_user_id then
    raise exception 'cannot bind yourself';
  end if;

  if current_user_id::text < target_user_id::text then
    perform pg_advisory_xact_lock(hashtext(current_user_id::text));
    perform pg_advisory_xact_lock(hashtext(target_user_id::text));
  else
    perform pg_advisory_xact_lock(hashtext(target_user_id::text));
    perform pg_advisory_xact_lock(hashtext(current_user_id::text));
  end if;

  if private.active_couple_id_for_user(current_user_id) is not null
    or private.active_couple_id_for_user(target_user_id) is not null
  then
    raise exception 'user already has an active couple relationship';
  end if;

  insert into public.couples (user_a_id, user_b_id)
  values (least(current_user_id, target_user_id), greatest(current_user_id, target_user_id))
  returning * into couple_row;

  return couple_row;
end;
$$;

create or replace function public.bind_partner_by_invite_code(p_invite_code text)
returns public.couples
language sql
security invoker
set search_path = public, private
as $$
  select private.bind_partner_by_invite_code(p_invite_code);
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
  plan_row public.plans%rowtype;
  checkin_row public.checkins%rowtype;
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  select *
  into plan_row
  from public.plans p
  where p.id = p_plan_id;

  if plan_row.id is null then
    raise exception 'plan does not exist';
  end if;

  if not private.can_checkin_plan(p_plan_id, current_user_id) then
    raise exception 'user cannot check in this plan';
  end if;

  insert into public.checkins (
    plan_id,
    user_id,
    couple_id,
    checkin_date,
    status,
    mood,
    note
  )
  values (
    p_plan_id,
    current_user_id,
    plan_row.couple_id,
    private.current_checkin_date(),
    p_status,
    p_mood,
    nullif(trim(p_note), '')
  )
  on conflict (plan_id, user_id, checkin_date) do update
  set
    status = excluded.status,
    mood = excluded.mood,
    note = excluded.note,
    updated_at = now()
  returning * into checkin_row;

  return checkin_row;
end;
$$;

create or replace function public.upsert_today_checkin(
  p_plan_id uuid,
  p_status text,
  p_mood text default null,
  p_note text default null
)
returns public.checkins
language sql
security invoker
set search_path = public, private
as $$
  select private.upsert_today_checkin(p_plan_id, p_status, p_mood, p_note);
$$;

create or replace function private.send_reminder(
  p_plan_id uuid,
  p_type text,
  p_content text
)
returns public.reminders
language plpgsql
security definer
set search_path = public, private
as $$
declare
  current_user_id uuid := auth.uid();
  plan_row public.plans%rowtype;
  partner_user_id uuid;
  reminder_row public.reminders%rowtype;
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  select *
  into plan_row
  from public.plans p
  where p.id = p_plan_id;

  if plan_row.id is null then
    raise exception 'plan does not exist';
  end if;

  partner_user_id := private.partner_id_for_couple(plan_row.couple_id, current_user_id);

  if partner_user_id is null then
    raise exception 'plan is not in the current user couple';
  end if;

  insert into public.reminders (
    from_user_id,
    to_user_id,
    couple_id,
    plan_id,
    type,
    content
  )
  values (
    current_user_id,
    partner_user_id,
    plan_row.couple_id,
    p_plan_id,
    p_type,
    p_content
  )
  returning * into reminder_row;

  return reminder_row;
end;
$$;

create or replace function public.send_reminder(
  p_plan_id uuid,
  p_type text,
  p_content text
)
returns public.reminders
language sql
security invoker
set search_path = public, private
as $$
  select private.send_reminder(p_plan_id, p_type, p_content);
$$;

create or replace function private.mark_reminder_read(p_reminder_id uuid)
returns public.reminders
language plpgsql
security definer
set search_path = public, private
as $$
declare
  current_user_id uuid := auth.uid();
  reminder_row public.reminders%rowtype;
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  update public.reminders
  set is_read = true,
      read_at = coalesce(read_at, now())
  where id = p_reminder_id
    and to_user_id = current_user_id
  returning * into reminder_row;

  if reminder_row.id is null then
    raise exception 'reminder not found';
  end if;

  return reminder_row;
end;
$$;

create or replace function public.mark_reminder_read(p_reminder_id uuid)
returns public.reminders
language sql
security invoker
set search_path = public, private
as $$
  select private.mark_reminder_read(p_reminder_id);
$$;

revoke all on schema private from public;
grant usage on schema private to authenticated;
revoke all on all functions in schema private from public;
grant execute on all functions in schema private to authenticated;

grant select, insert, update on public.profiles to authenticated;
grant select on public.couples to authenticated;
grant select, insert, update on public.plans to authenticated;
grant select, insert, update on public.checkins to authenticated;
grant select, insert, update on public.reminders to authenticated;

grant execute on function public.create_profile_for_current_user(text, text) to authenticated;
grant execute on function public.bind_partner_by_invite_code(text) to authenticated;
grant execute on function public.upsert_today_checkin(uuid, text, text, text) to authenticated;
grant execute on function public.send_reminder(uuid, text, text) to authenticated;
grant execute on function public.mark_reminder_read(uuid) to authenticated;
