create or replace function public.create_profile_for_current_user(
  p_nickname text default null,
  p_avatar_url text default null
)
returns public.profiles
language sql
security invoker
set search_path = public, private
as $$
  select *
  from private.create_profile_for_current_user(p_nickname, p_avatar_url);
$$;

create or replace function public.bind_partner_by_invite_code(p_invite_code text)
returns public.couples
language sql
security invoker
set search_path = public, private
as $$
  select *
  from private.bind_partner_by_invite_code(p_invite_code);
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
  select *
  from private.upsert_today_checkin(p_plan_id, p_status, p_mood, p_note);
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
  select *
  from private.send_reminder(p_plan_id, p_type, p_content);
$$;

create or replace function public.mark_reminder_read(p_reminder_id uuid)
returns public.reminders
language sql
security invoker
set search_path = public, private
as $$
  select *
  from private.mark_reminder_read(p_reminder_id);
$$;

create or replace function public.end_current_couple_relationship()
returns public.couples
language sql
security invoker
set search_path = public, private
as $$
  select *
  from private.end_current_couple_relationship();
$$;
