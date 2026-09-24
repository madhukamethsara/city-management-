import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:smart_sabha/app.dart';
import 'package:smart_sabha/data/demo_civic_repository.dart';
import 'package:smart_sabha/state/app_controller.dart';

void main() {
  testWidgets('Welcome screen opens the sign-in form', (tester) async {
    final controller = AppController(DemoCivicRepository());
    await tester.runAsync(controller.bootstrap);
    addTearDown(controller.dispose);

    await tester.pumpWidget(SmartSabhaApp(controller: controller));
    expect(find.text('Welcome to Smart Sabha'), findsOneWidget);
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Smart Sabha'), findsNothing);
    expect(find.text('Password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Welcome screen scrolls on a small phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController(DemoCivicRepository());
    await tester.runAsync(controller.bootstrap);
    addTearDown(controller.dispose);
    await tester.pumpWidget(SmartSabhaApp(controller: controller));
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
