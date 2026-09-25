import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_sabha/data/civic_repository.dart';
import 'package:smart_sabha/data/demo_civic_repository.dart';
import 'package:smart_sabha/models/domain_models.dart';
import 'package:smart_sabha/state/app_controller.dart';
import 'package:smart_sabha/widgets/save_civic_action.dart';

class RejectingRepository extends DemoCivicRepository {
  bool reject = false;

  @override
  Future<CivicChanges> saveChanges(CivicChanges changes) {
    if (reject) throw StateError('private backend details');
    return super.saveChanges(changes);
  }
}

void main() {
  test(
    'profile, project, community and notification edits survive reload',
    () async {
      final repository = DemoCivicRepository();
      final app = AppController(repository);
      addTearDown(app.dispose);
      await app.bootstrap();
      await app.signIn(email: 'citizen@smart-sabha.lk', password: 'demo12345');
      final userId = app.currentUser!.id;
      await app.updateProfile(
        fullName: 'Updated Resident',
        phone: '0770000000',
        preferredLanguage: 'si',
      );
      final project = app.projects.first;
      final followed = project.followerIds.contains(userId);
      await app.toggleProjectFollow(project.id);
      await app.saveProject(
        app.projectById(project.id)!.copyWith(progress: 77),
      );
      final feed = app.feedItems.first;
      await app.toggleFeedReaction(feed.id);
      await app.toggleFeedSave(feed.id);
      await app.addFeedComment(feed.id);
      final proposal = await app.submitProposal(
        const ProposalDraft(
          title: 'A new library',
          description: 'A community reading space.',
          category: 'Community',
          locationLabel: 'Ward 04',
          expectedBenefit: 'Access to books',
          attachmentNames: [],
        ),
      );
      await app.toggleProposalSupport(proposal.id);
      await app.toggleProposalFollow(proposal.id);
      await app.addProposalComment(
        proposal.id,
        '  Please include a study room.  ',
      );
      await app.submitConsultationResponse('c-walking');
      final notificationId = app.notifications.first.id;
      await app.markNotificationRead(notificationId);
      await app.markAllNotificationsRead();

      final reloaded = AppController(repository);
      addTearDown(reloaded.dispose);
      await reloaded.bootstrap();
      await reloaded.signIn(
        email: 'citizen@smart-sabha.lk',
        password: 'demo12345',
      );
      expect(reloaded.currentUser!.fullName, 'Updated Resident');
      expect(reloaded.locale, 'si');
      expect(reloaded.projectById(project.id)!.progress, 77);
      expect(
        reloaded.projectById(project.id)!.followerIds.contains(userId),
        !followed,
      );
      final savedFeed = reloaded.feedItems.firstWhere(
        (item) => item.id == feed.id,
      );
      expect(savedFeed.commentCount, feed.commentCount + 1);
      expect(
        savedFeed.reactedUserIds.contains(userId),
        !feed.reactedUserIds.contains(userId),
      );
      expect(
        savedFeed.savedUserIds.contains(userId),
        !feed.savedUserIds.contains(userId),
      );
      final savedProposal = reloaded.proposalById(proposal.id)!;
      expect(savedProposal.supporterIds, isEmpty);
      expect(savedProposal.followerIds, isEmpty);
      expect(
        savedProposal.comments.single.message,
        'Please include a study room.',
      );
      expect(
        reloaded.consultationById('c-walking')!.respondedUserIds,
        contains(userId),
      );
      expect(
        reloaded.notifications.any((item) => item.id == notificationId),
        isTrue,
      );
      expect(reloaded.unreadNotificationCount, 0);
    },
  );

  test('registration, onboarding and officer edits survive reload', () async {
    final repository = DemoCivicRepository();
    final app = AppController(repository);
    addTearDown(app.dispose);
    await app.bootstrap();
    await app.register(
      fullName: 'New Resident',
      email: 'new@example.com',
      password: 'demo12345',
    );
    final id = app.currentUser!.id;
    await app.completeOnboarding(
      const OnboardingDraft(
        fullName: 'New Resident',
        language: 'ta',
        phone: '0770000001',
        localAuthorityId: 'la-kumbukgate',
        ward: 'Ward 04',
        gnDivision: 'South',
        residentialArea: GeoPoint(7.48, 80.36),
      ),
    );
    await app.signIn(email: 'officer@smart-sabha.lk', password: 'demo12345');
    await app.changeUserRole(id, UserRole.verifiedResident);
    await app.toggleUserActive(id);
    final department = app.departments.first;
    await app.updateDepartment(
      Department(
        id: department.id,
        name: department.name,
        headName: 'New Head',
        categories: department.categories,
        officerCount: 10,
      ),
    );
    final project = await app.createProject(
      const ProjectDraft(
        title: 'New park',
        description: 'Public park',
        category: 'Community',
        locationLabel: 'Ward 04',
        status: ProjectStatus.inProgress,
        progress: 10,
        budget: 1000,
        department: 'Engineering',
      ),
    );
    final announcement = await app.createAnnouncement(
      AnnouncementDraft(
        title: 'Park opening',
        body: 'Visit the park.',
        type: AnnouncementType.values.first,
        department: 'Engineering',
        targetLabel: 'Ward 04',
      ),
      publishNow: true,
    );
    await app.saveAnnouncement(
      announcement.copyWith(body: 'Updated details.', isPublished: false),
    );
    await app.publishAnnouncement(announcement.id);
    final data = await repository.loadInitialData();
    final user = data.users.singleWhere((item) => item.id == id);
    expect(user.onboardingComplete, isTrue);
    expect(user.preferredLanguage, 'ta');
    expect(user.role, UserRole.verifiedResident);
    expect(user.isActive, isFalse);
    expect(data.departments.first.headName, 'New Head');
    expect(data.projects.any((item) => item.id == project.id), isTrue);
    final saved = data.announcements.singleWhere(
      (item) => item.id == announcement.id,
    );
    expect(saved.isPublished, isTrue);
    expect(saved.body, 'Updated details.');
    expect(
      data.notifications.any(
        (item) => item.route == '/announcements/${announcement.id}',
      ),
      isTrue,
    );
  });

  test(
    'failed batches leave related records and current profile unchanged',
    () async {
      final repository = RejectingRepository();
      final app = AppController(repository);
      addTearDown(app.dispose);
      await app.bootstrap();
      await app.signIn(email: 'citizen@smart-sabha.lk', password: 'demo12345');
      final user = app.currentUser;
      final consultation = app.consultationById('c-walking');
      final notifications = app.notifications.length;
      final announcements = app.managedAnnouncements.length;
      repository.reject = true;
      await expectLater(
        app.updateProfile(
          fullName: 'Unsaved',
          phone: '',
          preferredLanguage: 'ta',
        ),
        throwsStateError,
      );
      await expectLater(
        app.submitConsultationResponse('c-walking'),
        throwsStateError,
      );
      await expectLater(
        app.createAnnouncement(
          AnnouncementDraft(
            title: 'Unsaved',
            body: 'Test',
            type: AnnouncementType.values.first,
            department: 'Engineering',
            targetLabel: 'All',
          ),
          publishNow: true,
        ),
        throwsStateError,
      );
      await expectLater(app.markAllNotificationsRead(), throwsStateError);
      expect(app.currentUser, same(user));
      expect(app.consultationById('c-walking'), same(consultation));
      expect(app.notifications.length, notifications);
      expect(app.managedAnnouncements.length, announcements);
      final stored = await repository.loadInitialData();
      expect(
        stored.consultations
            .singleWhere((item) => item.id == 'c-walking')
            .respondedUserIds,
        consultation!.respondedUserIds,
      );
      expect(stored.announcements.length, announcements);
    },
  );

  testWidgets('failed UI save keeps input and permits a successful retry', (
    tester,
  ) async {
    final input = TextEditingController(text: 'My draft');
    addTearDown(input.dispose);
    var attempts = 0;
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextField(controller: input),
                FilledButton(
                  onPressed: () async {
                    if (!await saveCivicAction(context, () async {
                      attempts++;
                      if (attempts == 1) {
                        throw StateError('private backend details');
                      }
                    })) {
                      return;
                    }
                    saved = true;
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved, isFalse);
    expect(input.text, 'My draft');
    expect(
      find.text('Could not save your changes. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('private backend details'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved, isTrue);
    expect(attempts, 2);
  });
}
