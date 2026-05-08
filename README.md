# GrowTogetherApp

「一起进步呀」是一个 Android-first Flutter app，面向情侣共同成长场景：绑定伴侣、创建计划、每日打卡、互相提醒，并查看成长记录。

## Current Stack

- Flutter / Dart
- Supabase Auth anonymous sign-in
- Supabase Postgres, RLS, RPC, Realtime
- Supabase Edge Function for partner reminder push
- Firebase Cloud Messaging for Android push notifications
- `flutter_local_notifications` for local plan reminder notifications

The app uses `SupabaseStore` only when `SUPABASE_ANON_KEY` is provided through `--dart-define`. Without it, the app intentionally falls back to `MockStore`, which is useful for local UI tests but must not be used for release APKs.

## Build And Run

Run against Supabase:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://kmeuuwqcngxhcfeevzsy.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
```

Build the Android release APK with the checked-in script:

```bash
SUPABASE_ANON_KEY=sb_publishable_... scripts/build_release_android.sh
```

The script writes:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Do not use plain `flutter build apk --release` for release testing. It omits the Supabase key and produces a MockStore/static-data build.

## Verification

```bash
flutter analyze
flutter test
```

For a release candidate, install the APK on two Android devices and verify:

- both devices open the Supabase-backed app, not mock data
- binding works with invite codes
- plans sync between partners
- checkins update the home page
- reminder badge clears and stays cleared after restart
- local plan reminder notifications fire
- partner reminders are delivered through FCM after `fcm_token` is saved
