alter table public.plans
  add column if not exists repeat_type text not null default 'daily';

alter table public.plans
  drop constraint if exists plans_repeat_type_check;

alter table public.plans
  add constraint plans_repeat_type_check
  check (repeat_type in ('once', 'daily'));

update public.plans
set repeat_type = 'daily'
where repeat_type is null;
