import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_sabha/app.dart';
import 'package:smart_sabha/data/civic_failure.dart';
import 'package:smart_sabha/data/civic_repository.dart';
import 'package:smart_sabha/data/demo_civic_repository.dart';
import 'package:smart_sabha/data/report_codec.dart';
import 'package:smart_sabha/data/supabase_civic_repository.dart';
import 'package:smart_sabha/features/admin/admin_screens.dart';
import 'package:smart_sabha/features/reports/report_screens.dart';
import 'package:smart_sabha/features/onboarding/onboarding_screen.dart';
import 'package:smart_sabha/state/app_controller.dart';
import 'package:smart_sabha/state/app_scope.dart';
import 'package:smart_sabha/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'report comments survive a new controller using the same repository',
    () async {
      final repository = DemoCivicRepository();
      final first = AppController(repository);
      addTearDown(first.dispose);
      await first.bootstrap();
      await first.signIn(
        email: 'citizen@smart-sabha.lk',
        password: 'demo12345',
      );
      final report = first.myReports.first;
      await first.addReportComment(report.id, 'The issue is still present.');
      final second = AppController(repository);
      addTearDown(second.dispose);
      await second.bootstrap();
      expect(
        second.reportById(report.id)!.comments.single.message,
        'The issue is still present.',
      );
      final roundTrip = reportFromJson(
        jsonDecode(jsonEncode(reportToJson(second.reportById(report.id)!))),
      );
      expect(roundTrip.comments.single.message, 'The issue is still present.');
    },
  );

  test(
    'Supabase forwards report revision and uses server-generated response',
    () async {
      final demo = await DemoCivicRepository().loadInitialData();
      final report = demo.reports.first.copyWith(revision: 4);
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(reportToJson(report.copyWith(revision: 5))),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseCivicRepository(client: client);
      final saved = await repository.updateReport(report);
      expect(saved.revision, 5);
      expect(requests.single.url.path, '/rest/v1/rpc/civic_save_report');
      final body = jsonDecode(requests.single.body) as Map;
      expect(body['payload']['revision'], 4);
      expect(body['is_new'], false);
      expect(body.containsKey('notifications'), false);
    },
  );

  test('stale report edits produce an actionable conflict message', () async {
    final demo = await DemoCivicRepository().loadInitialData();
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          '{"code":"40001","message":"private details"}',
          409,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    final repository = SupabaseCivicRepository(client: client);
    await expectLater(
      repository.updateReport(demo.reports.first),
      throwsA(
        isA<CivicFailure>().having(
          (e) => e.message,
          'message',
          contains('Refresh'),
        ),
      ),
    );
    await expectLater(
      repository.saveChanges(CivicChanges(projects: demo.projects)),
      throwsA(isA<CivicFailure>()),
    );
  });

  for (final size in [
    const Size(320, 640),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    testWidgets('report and officer screens fit ${size.width}', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = AppController(DemoCivicRepository());
      addTearDown(controller.dispose);
      await tester.runAsync(controller.bootstrap);
      await controller.signIn(
        email: 'officer@smart-sabha.lk',
        password: 'demo12345',
      );
      for (final screen in <Widget>[
        const ReportWizardScreen(),
        const MyReportsScreen(),
        const OnboardingScreen(),
        ReportDetailScreen(reportId: controller.reports.first.id),
        const AdminShell(initialSection: AdminSection.reports),
      ]) {
        await tester.pumpWidget(
          AppScope(
            controller: controller,
            child: MaterialApp(
              theme: AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: screen,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.runtimeType} at $size',
        );
      }
    });
  }

  testWidgets('citizen navigation exposes a selected text label on phones', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController(DemoCivicRepository());
    addTearDown(controller.dispose);
    await tester.runAsync(controller.bootstrap);
    await controller.signIn(
      email: 'citizen@smart-sabha.lk',
      password: 'demo12345',
    );
    await tester.pumpWidget(SmartSabhaApp(controller: controller));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).labelBehavior,
      NavigationDestinationLabelBehavior.onlyShowSelected,
    );
    expect(tester.takeException(), isNull);
  });
}
