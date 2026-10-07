import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_sabha/app.dart';
import 'package:smart_sabha/core/theme/app_theme.dart';
import 'package:smart_sabha/data/demo_civic_repository.dart';
import 'package:smart_sabha/state/app_controller.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets(
      'Theme button changes colors and preserves navigation at $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = AppController(DemoCivicRepository());
        await tester.runAsync(controller.bootstrap);
        addTearDown(controller.dispose);
        await tester.pumpWidget(SmartSabhaApp(controller: controller));

        for (final palette in [
          AppPalette.ocean,
          AppPalette.violet,
          AppPalette.teal,
        ]) {
          await tester.tap(find.textContaining('Theme:'));
          await tester.pumpAndSettle();
          expect(find.text('Theme: ${palette.label}'), findsOneWidget);
          final signIn = find.text('Sign in');
          expect(
            Theme.of(tester.element(signIn)).colorScheme.primary,
            palette.seed,
          );
          expect(find.text('Welcome to Smart Sabha'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        await tester.ensureVisible(find.text('Sign in'));
        await tester.tap(find.text('Sign in'));
        await tester.pumpAndSettle();
        expect(find.text('Password'), findsOneWidget);
        await tester.tap(find.textContaining('Theme:'));
        await tester.pumpAndSettle();
        expect(find.text('Password'), findsOneWidget);
        expect(
          Theme.of(tester.element(find.text('Password'))).colorScheme.primary,
          AppColors.ocean,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
