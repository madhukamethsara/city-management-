import 'package:flutter_test/flutter_test.dart';
import 'package:smart_sabha/data/demo_civic_repository.dart';
import 'package:smart_sabha/models/domain_models.dart';
import 'package:smart_sabha/state/app_controller.dart';

class FailingWriteRepository extends DemoCivicRepository {
  bool failWrites = false;

  @override
  Future<CivicReport> createReport(
    CivicReport report, {
    List<AppNotification> notifications = const [],
  }) {
    if (failWrites) throw StateError('Save failed');
    return super.createReport(report, notifications: notifications);
  }

  @override
  Future<CivicReport> updateReport(
    CivicReport report, {
    List<AppNotification> notifications = const [],
  }) {
    if (failWrites) throw StateError('Save failed');
    return super.updateReport(report, notifications: notifications);
  }
}

const draft = ReportDraft(
  category: 'Road Damage',
  title: 'Damaged road',
  description: 'Road damage near the school.',
  locationLabel: 'School Road',
  location: GeoPoint(7.4864, 80.3642),
  urgency: 'High',
  attachmentNames: ['road.jpg'],
);

void main() {
  test('report workflow writes survive a controller reload', () async {
    final repository = DemoCivicRepository();
    final controller = AppController(repository);
    addTearDown(controller.dispose);
    await controller.bootstrap();
    await controller.signIn(
      email: 'citizen@smart-sabha.lk',
      password: 'demo12345',
    );
    final report = await controller.submitReport(draft);
    await controller.signIn(
      email: 'officer@smart-sabha.lk',
      password: 'demo12345',
    );
    await controller.updateReportStatus(
      reportId: report.id,
      status: ReportStatus.resolved,
      department: 'Engineering',
      priority: 'High',
      publicUpdate: 'Road repaired.',
      internalNote: 'Inspection complete.',
    );
    await controller.signIn(
      email: 'citizen@smart-sabha.lk',
      password: 'demo12345',
    );
    await controller.confirmReportResolution(report.id, resolved: false);
    await controller.toggleReportFollow(report.id);
    final reloaded = AppController(repository);
    addTearDown(reloaded.dispose);
    await reloaded.bootstrap();
    final saved = reloaded.reportById(report.id)!;
    expect(saved.status, ReportStatus.inProgress);
    expect(saved.updates.length, 3);
    expect(saved.internalNotes, ['Inspection complete.']);
    expect(saved.followerIds, isEmpty);
    expect(saved.attachments, ['road.jpg']);
    await expectLater(repository.createReport(saved), throwsStateError);
    final fresh = DemoCivicRepository();
    await expectLater(fresh.updateReport(saved), throwsStateError);
  });

  test('failed writes leave reports and notifications unchanged', () async {
    final repository = FailingWriteRepository();
    final controller = AppController(repository);
    addTearDown(controller.dispose);
    await controller.bootstrap();
    await controller.signIn(
      email: 'citizen@smart-sabha.lk',
      password: 'demo12345',
    );
    final count = controller.reports.length;
    final notifications = controller.notifications.length;
    repository.failWrites = true;
    await expectLater(controller.submitReport(draft), throwsStateError);
    expect(controller.reports.length, count);
    expect(controller.notifications.length, notifications);
    final original = controller.reports.first;
    await expectLater(
      controller.toggleReportFollow(original.id),
      throwsStateError,
    );
    await expectLater(
      controller.confirmReportResolution(original.id, resolved: true),
      throwsStateError,
    );
    await expectLater(
      controller.updateReportStatus(
        reportId: original.id,
        status: ReportStatus.resolved,
        department: 'Engineering',
        priority: 'High',
        publicUpdate: 'Repaired',
      ),
      throwsStateError,
    );
    expect(controller.reportById(original.id), same(original));
    expect(controller.notifications.length, notifications);
  });
}
