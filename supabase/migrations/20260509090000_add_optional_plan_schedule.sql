alter table public.plans
  add column if not exists has_date_range boolean not null default true;
