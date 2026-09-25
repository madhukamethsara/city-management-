import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/auth_config.dart';
import '../../models/domain_models.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository extends AuthRepository {
  SupabaseAuthRepository(this.config, {SupabaseClient? client})
    : _client = client;

  final AuthConfig config;
  SupabaseClient? _client;
  StreamSubscription<AuthState>? _subscription;
  AppUser? _user;
  bool _recovery = false;
  bool _disposed = false;

  @override
  AppUser? get currentUser => _user;
  @override
  bool get needsPasswordRecovery => _recovery;

  String get _redirect => config.redirectUrl.isNotEmpty
      ? config.redirectUrl
      : kIsWeb
      ? '${Uri.base.origin}${Uri.base.path}'
      : 'lk.smartsabha.app://auth-callback';

  @override
  Future<void> initialize() async {
    config.validate();
    _client ??= (await Supabase.initialize(
      url: config.url,
      publishableKey: config.key,
      debug: false,
    )).client;
    if (_disposed) return;
    _subscription ??= _client!.auth.onAuthStateChange.listen(
      (state) {
        if (state.event == AuthChangeEvent.passwordRecovery) _recovery = true;
        if (state.event == AuthChangeEvent.signedOut) _recovery = false;
        _setSession(state.session);
      },
      onError: (Object error, StackTrace stack) {
        // Never leave a failed or expired session granting local access.
        if (_client!.auth.currentSession?.isExpired != false) _setSession(null);
      },
    );
    final session = _client!.auth.currentSession;
    if (session?.isExpired == true) {
      await _perform(() async {
        await _client!.auth.refreshSession();
      });
    }
    _setSession(_client!.auth.currentSession);
  }

  void _setSession(Session? session) {
    if (_disposed) return;
    _user = session == null || session.isExpired
        ? null
        : userFromAuth(session.user);
    if (_user == null) _recovery = false;
    notifyListeners();
  }

  /// Privileged roles are not read from editable user metadata. Civic role
  /// assignment will be connected to the backend permissions milestone.
  static AppUser? userFromAuth(User user) {
    if (user.appMetadata['is_active'] == false) return null;
    final name = user.userMetadata?['full_name'];
    return AppUser(
      id: user.id,
      fullName: name is String && name.trim().isNotEmpty
          ? name.trim()
          : 'Resident',
      email: user.email ?? '',
      role: UserRole.citizen,
      localAuthorityId: '',
      ward: '',
      gnDivision: '',
      phone: '',
      preferredLanguage: 'en',
      onboardingComplete: false,
      isActive: true,
    );
  }

  Future<T> _perform<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException catch (error) {
      final message = switch (error.code) {
        'invalid_credentials' => 'Email or password is incorrect.',
        'email_not_confirmed' => 'Confirm your email before signing in.',
        'weak_password' => 'Choose a stronger password and try again.',
        'over_email_send_rate_limit' || 'over_request_rate_limit' =>
          'Too many attempts. Please wait and try again.',
        _ => 'Authentication failed. Please try again.',
      };
      throw AuthenticationFailure(message);
    } on AuthenticationFailure {
      rethrow;
    } catch (_) {
      throw const AuthenticationFailure('Unable to connect. Please try again.');
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _perform(() async {
        final response = await _client!.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        _recovery = false;
        _setSession(response.session);
        if (_user == null) {
          await _client!.auth.signOut(scope: SignOutScope.local);
          throw const AuthenticationFailure(
            'This account is unavailable. Contact your local authority.',
          );
        }
      });

  @override
  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) => _perform(() async {
    final response = await _client!.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim()},
      emailRedirectTo: _redirect,
    );
    _setSession(response.session);
    return response.session == null;
  });

  @override
  Future<void> sendPasswordReset(String email) => _perform(
    () => _client!.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: _redirect,
    ),
  );

  @override
  Future<void> updatePassword(String password) => _perform(() async {
    if (!_recovery || _user == null) {
      throw const AuthenticationFailure(
        'Open a valid password-reset link from your email first.',
      );
    }
    await _client!.auth.updateUser(UserAttributes(password: password));
    _recovery = false;
    notifyListeners();
  });

  @override
  Future<void> signOut() => _perform(() async {
    await _client!.auth.signOut(scope: SignOutScope.local);
    _recovery = false;
    _setSession(null);
  });

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
