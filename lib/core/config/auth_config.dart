import '../../data/auth/auth_repository.dart';

class AuthConfig {
  const AuthConfig({
    this.mode = 'auto',
    this.url = '',
    this.key = '',
    this.redirectUrl = '',
  });
  const AuthConfig.fromEnvironment()
    : mode = const String.fromEnvironment('AUTH_MODE', defaultValue: 'auto'),
      url = const String.fromEnvironment('SUPABASE_URL'),
      key = const String.fromEnvironment('SUPABASE_ANON_KEY'),
      redirectUrl = const String.fromEnvironment('AUTH_REDIRECT_URL');

  final String mode;
  final String url;
  final String key;
  final String redirectUrl;

  bool get useSupabase =>
      mode != 'demo' && (mode != 'auto' || url.isNotEmpty || key.isNotEmpty);

  void validate() {
    if (!['auto', 'demo', 'supabase'].contains(mode)) {
      throw const AuthenticationFailure(
        'AUTH_MODE must be auto, demo, or supabase.',
      );
    }
    if (!useSupabase) return;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.host.isEmpty ||
        !['https', 'http'].contains(uri.scheme) ||
        key.trim().isEmpty) {
      throw const AuthenticationFailure(
        'Set both SUPABASE_URL and SUPABASE_ANON_KEY to enable authentication.',
      );
    }
    if (redirectUrl.isNotEmpty) {
      final redirect = Uri.tryParse(redirectUrl);
      if (redirect == null || !redirect.hasScheme || redirect.host.isEmpty) {
        throw const AuthenticationFailure(
          'AUTH_REDIRECT_URL must be an absolute callback URL.',
        );
      }
    }
  }
}
