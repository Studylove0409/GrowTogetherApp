# Supabase Data Model

This backend model serves the Flutter app first. The older PRD references to WeChat mini-program cloud development are historical.

## Tables

### `profiles`

App-facing user profile keyed by `auth.users.id`.

- `user_id`: Supabase Auth user ID.
- `nickname`, `avatar_url`: visible profile fields.
- `invite_code`: permanent unique code used for partner binding.

### `couples`

Two-user relationship record.

- Only one active relationship is allowed per user through the binding RPC.
- Ending a relationship is modeled with `status = 'ended'`, not deletion.
- MVP does not expose unbind UI.

### `plans`

Growth plans owned by one couple relationship.

- `plan_type = 'personal'`: only `creator_id` can check in.
- `plan_type = 'shared'`: both partners can check in.
- `me` and `partner` are frontend perspectives, not stored backend types.
- Once checkins exist, dates can only be extended.
- Ended plans remain readable but cannot be edited, checked in, or reminded.

### `checkins`

Daily plan records.

- Unique by `(plan_id, user_id, checkin_date)`.
- `checkin_date` uses the Asia/Shanghai calendar day.
- Same-day checkins can be updated; past checkins are locked.
- Shared plan completion is derived from both partners having `completed` checkins on the same date.

### `reminders`

In-app reminders between active partners.

- MVP reminders are in-app messages, not phone push notifications.
- Remote push can be added later as a delivery channel without changing the core reminder concept.
- Same sender, receiver, plan, and Asia/Shanghai day is limited to three reminders.
- `gentle` and `strict` reminders are prompt-style and cannot be sent after the receiver completed today's plan.

## Public RPCs

- `create_profile_for_current_user(p_nickname, p_avatar_url)`
- `bind_partner_by_invite_code(p_invite_code)`
- `upsert_today_checkin(p_plan_id, p_status, p_mood, p_note)`
- `send_reminder(p_plan_id, p_type, p_content)`
- `mark_reminder_read(p_reminder_id)`

## Flutter Mapping

Recommended enum mapping:

- `PlanType.personal` ↔ `plans.plan_type = 'personal'`
- `PlanType.shared` ↔ `plans.plan_type = 'shared'`
- `PlanStatus.active` ↔ `plans.status = 'active'`
- `PlanStatus.ended` ↔ `plans.status = 'ended'`
- `CheckinStatus.completed` ↔ `checkins.status = 'completed'`
- `CheckinStatus.uncompleted` ↔ `checkins.status = 'uncompleted'`
- `CheckinMood.happy` ↔ `checkins.mood = 'happy'`
- `CheckinMood.normal` ↔ `checkins.mood = 'normal'`
- `CheckinMood.tired` ↔ `checkins.mood = 'tired'`
- `CheckinMood.great` ↔ `checkins.mood = 'great'`
- `CheckinMood.needHug` ↔ `checkins.mood = 'need_hug'`
- `ReminderType.gentle` ↔ `reminders.type = 'gentle'`
- `ReminderType.strict` ↔ `reminders.type = 'strict'`
- `ReminderType.encourage` ↔ `reminders.type = 'encourage'`
- `ReminderType.praise` ↔ `reminders.type = 'praise'`

Frontend owner mapping:

- `plans.plan_type = 'personal'` and `creator_id == currentUserId` → my plan.
- `plans.plan_type = 'personal'` and `creator_id == partnerUserId` → partner plan.
- `plans.plan_type = 'shared'` → shared plan.

## Integration Notes

- Supabase project: `GrowTogetherApp` (`kmeuuwqcngxhcfeevzsy`).
- Project URL: `https://kmeuuwqcngxhcfeevzsy.supabase.co`.
- Enable anonymous sign-ins in the Supabase project before testing auth.
- Flutter reads the publishable/anon key from `--dart-define=SUPABASE_ANON_KEY=...`.
- Use the publishable key in Flutter; never ship the service role key.
- Newly SQL-created tables in exposed schemas may need Data API grants in addition to RLS. The migration grants authenticated table access and relies on RLS for row access.
- Growth records are derived from `plans` and `checkins`; there is no `growth_records` source-of-truth table in MVP.

Run the app against Supabase with:

```bash
flutter run --dart-define=SUPABASE_ANON_KEY=<publishable-or-anon-key>
```

`SUPABASE_URL` is optional because the app defaults to the `GrowTogetherApp` project URL:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://kmeuuwqcngxhcfeevzsy.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable-or-anon-key>
```
