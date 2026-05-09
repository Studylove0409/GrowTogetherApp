alter table public.checkins
  drop constraint if exists checkins_plan_id_fkey;

alter table public.checkins
  add constraint checkins_plan_id_fkey
  foreign key (plan_id) references public.plans (id) on delete cascade;

alter table public.reminders
  drop constraint if exists reminders_plan_id_fkey;

alter table public.reminders
  add constraint reminders_plan_id_fkey
  foreign key (plan_id) references public.plans (id) on delete cascade;

alter table public.focus_sessions
  drop constraint if exists focus_sessions_plan_id_fkey;

alter table public.focus_sessions
  add constraint focus_sessions_plan_id_fkey
  foreign key (plan_id) references public.plans (id) on delete cascade;

drop policy if exists "Plan owners can delete plans" on public.plans;

create policy "Plan owners can delete plans"
on public.plans for delete
to authenticated
using (
  (select auth.uid()) is not null
  and private.is_active_couple_member(couple_id, (select auth.uid()))
  and (
    creator_id = (select auth.uid())
    or plan_type = 'shared'
  )
);

grant delete on public.plans to authenticated;
