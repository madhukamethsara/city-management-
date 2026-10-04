import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_sabha/core/theme/app_theme.dart';
import 'package:smart_sabha/data/civic_failure.dart';
import 'package:smart_sabha/data/demo_civic_repository.dart';
import 'package:smart_sabha/features/admin/admin_screens.dart';
import 'package:smart_sabha/models/domain_models.dart';
import 'package:smart_sabha/state/app_controller.dart';
import 'package:smart_sabha/state/app_scope.dart';

class ConnectedAdminRepository extends DemoCivicRepository {
  @override
  bool get isPersistent => true;
}

void main() {
  test('regular officers cannot change privileges or departments', () async {
    final app = AppController(DemoCivicRepository());
    addTearDown(app.dispose);
    await app.bootstrap();
    await app.signIn(email: 'dilan.w@smart-sabha.lk', password: 'demo12345');
    expect(app.canManageUsers, isFalse);
    expect(app.canManageDepartments, isFalse);
    final resident = app.users.firstWhere(
      (u) => u.role == UserRole.verifiedResident,
    );
    await expectLater(
      app.changeUserRole(resident.id, UserRole.officer),
      throwsA(isA<CivicFailure>()),
    );
    await expectLater(
      app.updateDepartment(app.departments.first),
      throwsA(isA<CivicFailure>()),
    );
    await app.signIn(email: 'officer@smart-sabha.lk', password: 'demo12345');
    await expectLater(
      app.toggleUserActive(app.currentUser!.id),
      throwsA(isA<CivicFailure>()),
    );
    await expectLater(
      app.changeUserRole(resident.id, UserRole.platformAdmin),
      throwsA(isA<CivicFailure>()),
    );
  });

  test('resolution metrics reflect case history', () async {
    final app = AppController(DemoCivicRepository());
    addTearDown(app.dispose);
    await app.bootstrap();
    final resolved = app.reports.where(
      (r) => r.status == ReportStatus.resolved,
    );
    final expected =
        resolved.fold<double>(0, (sum, r) {
          final updates = r.updates.where(
            (u) => u.status == ReportStatus.resolved,
          );
          final date = updates.isEmpty ? r.lastUpdated : updates.last.date;
          return sum + date.difference(r.submittedAt).inMinutes / 1440;
        }) /
        resolved.length;
    expect(app.averageResolutionDays, (expected * 10).round() / 10);
  });

  for (final size in [const Size(320, 640), const Size(1280, 900)]) {
    testWidgets('connected admin management and analytics fit $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final app = AppController(ConnectedAdminRepository());
      addTearDown(app.dispose);
      await tester.runAsync(app.bootstrap);
      await app.signIn(email: 'officer@smart-sabha.lk', password: 'demo12345');
      expect(app.canManageUsers, isTrue);
      await tester.pumpWidget(
        AppScope(
          controller: app,
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(size: size, textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const AdminShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(NavigationRail),
        size.width >= 1000 ? findsOneWidget : findsNothing,
      );
      for (final entry in [
        ('Departments', 'Department management'),
        ('Users', 'User management'),
        ('Analytics', 'Authority analytics'),
      ]) {
        if (size.width < 1000) {
          await tester.tap(find.byTooltip('Open navigation menu'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(entry.$1));
        await tester.pumpAndSettle();
        expect(find.text(entry.$2), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
