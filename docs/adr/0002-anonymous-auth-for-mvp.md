# Anonymous auth for MVP

The MVP will use Supabase Auth anonymous sign-in so the Flutter app can validate the core couple workflow before adding phone, WeChat, Apple, or other permanent login methods. Anonymous users still get stable Supabase user IDs and use the authenticated database role, while profile data, invite codes, couple binding, plans, checkins, and reminders live in app-owned tables that can later survive account linking.

## Account Upgrade Path

The Flutter app exposes an account protection card on the Profile tab. The intended flow is:

1. Start as an anonymous Supabase user.
2. Link an email identity with `auth.updateUser(UserAttributes(email: ...), emailRedirectTo: 'growtogether://auth-callback')`.
3. Confirm the email through Supabase Auth.
4. Set a password with `auth.updateUser(UserAttributes(password: ...))`.
5. On a new device, sign in with email and password.

This preserves the existing `auth.users.id`, so profile data, couple relationships, plans, checkins, reminders, and FCM token ownership do not need to be migrated during the upgrade.

Supabase project requirements:

- Anonymous sign-ins enabled.
- Email provider enabled.
- Manual identity linking enabled for anonymous-to-email upgrade.
- Email confirmation flow configured for the target environment.
- `growtogether://auth-callback` added to Authentication -> URL Configuration -> Redirect URLs so the verification email returns to the Android app.
