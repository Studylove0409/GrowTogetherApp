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
  normalized_nickname text := nullif(trim(p_nickname), '');
  normalized_avatar_url text := nullif(trim(p_avatar_url), '');
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  insert into public.profiles (user_id, nickname, avatar_url, invite_code)
  values (
    current_user_id,
    coalesce(normalized_nickname, '一起进步的你'),
    normalized_avatar_url,
    ''
  )
  on conflict (user_id) do update
  set
    nickname = coalesce(normalized_nickname, public.profiles.nickname),
    avatar_url = coalesce(normalized_avatar_url, public.profiles.avatar_url),
    updated_at = case
      when normalized_nickname is not null or normalized_avatar_url is not null
        then now()
      else public.profiles.updated_at
    end
  returning * into profile_row;

  return profile_row;
end;
$$;
