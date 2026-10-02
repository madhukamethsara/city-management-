import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_sabha/data/civic_failure.dart';
import 'package:smart_sabha/data/civic_repository.dart';
import 'package:smart_sabha/data/demo_civic_repository.dart';
import 'package:smart_sabha/models/domain_models.dart';
import 'package:smart_sabha/state/app_controller.dart';
import 'auth_test.dart' show FakeAuth, resident;

class SessionRepository extends DemoCivicRepository {
  SessionRepository(this.auth);
  final FakeAuth auth;
  Completer<void>? holdNextLoad;
  Completer<CivicReport>? holdNextUpdate;
  @override
  bool get isPersistent => true;
  @override
  Future<InitialCivicData> loadInitialData() async {
    final identity = auth.currentUser;
    final gate = holdNextLoad;
    holdNextLoad = null;
    final data = await super.loadInitialData();
    final snapshot = InitialCivicData(
      authorities: data.authorities,
      departments: data.departments,
      users: identity == null
          ? []
          : [
              identity.copyWith(
                role: UserRole.officer,
                localAuthorityId: data.authorities.first.id,
                onboardingComplete: true,
              ),
            ],
      projects: const [],
      reports: identity == null ? [] : data.reports,
      announcements: const [],
      feedItems: const [],
      proposals: const [],
      consultations: const [],
      notifications: identity == null ? [] : data.notifications,
    );
    await gate?.future;
    return snapshot;
  }

  @override
  Future<CivicReport> updateReport(
    CivicReport report, {
    List<AppNotification> notifications = const [],
  }) async {
    final gate = holdNextUpdate;
    holdNextUpdate = null;
    if (gate != null) return gate.future;
    return super.updateReport(report, notifications: notifications);
  }
}

void main() {
  test(
    'connected profiles restore role/onboarding and sign-out clears private state',
    () async {
      final auth = FakeAuth()..currentUser = resident;
      final repository = SessionRepository(auth);
      final controller = AppController(repository, auth: auth);
      addTearDown(controller.dispose);
      await controller.bootstrap();
      expect(controller.isOfficer, isTrue);
      expect(controller.currentUser!.onboardingComplete, isTrue);
      expect(controller.reports, isNotEmpty);
      auth.emit(resident);
      expect(
        controller.isOfficer,
        isTrue,
        reason: 'Token refresh must not replace the database role',
      );
      await controller.signOut();
      expect(controller.currentUser, isNull);
      expect(controller.reports, isEmpty);
      expect(controller.notifications, isEmpty);
      await controller.signIn(email: resident.email, password: 'password123');
      expect(controller.isOfficer, isTrue);
      expect(controller.currentUser!.onboardingComplete, isTrue);
    },
  );

  test('a late refresh cannot restore the previous session data', () async {
    final auth = FakeAuth()..currentUser = resident;
    final repository = SessionRepository(auth);
    final controller = AppController(repository, auth: auth);
    addTearDown(controller.dispose);
    await controller.bootstrap();
    final gate = Completer<void>();
    repository.holdNextLoad = gate;
    final refresh = controller.refreshData();
    await controller.signOut();
    gate.complete();
    await refresh;
    expect(controller.currentUser, isNull);
    expect(controller.reports, isEmpty);
    expect(controller.notifications, isEmpty);
  });

  test('an in-flight report save cannot leak data after sign-out', () async {
    final auth = FakeAuth()..currentUser = resident;
    final repository = SessionRepository(auth);
    final controller = AppController(repository, auth: auth);
    addTearDown(controller.dispose);
    await controller.bootstrap();
    final report = controller.reports.first;
    final gate = Completer<CivicReport>();
    repository.holdNextUpdate = gate;
    final pending = controller.addReportComment(report.id, 'An observation.');
    final expectation = expectLater(pending, throwsA(isA<CivicFailure>()));
    await controller.signOut();
    gate.complete(report);
    await expectation;
    expect(controller.reports, isEmpty);
  });
}
