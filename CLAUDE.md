# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## User preferences

- 称呼用户为"道友"
- 禁止批量删除文件或目录，只能一次删除一个明确路径的文件

## Build & run

```bash
# Run on a connected device/emulator (requires Supabase anon key)
flutter run \
  --dart-define=SUPABASE_URL=https://kmeuuwqcngxhcfeevzsy.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_...

# Run on a specific device
flutter run -d <device-id> \
  --dart-define=SUPABASE_URL=https://kmeuuwqcngxhcfeevzsy.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_...

# Build Android release APK against Supabase.
# Do not use plain `flutter build apk --release`; that creates a MockStore/static-data build.
SUPABASE_ANON_KEY=sb_publishable_... scripts/build_release_android.sh

# Analyze
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart
```

The app uses anonymous auth with Supabase — no email/password login. The `SUPABASE_ANON_KEY` dart-define is required; without it the app falls back to `MockStore`.
Release APKs must be built with `scripts/build_release_android.sh` so the Supabase dart-defines are always included.

## Architecture

### Store abstraction

The core pattern is a **Store interface** (`lib/data/store/store.dart`) that decouples the UI from the data source. Two implementations:

- **`SupabaseStore`** (`lib/data/supabase/supabase_store.dart`) — production, backed by Supabase. Subscribes to Postgres realtime changes and auto-refreshes local state.
- **`MockStore`** (`lib/data/mock/mock_store.dart`) — development/fallback, in-memory data.

The store is injected at the root via `Provider<Store>.value` in `app.dart`. The switch is gated by `SupabaseConfig.isConfigured` (checks whether `SUPABASE_ANON_KEY` was provided). All UI pages interact only with the `Store` abstract class — never with a concrete implementation directly.

### Data layer

- `data/models/` — Plain Dart models: `Plan`, `Reminder`, `Profile`, `CheckinRecord`, `CoupleInvitation`.
- `data/supabase/*_repository.dart` — One repository per domain entity. Each repository wraps Supabase queries, and accepts an optional `SupabaseClient` for testability.
- `data/supabase/supabase_store.dart` — Orchestrates repositories, maintains local caches (`_plans`, `_reminders`, `_profile`), and wires up realtime subscriptions.

### UI layer

- `features/` — Screen-level pages organized by domain: `home/`, `plans/`, `checkin/`, `profile/`, `reminders/`.
- `shared/widgets/` — Reusable components (`AppCard`, `PrimaryButton`, `ReminderCard`, `PlanListTile`, etc.).
- `core/theme/` — Design tokens: `AppColors`, `AppSpacing`, `AppTextStyles`, `AppTheme`.
- `core/notification/` — Local notifications (`NotificationService`) and FCM push (`FcmService`).

### Backend (Supabase)

- **Database migrations** are in `supabase/migrations/`. Applied to the remote Supabase project via MCP or Supabase CLI.
- **Edge Function** `send_reminder_notification` at `supabase/functions/send_reminder_notification/index.ts`. Triggered by a Postgres AFTER INSERT trigger on `reminders` via `pg_net.http_post`. It fetches the recipient's FCM token from `profiles` and calls Firebase Cloud Messaging.
- The `notify_reminder_received` trigger wraps `net.http_post` in a `BEGIN...EXCEPTION` block that converts failures to WARNINGs — so the INSERT always succeeds even if the push fails.
- `send_reminder` RPC inserts into `reminders`; validation is in `validate_reminder_insert` trigger.

### Key data flows

1. **Create plan**: `CreatePlanPage` → `Store.createPlan()` → Supabase `plan_repository.createPlan()` → `profiles` RPC → realtime → local cache refresh.
2. **Send reminder**: `PlanDetailPage._showRemindSheet` → `Store.sendReminder()` → `reminder_repository.sendReminder()` → `send_reminder` RPC → INSERT into `reminders` → trigger calls Edge Function → FCM push.
3. **Realtime sync**: `SupabaseStore._subscribeRealtime()` listens to Postgres changes on `plans`, `checkins`, `reminders` tables and auto-refreshes local caches.

## Tests

Tests use `MockStore` or inline `Store` subclasses to avoid Supabase dependencies. When testing UI with custom Store behavior, extend `Store` and override only the methods needed (see `_BlockedPromptReminderStore` and `_ReminderBadgeStore` in `test/widget_test.dart`).

The `PlanDetailPage` test for blocked reminders verifies that a friendly message is shown instead of the raw PostgrestException — no new error handling should regress that test.
