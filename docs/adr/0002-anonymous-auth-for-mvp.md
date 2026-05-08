# Anonymous auth for MVP

The MVP will use Supabase Auth anonymous sign-in so the Flutter app can validate the core couple workflow before adding phone, WeChat, Apple, or other permanent login methods. Anonymous users still get stable Supabase user IDs and use the authenticated database role, while profile data, invite codes, couple binding, plans, checkins, and reminders live in app-owned tables that can later survive account linking.
