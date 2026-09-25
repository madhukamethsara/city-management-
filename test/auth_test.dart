import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_sabha/app.dart';
import 'package:smart_sabha/core/config/auth_config.dart';
import 'package:smart_sabha/data/auth/auth_repository.dart';
import 'package:smart_sabha/data/auth/supabase_auth_repository.dart';
import 'package:smart_sabha/data/demo_civic_repository.dart';
import 'package:smart_sabha/models/domain_models.dart';
import 'package:smart_sabha/state/app_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

const resident = AppUser(
  id: 'real-user',
  fullName: 'Resident',
  email: 'resident@example.com',
  role: UserRole.citizen,
  localAuthorityId: '',
  ward: '',
  gnDivision: '',
  phone: '',
  preferredLanguage: 'en',
  onboardingComplete: false,
  isActive: true,
);

class FakeAuth extends AuthRepository {
  @override
  AppUser? currentUser;
  @override
  bool needsPasswordRecovery = false;
  bool rejectLogin = false;
  bool rejectSignOut = false;
  bool confirmationRequired = true;
  String? submittedPassword;
  String? resetEmail;
  int passwordUpdates = 0;
  void emit(AppUser? user, {bool recovery = false}) {
    currentUser = user;
    needsPasswordRecovery = recovery;
    notifyListeners();
  }

  @override
  Future<void> initialize() async {
    notifyListeners();
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    submittedPassword = password;
    if (rejectLogin) {
      throw const AuthenticationFailure('Email or password is incorrect.');
    }
    emit(resident);
  }

  @override
  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    submittedPassword = password;
    if (!confirmationRequired) emit(resident);
    return confirmationRequired;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    resetEmail = email;
  }

  @override
  Future<void> updatePassword(String password) async {
    submittedPassword = password;
    passwordUpdates++;
    emit(currentUser);
  }

  @override
  Future<void> signOut() async {
    if (rejectSignOut) {
      throw const AuthenticationFailure('Unable to connect. Please try again.');
    }
    emit(null);
  }
}

