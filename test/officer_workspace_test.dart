import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_sabha/app.dart';
import 'package:smart_sabha/state/app_controller.dart';

import 'auth_test.dart' show FakeAuth, resident;
import 'connected_session_test.dart' show SessionRepository;

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 900)]) {
    testWidgets('Connected officer workspace at ${size.width}', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = FakeAuth()..currentUser = resident;
      final controller = AppController(SessionRepository(auth), auth: auth);
      addTearDown(controller.dispose);
      await tester.runAsync(controller.bootstrap);
      await tester.pumpWidget(SmartSabhaApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('Officer workspace'), findsOneWidget);
      expect(find.text('Current case workload'), findsOneWidget);
      expect(find.text('Average resolution'), findsNothing);
      await tester.scrollUntilVisible(find.text('Manage complaints'), 250);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage complaints'));
      await tester.pumpAndSettle();
      expect(find.text('Complaint management'), findsOneWidget);
      await tester.tap(find.text('Assigned to me'));
      await tester.pumpAndSettle();
      final mine = controller.reports
          .where(
            (report) =>
                report.assignedOfficer == controller.currentUser!.fullName,
          )
          .length;
      expect(find.text('$mine cases'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('${controller.reports.length} cases'), findsOneWidget);
    });
  }
}
