import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_sabha/core/config/auth_config.dart';
import 'package:smart_sabha/data/auth/auth_repository.dart';
import 'package:smart_sabha/data/auth/supabase_auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const config = AuthConfig(
  mode: 'supabase',
  url: 'https://example.supabase.co',
  key: 'test-public-key',
  redirectUrl: 'lk.smartsabha.app://auth-callback',
);

Map<String, Object?> authUser() => {
  'id': 'user-uuid',
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': 'resident@example.com',
  'created_at': '2026-01-01T00:00:00Z',
  'app_metadata': <String, Object?>{},
  'user_metadata': {'full_name': 'Resident'},
};

Map<String, Object?> session() {
  final expires =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return {
    'access_token':
        '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': 'user-uuid', 'exp': expires})}.test-signature',
    'refresh_token': 'test-refresh-token',
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': expires,
    'user': authUser(),
  };
}

void main() {
  test(
    'Supabase adapter sends passwords and persists SDK session through sign-in/out',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        config.url,
        config.key,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/token')) {
            return http.Response(jsonEncode(session()), 200);
          }
          return http.Response('{}', 200);
        }),
      );
      final repository = SupabaseAuthRepository(config, client: client);
      addTearDown(() async {
        repository.dispose();
        await client.dispose();
      });
      await repository.initialize();
      await repository.signIn(
        email: ' resident@example.com ',
        password: 'actual-password',
      );
      final login = requests.firstWhere(
        (item) => item.url.path.endsWith('/token'),
      );
      expect(jsonDecode(login.body)['password'], 'actual-password');
      expect(jsonDecode(login.body)['email'], 'resident@example.com');
      expect(repository.currentUser!.id, 'user-uuid');
      expect(client.auth.currentSession, isNotNull);
      await repository.signOut();
      expect(repository.currentUser, isNull);
      expect(client.auth.currentSession, isNull);
    },
  );

  test(
    'Supabase signup awaits email confirmation and reset uses configured callback',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        config.url,
        config.key,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(request.url.path.endsWith('/signup') ? authUser() : {}),
            200,
          );
        }),
      );
      final repository = SupabaseAuthRepository(config, client: client);
      addTearDown(() async {
        repository.dispose();
        await client.dispose();
      });
      await repository.initialize();
      expect(
        await repository.register(
          fullName: 'Resident',
          email: 'resident@example.com',
          password: 'signup-password',
        ),
        isTrue,
      );
      expect(repository.currentUser, isNull);
      final signup = requests.firstWhere(
        (item) => item.url.path.endsWith('/signup'),
      );
      expect(jsonDecode(signup.body)['password'], 'signup-password');
      expect(jsonDecode(signup.body)['data'], {'full_name': 'Resident'});
      await repository.sendPasswordReset('resident@example.com');
      final reset = requests.firstWhere(
        (item) => item.url.path.endsWith('/recover'),
      );
      expect(reset.url.queryParameters['redirect_to'], config.redirectUrl);
      expect(jsonDecode(reset.body)['email'], 'resident@example.com');
      await expectLater(
        repository.updatePassword('new-password'),
        throwsA(isA<AuthenticationFailure>()),
      );
      expect(requests.where((item) => item.method == 'PUT'), isEmpty);
    },
  );

  test(
    'verified recovery link enables a password update through the SDK',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        config.url,
        config.key,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode(authUser()), 200);
        }),
      );
      final repository = SupabaseAuthRepository(config, client: client);
      addTearDown(() async {
        repository.dispose();
        await client.dispose();
      });
      await repository.initialize();
      final tokens = session();
      final fragment = Uri(
        queryParameters: {
          'access_token': tokens['access_token'] as String,
          'refresh_token': tokens['refresh_token'] as String,
          'expires_in': '3600',
          'token_type': 'bearer',
          'type': 'recovery',
        },
      ).query;
      await client.auth.getSessionFromUrl(
        Uri.parse('${config.redirectUrl}#$fragment'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(repository.needsPasswordRecovery, isTrue);
      expect(repository.currentUser!.id, 'user-uuid');
      await repository.updatePassword('new-password');
      final update = requests.singleWhere((request) => request.method == 'PUT');
      expect(jsonDecode(update.body)['password'], 'new-password');
      expect(repository.needsPasswordRecovery, isFalse);
    },
  );

  test('Supabase errors are mapped without exposing server details', () async {
    final client = SupabaseClient(
      config.url,
      config.key,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'error_code': 'invalid_credentials',
            'msg': 'private server detail',
          }),
          400,
        ),
      ),
    );
    final repository = SupabaseAuthRepository(config, client: client);
    addTearDown(() async {
      repository.dispose();
      await client.dispose();
    });
    await repository.initialize();
    await expectLater(
      repository.signIn(
        email: 'resident@example.com',
        password: 'wrong-password',
      ),
      throwsA(
        isA<AuthenticationFailure>().having(
          (error) => error.message,
          'message',
          'Email or password is incorrect.',
        ),
      ),
    );
    expect(repository.currentUser, isNull);
  });
}
