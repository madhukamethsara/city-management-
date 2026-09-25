import '../../models/domain_models.dart';
import 'package:flutter/foundation.dart';

class AuthenticationFailure implements Exception {
  const AuthenticationFailure(this.message);
  final String message;
}

/// Authentication is independent of civic data and its demo repository.
abstract class AuthRepository extends ChangeNotifier {
  AppUser? get currentUser;
  bool get needsPasswordRecovery;
  Future<void> initialize();
  Future<void> signIn({required String email, required String password});

  /// Returns true if email confirmation is required before signing in.
  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  });
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String password);
  Future<void> signOut();
}
