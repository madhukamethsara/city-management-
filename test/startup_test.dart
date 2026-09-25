import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_sabha/app.dart';
import 'package:smart_sabha/data/demo_civic_repository.dart';
import 'package:smart_sabha/data/civic_repository.dart';
import 'package:smart_sabha/state/app_controller.dart';

class ControlledRepository extends DemoCivicRepository {
  Completer<InitialCivicData> pending = Completer<InitialCivicData>();
  int calls = 0;

  @override
  Future<InitialCivicData> loadInitialData() {
    calls++;
    return pending.future;
  }
}

void main() {
  testWidgets('startup failure can retry and reach the welcome screen', (
    tester,
  ) async {
    final repository = ControlledRepository();
    final controller = AppController(repository);
    addTearDown(controller.dispose);
    final initialLoad = controller.bootstrap();
    await tester.pumpWidget(SmartSabhaApp(controller: controller));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await controller.bootstrap();
    expect(repository.calls, 1);
    repository.pending.completeError(StateError('private backend details'));
    await initialLoad;
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('private backend details'), findsNothing);
    expect(controller.isLoading, isFalse);

    repository.pending = Completer<InitialCivicData>();
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(repository.calls, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(controller.startupError, isNull);
    final data = await tester.runAsync(DemoCivicRepository().loadInitialData);
    repository.pending.complete(data!);
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Smart Sabha'), findsOneWidget);
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
