alter table public.profiles
add column if not exists notification_settings jsonb not null default '{
  "dailyReminderEnabled": true,
  "dailyReminderTime": "20:30",
  "partnerActivityReminderEnabled": true,
  "doNotDisturbEnabled": false,
  "doNotDisturbStart": "22:30",
  "doNotDisturbEnd": "08:00"
}'::jsonb;

update public.profiles
set notification_settings = coalesce(
  notification_settings,
  '{
    "dailyReminderEnabled": true,
    "dailyReminderTime": "20:30",
    "partnerActivityReminderEnabled": true,
    "doNotDisturbEnabled": false,
    "doNotDisturbStart": "22:30",
    "doNotDisturbEnd": "08:00"
  }'::jsonb
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_notification_settings_is_object'
  ) then
    alter table public.profiles
    add constraint profiles_notification_settings_is_object
    check (jsonb_typeof(notification_settings) = 'object');
  end if;
end $$;
