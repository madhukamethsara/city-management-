import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_sabha/core/theme/app_theme.dart';
import 'package:smart_sabha/data/announcement_codec.dart';
import 'package:smart_sabha/data/civic_failure.dart';
import 'package:smart_sabha/data/civic_repository.dart';
import 'package:smart_sabha/data/report_codec.dart';
import 'package:smart_sabha/data/supabase_civic_repository.dart';
import 'package:smart_sabha/features/admin/admin_screens.dart';
import 'package:smart_sabha/features/citizen/citizen_screens.dart';
import 'package:smart_sabha/features/community/community_screens.dart';
import 'package:smart_sabha/models/domain_models.dart';
import 'package:smart_sabha/state/app_controller.dart';
import 'package:smart_sabha/state/app_scope.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_test.dart' show FakeAuth, resident;
import 'connected_session_test.dart' show SessionRepository;

Json noticeJson({String id = 'a-test', bool published = true}) => {
  'id': id,
  'authorityId': 'a',
  'revision': 1,
  'title': 'Water service interruption',
  'body': 'Water will be unavailable during planned maintenance tomorrow.',
  'type': 'serviceInterruption',
  'department': 'Administration',
  'targetWard': 'Ward 1',
  'targetDivision': 'Division',
  'targetLabel': 'Ward 1 / Division',
  'isPublished': published,
  'isPinned': false,
  'publishedAt': '2026-10-02T00:00:00Z',
  'reactionCount': 1,
  'commentCount': 1,
  'reactedUserIds': <String>[],
  'savedUserIds': <String>[],
  'comments': [
    {
      'id': 'c-existing',
      'author': 'Resident',
      'message': 'When will service return?',
      'createdAt': '2026-10-02T01:00:00Z',
      'isVerified': false,
    },
  ],
};

class AnnouncementRepository extends SessionRepository {
  AnnouncementRepository(super.auth);
  bool failSave = false;
  bool failDetail = false;
  final attempts = <Announcement>[];
  final offsets = <int>[];
  Completer<FeedItem>? commentGate;
  Completer<AnnouncementPage>? pageGate;
  @override
  Future<InitialCivicData> loadInitialData() async {
    final base = await super.loadInitialData();
    final records = auth.currentUser == null ? <Json>[] : [noticeJson()];
    return InitialCivicData(
      authorities: base.authorities,
      departments: base.departments,
      users: base.users,
      projects: base.projects,
      reports: base.reports,
      notifications: base.notifications,
      proposals: base.proposals,
      consultations: base.consultations,
      announcements: records.map(announcementFromJson).toList(),
      feedItems: records.map(feedFromJson).toList(),
      announcementTotal: records.isEmpty ? 0 : 2,
    );
  }

  @override
  Future<CivicChanges> saveChanges(CivicChanges changes) async {
    if (changes.announcements.isNotEmpty) {
      attempts.add(changes.announcements.single);
      if (failSave) {
        throw const CivicFailure('Announcement save failed. Please retry.');
      }
    }
    return super.saveChanges(changes);
  }

  @override
  Future<AnnouncementPage> listAnnouncements({int offset = 0}) async {
    offsets.add(offset);
    if (pageGate != null) return pageGate!.future;
    return AnnouncementPage(
      announcements: [announcementFromJson(noticeJson(id: 'a-next'))],
      feedItems: [feedFromJson(noticeJson(id: 'a-next'))],
      total: 2,
    );
  }

  @override
  Future<Announcement?> getAnnouncement(String id) async {
    if (failDetail) throw const CivicFailure('Could not load notice.');
    return announcementFromJson(noticeJson(id: id));
  }

  @override
  Future<FeedItem> addFeedComment(FeedItem item, CivicComment comment) async {
    if (commentGate != null) return commentGate!.future;
    return super.addFeedComment(item, comment);
  }
}

Widget app(AppController controller, Widget child, {double scale = 1}) =>
    AppScope(
      controller: controller,
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: child,
      ),
    );