void main() {
  test(
    'configuration does not silently fall back when partially configured',
    () {
      expect(const AuthConfig().useSupabase, isFalse);
      expect(const AuthConfig(mode: 'supabase').useSupabase, isTrue);
      expect(
        const AuthConfig(url: 'https://example.supabase.co').useSupabase,
        isTrue,
      );
      expect(
        const AuthConfig(url: 'https://example.supabase.co').validate,
        throwsA(isA<AuthenticationFailure>()),
      );
      expect(
        const AuthConfig(mode: 'wrong').validate,
        throwsA(isA<AuthenticationFailure>()),
      );
    },
  );

  test(
    'invalid live configuration reaches a recoverable startup error',
    () async {
      final app = AppController(
        DemoCivicRepository(),
        auth: SupabaseAuthRepository(const AuthConfig(mode: 'supabase')),
      );
      addTearDown(app.dispose);
      await app.bootstrap();
      expect(app.isLoading, isFalse);
      expect(app.startupError, contains('SUPABASE_URL'));
      expect(app.hasSession, isFalse);
      expect(app.isDemoAuth, isFalse);
    },
  );

  test('auth metadata cannot grant an officer role or complete onboarding', () {
    final user = User(
      id: 'uuid',
      appMetadata: {},
      userMetadata: {
        'full_name': 'Resident',
        'role': 'platformAdmin',
        'onboarding_complete': true,
      },
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    );
    final mapped = SupabaseAuthRepository.userFromAuth(user)!;
    expect(mapped.role, UserRole.citizen);
    expect(mapped.onboardingComplete, isFalse);
    final disabled = User(
      id: 'uuid',
      appMetadata: {'is_active': false},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    );
    expect(SupabaseAuthRepository.userFromAuth(disabled), isNull);
  });

  test(
    'restores identity and handles confirmation without a fake session',
    () async {
      final auth = FakeAuth()..currentUser = resident;
      final app = AppController(DemoCivicRepository(), auth: auth);
      addTearDown(app.dispose);
      await app.bootstrap();
      expect(app.currentUser!.id, resident.id);
      await app.signOut();
      final confirmation = await app.register(
        fullName: 'Resident',
        email: resident.email,
        password: 'correct-password',
      );
      expect(confirmation, isTrue);
      expect(auth.submittedPassword, 'correct-password');
      expect(app.hasSession, isFalse);
      auth.emit(resident);
      expect(app.hasSession, isTrue);
      auth.emit(null);
      expect(app.hasSession, isFalse);
    },
  );

  test(
    'reset requests delegate and password updates require a recovery session',
    () async {
      final auth = FakeAuth();
      final app = AppController(DemoCivicRepository(), auth: auth);
      addTearDown(app.dispose);
      await app.bootstrap();
      await app.sendPasswordReset(resident.email);
      expect(auth.resetEmail, resident.email);
      await expectLater(
        app.updatePassword('new-password'),
        throwsA(isA<AuthenticationFailure>()),
      );
      expect(auth.passwordUpdates, 0);
      auth.emit(resident, recovery: true);
      await app.updatePassword('new-password');
      expect(auth.submittedPassword, 'new-password');
      expect(app.needsPasswordRecovery, isFalse);
    },
  );

  test('failed live sign-in cannot select a seeded officer', () async {
    final auth = FakeAuth()..rejectLogin = true;
    final app = AppController(DemoCivicRepository(), auth: auth);
    addTearDown(app.dispose);
    await app.bootstrap();
    await expectLater(
      app.signIn(email: 'officer@smart-sabha.lk', password: 'wrong-password'),
      throwsA(isA<AuthenticationFailure>()),
    );
    expect(app.hasSession, isFalse);
    expect(app.isOfficer, isFalse);
  });

  test(
    'failed sign-out leaves the current session available for retry',
    () async {
      final auth = FakeAuth()
        ..currentUser = resident
        ..rejectSignOut = true;
      final app = AppController(DemoCivicRepository(), auth: auth);
      addTearDown(app.dispose);
      await app.bootstrap();
      await expectLater(app.signOut(), throwsA(isA<AuthenticationFailure>()));
      expect(app.currentUser!.id, resident.id);
      auth.rejectSignOut = false;
      await app.signOut();
      expect(app.hasSession, isFalse);
    },
  );

  test('demo rejects unknown accounts and incorrect passwords', () async {
    final app = AppController(DemoCivicRepository());
    addTearDown(app.dispose);
    await app.bootstrap();
    await expectLater(
      app.signIn(email: 'unknown-officer@example.com', password: 'demo12345'),
      throwsA(isA<AuthenticationFailure>()),
    );
    await expectLater(
      app.signIn(email: 'officer@smart-sabha.lk', password: 'wrong-password'),
      throwsA(isA<AuthenticationFailure>()),
    );
    expect(app.hasSession, isFalse);
    await expectLater(
      app.sendPasswordReset('someone@example.com'),
      throwsA(isA<AuthenticationFailure>()),
    );
  });

  testWidgets('recovery and sign-out events replace the current route', (
    tester,
  ) async {
    final auth = FakeAuth();
    final app = AppController(DemoCivicRepository(), auth: auth);
    addTearDown(app.dispose);
    await tester.runAsync(app.bootstrap);
    await tester.pumpWidget(SmartSabhaApp(controller: app));
    auth.emit(resident, recovery: true);
    await tester.pumpAndSettle();
    expect(find.text('Choose a new password'), findsOneWidget);
    auth.emit(null);
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Smart Sabha'), findsOneWidget);
    expect(find.text('Choose a new password'), findsNothing);
  });

  testWidgets('live login hides demo shortcuts and retries after rejection', (
    tester,
  ) async {
    final auth = FakeAuth()..rejectLogin = true;
    final app = AppController(DemoCivicRepository(), auth: auth);
    addTearDown(app.dispose);
    await tester.runAsync(app.bootstrap);
    await tester.pumpWidget(SmartSabhaApp(controller: app));
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Demo accounts'), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(0), resident.email);
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    expect(app.hasSession, isFalse);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Sign in'))
          .onPressed,
      isNotNull,
    );
  });
}
