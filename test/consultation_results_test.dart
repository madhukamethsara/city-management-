import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_sabha/data/civic_failure.dart';
import 'package:smart_sabha/data/demo_civic_repository.dart';
import 'package:smart_sabha/features/community/community_screens.dart';
import 'package:smart_sabha/features/community/consultation_results_screen.dart';
import 'package:smart_sabha/models/consultation_results.dart';
import 'package:smart_sabha/models/domain_models.dart';
import 'package:smart_sabha/state/app_controller.dart';
import 'package:smart_sabha/state/app_scope.dart';

Consultation fixture() => Consultation(
  id: 'con-results',
  title: 'School crossing consultation',
  description: 'Help us choose a safer school crossing.',
  openingDate: DateTime(2020),
  closingDate: DateTime(2099),
  department: 'Roads',
  questions: const [
    ConsultationQuestion(
      id: 'choice',
      question: 'Preferred crossing?',
      options: ['Raised', 'Signals', 'Other'],
      allowsLongText: false,
    ),
    ConsultationQuestion(
      id: 'text',
      question: 'Explain your choice',
      options: [],
      allowsLongText: true,
    ),
  ],
  respondedUserIds: const {'resident-one', 'resident-two'},
  answers: const {
    'resident-one': {'choice': 'Raised', 'text': 'Secret written answer'},
    'resident-two': {'choice': 'Signals', 'text': 'Another private answer'},
  },
);

class ResultsRepository extends DemoCivicRepository {
  bool fail = false;
  Completer<ConsultationResults>? gate;
  int calls = 0;

  @override
  Future<ConsultationResults> consultationResults(String id) async {
    calls++;
    if (fail) {
      fail = false;
      throw const CivicFailure('Connection failed. Try again.');
    }
    return gate == null ? super.consultationResults(id) : gate!.future;
  }
}

Future<AppController> officer(ResultsRepository repo) async {
  final app = AppController(repo);
  await app.bootstrap();
  await app.signIn(email: 'officer@smart-sabha.lk', password: 'demo12345');
  await app.createConsultation(fixture());
  return app;
}

void main() {
  test('results count every answer and preserve zero-vote options', () async {
    final repo = ResultsRepository();
    final app = await officer(repo);
    addTearDown(app.dispose);
    final results = await app.consultationResults('con-results');
    expect(results.totalResponses, 2);
    expect(results.questions.first.optionCounts, {
      'Raised': 1,
      'Signals': 1,
      'Other': 0,
    });
    expect(results.questions.last.responseCount, 2);
    expect(results.questions.last.optionCounts, isEmpty);
    await app.signOut();
    await app.signIn(email: 'citizen@smart-sabha.lk', password: 'demo12345');
    await expectLater(
      app.consultationResults('con-results'),
      throwsA(isA<CivicFailure>()),
    );
    expect(
      repo.calls,
      1,
      reason: 'Residents must be rejected before reading results.',
    );
  });

  test('late results are rejected after switching accounts', () async {
    final repo = ResultsRepository();
    final app = await officer(repo);
    addTearDown(app.dispose);
    final result = await app.consultationResults('con-results');
    repo.gate = Completer<ConsultationResults>();
    final pending = app.consultationResults('con-results');
    final rejected = expectLater(pending, throwsA(isA<CivicFailure>()));
    await app.signOut();
    await app.signIn(email: 'citizen@smart-sabha.lk', password: 'demo12345');
    repo.gate!.complete(result);
    await rejected;
  });

  testWidgets('officer opens results from consultation details', (
    tester,
  ) async {
    final app = (await tester.runAsync(() => officer(ResultsRepository())))!;
    addTearDown(app.dispose);
    await tester.pumpWidget(
      AppScope(
        controller: app,
        child: MaterialApp(
          home: const ConsultationDetailScreen(consultationId: 'con-results'),
        ),
      ),
    );
    await tester.tap(find.byTooltip('View results'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 total responses'), findsOneWidget);
    expect(find.text('Raised: 1 (50.0%)'), findsOneWidget);
    expect(find.textContaining('Secret written answer'), findsNothing);
  });

  testWidgets(
    'narrow results view retries errors and hides results after account switch',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = ResultsRepository();
      final app = (await tester.runAsync(() => officer(repo)))!;
      addTearDown(app.dispose);
      repo.fail = true;
      await tester.pumpWidget(
        AppScope(
          controller: app,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const ConsultationResultsScreen(
              consultationId: 'con-results',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Connection failed. Try again.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 total responses'), findsOneWidget);
      await tester.tap(find.byTooltip('Refresh results'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(repo.calls, 3);
      expect(tester.takeException(), isNull);
      await app.signOut();
      await app.signIn(email: 'citizen@smart-sabha.lk', password: 'demo12345');
      await tester.pumpAndSettle();
      expect(find.text('Officer access required.'), findsOneWidget);
      expect(find.text('2 total responses'), findsNothing);
    },
  );
}