void main() {
  test(
    'announcement RPCs trust server identity and preserve targeting and revisions',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          final data = noticeJson()..['revision'] = 2;
          return http.Response(
            jsonEncode(
              request.url.path.endsWith('civic_list_announcements')
                  ? {
                      'announcements': [data],
                      'total': 27,
                    }
                  : data,
            ),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseCivicRepository(client: client);
      final page = await repository.listAnnouncements(offset: 25);
      expect(page.total, 27);
      expect(jsonDecode(requests.last.body), {
        'page_offset': 25,
        'page_size': 25,
      });
      final notice = page.announcements.single;
      expect(notice.targetWard, 'Ward 1');
      expect(notice.targetDivision, 'Division');
      expect(
        page.feedItems.single.comments.single.message,
        'When will service return?',
      );
      await repository.saveChanges(CivicChanges(announcements: [notice]));
      expect(requests.last.url.path, endsWith('civic_save_announcement'));
      expect(jsonDecode(requests.last.body)['payload']['revision'], 2);
      await repository.updateFeedPreference(
        page.feedItems.single,
        'spoofed-user',
        reacted: true,
      );
      expect(jsonDecode(requests.last.body), {
        'announcement_id': 'a-test',
        'reacted': true,
        'saved': null,
      });
      await repository.addFeedComment(
        page.feedItems.single,
        CivicComment(
          id: 'c-retry',
          author: 'Spoofed author',
          message: 'Please confirm the dates.',
          createdAt: DateTime(1900),
          isVerified: true,
        ),
      );
      expect(jsonDecode(requests.last.body), {
        'announcement_id': 'a-test',
        'comment_id': 'c-retry',
        'message': 'Please confirm the dates.',
      });
      final before = requests.length;
      await expectLater(
        repository.saveChanges(
          CivicChanges(announcements: [notice], users: [resident]),
        ),
        throwsA(isA<CivicFailure>()),
      );
      expect(
        requests.length,
        before,
        reason: 'Mixed batches must fail before any RPC commits',
      );
    },
  );

  test(
    'pagination appends records without changing the first page order',
    () async {
      final auth = FakeAuth()..currentUser = resident;
      final repository = AnnouncementRepository(auth);
      final controller = AppController(repository, auth: auth);
      addTearDown(controller.dispose);
      await controller.bootstrap();
      expect(controller.hasMoreAnnouncements, isTrue);
      await controller.loadMoreAnnouncements();
      expect(repository.offsets, [1]);
      expect(controller.announcements.map((a) => a.id), ['a-test', 'a-next']);
      expect(controller.feedItems.map((f) => f.id), ['a-test', 'a-next']);
      expect(controller.hasMoreAnnouncements, isFalse);
    },
  );

  test('pending comments cannot repopulate another session', () async {
    final auth = FakeAuth()..currentUser = resident;
    final repository = AnnouncementRepository(auth);
    final controller = AppController(repository, auth: auth);
    addTearDown(controller.dispose);
    await controller.bootstrap();
    final old = controller.feedItems.single;
    repository.commentGate = Completer<FeedItem>();
    final pending = controller.addFeedComment(
      old.id,
      'Pending comment',
      requestId: 'c-pending',
    );
    final rejected = expectLater(pending, throwsA(isA<CivicFailure>()));
    await controller.signOut();
    repository.commentGate!.complete(old.copyWith(commentCount: 2));
    await rejected;
    expect(controller.feedItems, isEmpty);
    expect(controller.announcements, isEmpty);
    expect(controller.hasMoreAnnouncements, isFalse);
  });

  test('a stale page cannot overwrite a newly saved preference', () async {
    final auth = FakeAuth()..currentUser = resident;
    final repository = AnnouncementRepository(auth);
    final controller = AppController(repository, auth: auth);
    addTearDown(controller.dispose);
    await controller.bootstrap();
    final old = controller.feedItems.single;
    repository.pageGate = Completer<AnnouncementPage>();
    final pending = controller.loadMoreAnnouncements();
    await controller.toggleFeedSave(old.id);
    repository.pageGate!.complete(
      AnnouncementPage(announcements: [], feedItems: [old], total: 2),
    );
    await pending;
    expect(controller.feedItems.single.savedUserIds, contains(resident.id));
  });

  testWidgets('notice detail loads beyond cached pages and retries failures', (
    tester,
  ) async {
    final auth = FakeAuth()..currentUser = resident;
    final repository = AnnouncementRepository(auth)..failDetail = true;
    final controller = AppController(repository, auth: auth);
    addTearDown(controller.dispose);
    await tester.runAsync(controller.bootstrap);
    await tester.pumpWidget(
      app(
        controller,
        const AnnouncementDetailScreen(announcementId: 'a-deep-link'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    repository.failDetail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Water service interruption'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('announcement form keeps the creation ID on retry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = FakeAuth()..currentUser = resident;
    final repository = AnnouncementRepository(auth)..failSave = true;
    final controller = AppController(repository, auth: auth);
    addTearDown(controller.dispose);
    await tester.runAsync(controller.bootstrap);
    await tester.pumpWidget(
      app(
        controller,
        const AdminShell(initialSection: AdminSection.announcements),
      ),
    );
    await tester.tap(find.text('New announcement'));
    await tester.pumpAndSettle();
    for (final field in {
      'Announcement title': 'Notice of road maintenance',
      'Public message': 'The main road will be repaired during the next week.',
      'Target ward (optional)': 'Ward 1',
    }.entries) {
      final finder = find.widgetWithText(TextFormField, field.key);
      await tester.ensureVisible(finder);
      await tester.enterText(finder, field.value);
    }
    final save = find.widgetWithText(FilledButton, 'Save draft');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.attempts, hasLength(1));
    expect(
      find.text('Announcement save failed. Please retry.'),
      findsOneWidget,
    );
    repository.failSave = false;
    await tester.tap(save);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
    );
    await tester.pumpAndSettle();
    expect(repository.attempts, hasLength(2));
    expect(
      announcementToJson(repository.attempts[0]),
      announcementToJson(repository.attempts[1]),
    );
    expect(repository.attempts.last.targetWard, 'Ward 1');
    expect(save, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets(
      'feed and officer notices fit width $width with enlarged text',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final auth = FakeAuth()..currentUser = resident;
        final repository = AnnouncementRepository(auth);
        final controller = AppController(repository, auth: auth);
        addTearDown(controller.dispose);
        await tester.runAsync(controller.bootstrap);
        await tester.pumpWidget(
          app(controller, const CivicFeedScreen(), scale: 1.5),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Saved'));
        await tester.pumpAndSettle();
        expect(find.text('No updates here yet'), findsOneWidget);
        await tester.pumpWidget(
          app(
            controller,
            const AdminShell(initialSection: AdminSection.announcements),
            scale: 1.5,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Announcement administration'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('New announcement'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
