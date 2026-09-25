import 'package:flutter_test/flutter_test.dart';
import 'package:smart_sabha/data/demo_civic_repository.dart';
import 'package:smart_sabha/models/domain_models.dart';
import 'package:smart_sabha/state/app_controller.dart';

void main() {
  group('AppController', () {
    test('loads civic data and updates project following', () async {
      final controller = AppController(DemoCivicRepository());
      await controller.bootstrap();
      await controller.signIn(
        email: 'citizen@smart-sabha.lk',
        password: 'demo12345',
      );

      final project = controller.projectById('p-road-renewal')!;
      expect(project.followerIds.contains(controller.currentUser!.id), isTrue);

      await controller.toggleProjectFollow(project.id);

      expect(
        controller
            .projectById(project.id)!
            .followerIds
            .contains(controller.currentUser!.id),
        isFalse,
      );
    });

    test(
      'submitting a report creates a trackable case and notification',
      () async {
        final controller = AppController(DemoCivicRepository());
        await controller.bootstrap();
        await controller.signIn(
          email: 'citizen@smart-sabha.lk',
          password: 'demo12345',
        );
        final before = controller.myReports.length;

        final report = await controller.submitReport(
          const ReportDraft(
            category: 'Road Damage',
            title: 'Pothole beside the school gate',
            description:
                'A large pothole is affecting vehicles and pedestrians near the school gate.',
            locationLabel: 'School Road, Ward 04',
            location: GeoPoint(7.4864, 80.3642),
            urgency: 'High',
            attachmentNames: <String>['pothole.jpg'],
          ),
        );

        expect(controller.myReports.length, before + 1);
        expect(controller.reportById(report.id)!.caseNumber, startsWith('SS-'));
        expect(controller.notifications.first.route, '/reports/${report.id}');
      },
    );

    test(
      'a consultation response is recorded for the current resident',
      () async {
        final controller = AppController(DemoCivicRepository());
        await controller.bootstrap();
        await controller.signIn(
          email: 'citizen@smart-sabha.lk',
          password: 'demo12345',
        );
        const consultationId = 'c-walking';

        await controller.submitConsultationResponse(consultationId);

        expect(
          controller
              .consultationById(consultationId)!
              .respondedUserIds
              .contains(controller.currentUser!.id),
          isTrue,
        );
      },
    );
  });
}
