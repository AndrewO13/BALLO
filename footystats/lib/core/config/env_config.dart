import '../constants/app_constants.dart';

/// Compile-time config from `--dart-define-from-file=.env`.
///
/// Run with: `flutter run --dart-define-from-file=.env`
class EnvConfig {
  EnvConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const publicSiteUrl = String.fromEnvironment(
    'PUBLIC_SITE_URL',
    defaultValue: AppConstants.publicSiteUrl,
  );

  static void validate() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing Supabase config. Copy .env.example to .env and run with '
        '`flutter run --dart-define-from-file=.env`.',
      );
    }
  }
}
