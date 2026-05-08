create table public.couple_invitations (
  id uuid primary key default gen_random_uuid(),
  from_user_id uuid not null references auth.users (id) on delete cascade,
  to_user_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'pending' check (
    status in ('pending', 'accepted', 'declined', 'cancelled', 'expired')
  ),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  constraint couple_invitations_distinct_users check (from_user_id <> to_user_id),
  constraint couple_invitations_responded_at_required check (
    (status = 'pending' and responded_at is null)
    or (status <> 'pending' and responded_at is not null)
  )
);

create unique index couple_invitations_unique_pending_pair_idx
  on public.couple_invitations (
    least(from_user_id, to_user_id),
    greatest(from_user_id, to_user_id)
  )
  where status = 'pending';

create index couple_invitations_to_status_idx
  on public.couple_invitations (to_user_id, status, created_at desc);

create index couple_invitations_from_status_idx
  on public.couple_invitations (from_user_id, status, created_at desc);

alter table public.couple_invitations enable row level security;

create policy "Couple invitations are visible to sender and receiver"
on public.couple_invitations for select
to authenticated
using (
  (select auth.uid()) is not null
  and (select auth.uid()) in (from_user_id, to_user_id)
);

create or replace function private.create_couple_invitation_by_invite_code(
  p_invite_code text
)
returns public.couple_invitations
language plpgsql
security definer
set search_path = public, private
as $$
declare
  current_user_id uuid := auth.uid();
  target_user_id uuid;
  invitation_row public.couple_invitations%rowtype;
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  perform private.create_profile_for_current_user(null, null);

  select p.user_id
  into target_user_id
  from public.profiles p
  where p.invite_code = upper(trim(p_invite_code));

  if target_user_id is null then
    raise exception 'invite code not found';
  end if;

  if target_user_id = current_user_id then
    raise exception 'cannot invite yourself';
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

  select *
  into invitation_row
  from public.couple_invitations i
  where i.status = 'pending'
    and current_user_id in (i.from_user_id, i.to_user_id)
    and target_user_id in (i.from_user_id, i.to_user_id)
  order by i.created_at desc
  limit 1;

  if invitation_row.id is not null then
    return invitation_row;
  end if;

  insert into public.couple_invitations (from_user_id, to_user_id)
  values (current_user_id, target_user_id)
  returning * into invitation_row;

  return invitation_row;
end;
$$;

create or replace function public.create_couple_invitation_by_invite_code(
  p_invite_code text
)
returns public.couple_invitations
language sql
security invoker
set search_path = public, private
as $$
  select *
  from private.create_couple_invitation_by_invite_code(p_invite_code);
$$;

create or replace function private.accept_couple_invitation(p_invitation_id uuid)
returns public.couple_invitations
language plpgsql
security definer
set search_path = public, private
as $$
declare
  current_user_id uuid := auth.uid();
  invitation_row public.couple_invitations%rowtype;
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  select *
  into invitation_row
  from public.couple_invitations i
  where i.id = p_invitation_id
    and i.status = 'pending'
  for update;

  if invitation_row.id is null then
    raise exception 'pending invitation not found';
  end if;

  if invitation_row.to_user_id <> current_user_id then
    raise exception 'only the receiver can accept an invitation';
  end if;

  if invitation_row.from_user_id::text < invitation_row.to_user_id::text then
    perform pg_advisory_xact_lock(hashtext(invitation_row.from_user_id::text));
    perform pg_advisory_xact_lock(hashtext(invitation_row.to_user_id::text));
  else
    perform pg_advisory_xact_lock(hashtext(invitation_row.to_user_id::text));
    perform pg_advisory_xact_lock(hashtext(invitation_row.from_user_id::text));
  end if;

  if private.active_couple_id_for_user(invitation_row.from_user_id) is not null
    or private.active_couple_id_for_user(invitation_row.to_user_id) is not null
  then
    raise exception 'user already has an active couple relationship';
  end if;

  insert into public.couples (user_a_id, user_b_id)
  values (
    least(invitation_row.from_user_id, invitation_row.to_user_id),
    greatest(invitation_row.from_user_id, invitation_row.to_user_id)
  );

  update public.couple_invitations
  set status = 'accepted',
      responded_at = now()
  where id = invitation_row.id
  returning * into invitation_row;

  return invitation_row;
end;
$$;

create or replace function public.accept_couple_invitation(p_invitation_id uuid)
returns public.couple_invitations
language sql
security invoker
set search_path = public, private
as $$
  select *
  from private.accept_couple_invitation(p_invitation_id);
$$;

create or replace function private.decline_couple_invitation(p_invitation_id uuid)
returns public.couple_invitations
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  invitation_row public.couple_invitations%rowtype;
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  update public.couple_invitations
  set status = 'declined',
      responded_at = now()
  where id = p_invitation_id
    and to_user_id = current_user_id
    and status = 'pending'
  returning * into invitation_row;

  if invitation_row.id is null then
    raise exception 'pending invitation not found';
  end if;

  return invitation_row;
end;
$$;

create or replace function public.decline_couple_invitation(p_invitation_id uuid)
returns public.couple_invitations
language sql
security invoker
set search_path = public, private
as $$
  select *
  from private.decline_couple_invitation(p_invitation_id);
$$;

create or replace function public.bind_partner_by_invite_code(p_invite_code text)
returns public.couples
language plpgsql
security invoker
set search_path = public
as $$
begin
  raise exception 'direct binding is disabled; create a couple invitation instead';
end;
$$;

revoke execute on function public.bind_partner_by_invite_code(text) from public;
revoke execute on function public.bind_partner_by_invite_code(text) from anon;
revoke execute on function public.bind_partner_by_invite_code(text) from authenticated;

revoke all on function private.create_couple_invitation_by_invite_code(text) from public;
revoke all on function private.accept_couple_invitation(uuid) from public;
revoke all on function private.decline_couple_invitation(uuid) from public;

grant execute on function private.create_couple_invitation_by_invite_code(text) to authenticated;
grant execute on function private.accept_couple_invitation(uuid) to authenticated;
grant execute on function private.decline_couple_invitation(uuid) to authenticated;
grant execute on function public.create_couple_invitation_by_invite_code(text) to authenticated;
grant execute on function public.accept_couple_invitation(uuid) to authenticated;
grant execute on function public.decline_couple_invitation(uuid) to authenticated;
