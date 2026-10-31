/// Backend settings, passed at build time so no keys live in the source.
///
/// Your own Node.js server (server/ folder):
///   flutter run --dart-define=API_URL=http://10.0.2.2:3000
///
/// Or Supabase:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=your-anon-key
///
/// Without any of them the app uses the demo auth (codes are shown on screen).
/// If both API_URL and Supabase are given, API_URL wins.
abstract final class AppConfig {
  // static const apiUrl = String.fromEnvironment('API_URL');
  static const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://shop-desk-pos-gamma.vercel.app',
);
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get hasApi => apiUrl.isNotEmpty;
  static bool get hasSupabase => !hasApi && supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// True when no real server is configured: codes are shown on screen, no email is sent.
  static bool get isDemo => !hasApi && !hasSupabase;
}
