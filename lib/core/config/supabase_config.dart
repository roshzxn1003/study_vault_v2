class SupabaseConfig {
  // These come from environment variables via --dart-define-from-file=.env
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qzakyjprqtphofrutoxp.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6YWt5anBycXRwaG9mcnV0b3hwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMxOTc4NDgsImV4cCI6MjEwODc3Mzg0OH0.khtHtByTmUywkgA2FgAR7pXT_gU5mr9egtwYE8H4HMk',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
