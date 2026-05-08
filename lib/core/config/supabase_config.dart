class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kmeuuwqcngxhcfeevzsy.supabase.co',
  );

  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const emailRedirectTo = 'growtogether://auth-callback';

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
