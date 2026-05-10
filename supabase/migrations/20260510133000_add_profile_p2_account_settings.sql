alter table public.couples
  add column if not exists anniversary_date date;

create or replace function private.update_current_couple_anniversary(
  p_anniversary_date date
)
returns public.couples
language plpgsql
security definer
set search_path = public, private
as $$
declare
  current_user_id uuid := auth.uid();
  couple_row public.couples%rowtype;
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  if p_anniversary_date is null then
    raise exception 'anniversary date is required';
  end if;

  if p_anniversary_date > private.current_checkin_date() then
    raise exception 'anniversary date cannot be in the future';
  end if;

  update public.couples
  set anniversary_date = p_anniversary_date
  where id = private.active_couple_id_for_user(current_user_id)
    and current_user_id in (user_a_id, user_b_id)
    and status = 'active'
  returning * into couple_row;

  if couple_row.id is null then
    raise exception 'active couple relationship not found';
  end if;

  return couple_row;
end;
$$;

create or replace function public.update_current_couple_anniversary(
  p_anniversary_date date
)
returns public.couples
language sql
security invoker
set search_path = public, private
as $$
  select * from private.update_current_couple_anniversary(p_anniversary_date);
$$;

create or replace function private.delete_current_user_account()
returns void
language plpgsql
security definer
set search_path = public, private, auth, storage
as $$
declare
  current_user_id uuid := auth.uid();
  current_couple_ids uuid[];
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  select coalesce(array_agg(c.id), array[]::uuid[])
  into current_couple_ids
  from public.couples c
  where current_user_id in (c.user_a_id, c.user_b_id);

  delete from public.reminders
  where from_user_id = current_user_id
    or to_user_id = current_user_id
    or couple_id = any(current_couple_ids);

  delete from public.focus_sessions
  where created_by_user_id = current_user_id
    or couple_id = any(current_couple_ids);

  delete from public.checkins
  where user_id = current_user_id
    or couple_id = any(current_couple_ids);

  delete from public.plans
  where creator_id = current_user_id
    or couple_id = any(current_couple_ids);

  delete from public.couple_invitations
  where from_user_id = current_user_id
    or to_user_id = current_user_id;

  delete from public.couples
  where current_user_id in (user_a_id, user_b_id);

  delete from storage.objects
  where bucket_id = 'avatars'
    and (storage.foldername(name))[1] = current_user_id::text;

  delete from public.profiles
  where user_id = current_user_id;

  delete from auth.users
  where id = current_user_id;
end;
$$;

create or replace function public.delete_current_user_account()
returns void
language sql
security invoker
set search_path = public, private
as $$
  select private.delete_current_user_account();
$$;

revoke all on function private.update_current_couple_anniversary(date) from public;
revoke all on function private.delete_current_user_account() from public;
grant execute on function private.update_current_couple_anniversary(date) to authenticated;
grant execute on function private.delete_current_user_account() to authenticated;
grant execute on function public.update_current_couple_anniversary(date) to authenticated;
grant execute on function public.delete_current_user_account() to authenticated;
