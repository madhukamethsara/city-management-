import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_sabha/core/theme/app_theme.dart';
import 'package:smart_sabha/data/civic_failure.dart';
import 'package:smart_sabha/data/demo_civic_repository.dart';
import 'package:smart_sabha/data/supabase_civic_repository.dart';
import 'package:smart_sabha/features/citizen/citizen_screens.dart';
import 'package:smart_sabha/models/domain_models.dart';
import 'package:smart_sabha/state/app_controller.dart';
import 'package:smart_sabha/state/app_scope.dart';

AppNotification notice(String id, {bool read = false, int day = 1}) =>
    AppNotification(
      id: id,
      title: 'Update $id',
      message: 'Your local report has been updated.',
      category: 'Reports',
      createdAt: DateTime(2026, 10, day),
      isRead: read,
      route: '/reports/example',
    );

class RefreshRepository extends DemoCivicRepository {
  final requests = <Completer<List<AppNotification>>>[];
  bool fail = false;
  List<AppNotification>? result;

  @override
  Future<List<AppNotification>> loadNotifications() async {
    if (fail) throw const CivicFailure('Unable to connect.');
    if (result != null) return result!;
    final gate = Completer<List<AppNotification>>();
    requests.add(gate);
    return gate.future;
  }
}

Future<AppController> signedIn(RefreshRepository repo) async {
  final app = AppController(repo);
  await app.bootstrap();
  await app.signIn(email: 'citizen@smart-sabha.lk', password: 'demo12345');
  return app;
}

void main() {
  test(
    'refresh orders and deduplicates notifications without replacing records',
    () async {
      final repo = RefreshRepository();
      final app = await signedIn(repo);
      addTearDown(app.dispose);
      final projects = app.projects;
      final reports = app.reports;
      repo.result = [notice('old'), notice('new', day: 2), notice('old')];
      await app.refreshNotifications();
      expect(app.notifications.map((n) => n.id), ['new', 'old']);
      expect(app.projects, projects);
      expect(app.reports, reports);
      expect(app.unreadNotificationCount, 2);
    },
  );

  test('older refresh cannot overwrite a newer refresh', () async {
    final repo = RefreshRepository();
    final app = await signedIn(repo);
    addTearDown(app.dispose);
    final old = app.refreshNotifications();
    final latest = app.refreshNotifications();
    repo.requests.last.complete([notice('latest')]);
    await latest;
    repo.requests.first.complete([notice('stale')]);
    await old;
    expect(app.notifications.single.id, 'latest');
  });

  test(
    'refresh preserves read confirmations made while snapshot is pending',
    () async {
      final repo = RefreshRepository()..result = [notice('read-me')];
      final app = await signedIn(repo);
      addTearDown(app.dispose);
      await app.refreshNotifications();
      repo.result = null;
      final refresh = app.refreshNotifications();
      await app.markNotificationRead('read-me');
      repo.requests.single.complete([
        notice('read-me'),
        notice('arrival', day: 2),
      ]);
      await refresh;
      expect(app.notifications.first.id, 'arrival');
      expect(app.notifications.last.isRead, isTrue);
      expect(app.unreadNotificationCount, 1);
    },
  );

  test('late notification refresh is discarded after account switch', () async {
    final repo = RefreshRepository();
    final app = await signedIn(repo);
    addTearDown(app.dispose);
    final refresh = app.refreshNotifications();
    await app.signOut();
    await app.signIn(email: 'officer@smart-sabha.lk', password: 'demo12345');
    final before = app.notifications;
    repo.requests.single.complete([notice('previous-account')]);
    await refresh;
    expect(app.notifications, before);
  });

  test('failed refresh retains existing notifications', () async {
    final repo = RefreshRepository()..result = [notice('retained')];
    final app = await signedIn(repo);
    addTearDown(app.dispose);
    await app.refreshNotifications();
    repo.fail = true;
    await expectLater(app.refreshNotifications(), throwsA(isA<CivicFailure>()));
    expect(app.notifications.single.id, 'retained');
  });

  test(
    'Supabase refresh calls only the recipient RPC and decodes read state',
    () async {
      final paths = <String>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'public',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(
            jsonEncode([
              {
                'id': 'server',
                'title': 'Report updated',
                'message': 'Repaired.',
                'category': 'Reports',
                'createdAt': '2026-10-07T10:00:00Z',
                'isRead': true,
                'route': '/reports/example',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final loaded = await SupabaseCivicRepository(
        client: client,
      ).loadNotifications();
      expect(paths, ['/rest/v1/rpc/civic_notifications']);
      expect(loaded.single.isRead, isTrue);
      expect(loaded.single.route, '/reports/example');
    },
  );

  testWidgets('hidden notification tab waits and refreshes on each opening', (
    tester,
  ) async {
    final repo = RefreshRepository();
    late AppController app;
    await tester.runAsync(() async => app = await signedIn(repo));
    addTearDown(app.dispose);
    Future<void> show(bool active) async {
      await tester.pumpWidget(
        AppScope(
          controller: app,
          child: MaterialApp(
            home: Scaffold(body: NotificationsScreen(active: active)),
          ),
        ),
      );
      await tester.pump();
    }

    await show(false);
    expect(repo.requests, isEmpty);
    await show(true);
    expect(repo.requests, hasLength(1));
    repo.requests.single.complete([notice('first-opening')]);
    await tester.pumpAndSettle();
    await show(false);
    expect(repo.requests, hasLength(1));
    await show(true);
    expect(repo.requests, hasLength(2));
    repo.requests.last.complete([notice('second-opening')]);
    await tester.pumpAndSettle();
    expect(find.text('Update second-opening'), findsOneWidget);
  });

  for (final size in [const Size(320, 640), const Size(1280, 900)]) {
    testWidgets(
      'refresh failure, retry and pull gesture fit $size with enlarged text',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repo = RefreshRepository()..fail = true;
        late AppController app;
        await tester.runAsync(() async => app = await signedIn(repo));
        addTearDown(app.dispose);
        await tester.pumpWidget(
          AppScope(
            controller: app,
            child: MaterialApp(
              theme: AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: const Scaffold(body: NotificationsScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Could not refresh notifications. Retry'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        repo.fail = false;
        repo.result = [];
        await tester.tap(find.text('Could not refresh notifications. Retry'));
        await tester.pumpAndSettle();
        expect(find.text('You are all caught up'), findsOneWidget);
        repo.result = [notice('arrival')];
        await tester.drag(find.byType(ListView), const Offset(0, 350));
        await tester.pumpAndSettle();
        expect(find.text('Update arrival'), findsOneWidget);
        repo.result = [notice('button')];
        await tester.tap(find.byTooltip('Refresh notifications'));
        await tester.pumpAndSettle();
        expect(find.text('Update button'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
