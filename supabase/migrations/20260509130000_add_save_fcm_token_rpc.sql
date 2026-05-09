create or replace function private.save_fcm_token(p_token text)
returns public.profiles
language plpgsql
security definer
set search_path = public, private
as $$
declare
  profile_row public.profiles%rowtype;
  normalized_token text := nullif(trim(p_token), '');
begin
  if (select auth.uid()) is null then
    raise exception 'authentication required';
  end if;

  if normalized_token is null then
    raise exception 'fcm token required';
  end if;

  perform private.create_profile_for_current_user(null, null);

  update public.profiles
  set fcm_token = left(normalized_token, 4096)
  where user_id = (select auth.uid())
  returning * into profile_row;

  if profile_row.user_id is null then
    raise exception 'profile not found';
  end if;

  return profile_row;
end;
$$;

create or replace function public.save_fcm_token(p_token text)
returns public.profiles
language sql
security invoker
set search_path = public
as $$
  select private.save_fcm_token(p_token);
$$;

grant execute on function public.save_fcm_token(text) to authenticated;
