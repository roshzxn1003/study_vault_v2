class SupabaseConfig {
  // These come from environment variables via --dart-define-from-file=.env
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pjmlovhagvwnbfbwlupa.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBqbWxvdmhhZ3Z3bmJmYndsdXBhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk3NTE1NzMsImV4cCI6MjEwNTMyNzU3M30.FTVXgpIZbi94yxNzDOTY7KvMM_SOUZ40QLiIuv6zqXM',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
