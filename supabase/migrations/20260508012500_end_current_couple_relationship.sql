drop policy "Couples are visible to members" on public.couples;

create policy "Active couples are visible to members"
on public.couples for select
to authenticated
using (
  (select auth.uid()) is not null
  and status = 'active'
  and (select auth.uid()) in (user_a_id, user_b_id)
);

create or replace function private.end_current_couple_relationship()
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

  update public.couples
  set status = 'ended',
      ended_at = now()
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

create or replace function public.end_current_couple_relationship()
returns public.couples
language sql
security invoker
set search_path = public, private
as $$
  select private.end_current_couple_relationship();
$$;

revoke all on function private.end_current_couple_relationship() from public;
grant execute on function private.end_current_couple_relationship() to authenticated;
grant execute on function public.end_current_couple_relationship() to authenticated;
