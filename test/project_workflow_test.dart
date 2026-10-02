import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_sabha/core/theme/app_theme.dart';
import 'package:smart_sabha/data/civic_failure.dart';
import 'package:smart_sabha/data/civic_repository.dart';
import 'package:smart_sabha/data/demo_civic_repository.dart';
import 'package:smart_sabha/data/project_codec.dart';
import 'package:smart_sabha/data/supabase_civic_repository.dart';
import 'package:smart_sabha/features/admin/admin_screens.dart';
import 'package:smart_sabha/features/projects/connected_project_list.dart';
import 'package:smart_sabha/models/domain_models.dart';
import 'package:smart_sabha/state/app_controller.dart';
import 'package:smart_sabha/state/app_scope.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_test.dart' show FakeAuth, resident;
import 'connected_session_test.dart' show SessionRepository;

class ProjectTestRepository extends SessionRepository {
  ProjectTestRepository(super.auth);
  final requests = <String>[];
  bool failNext = false;
  bool rejectSave = false;
  final saveAttempts = <Project>[];
  @override
  Future<CivicChanges> saveChanges(CivicChanges changes) async {
    if (changes.projects.isNotEmpty) {
      saveAttempts.add(changes.projects.single);
      if (rejectSave) {
        throw const CivicFailure('Project save failed. Please retry.');
      }
    }
    return super.saveChanges(changes);
  }

  Completer<ProjectPage>? pending;
  Project? fixture;
  @override
  Future<ProjectPage> listProjects({
    String search = '',
    ProjectStatus? status,
    String sort = 'Latest',
    int offset = 0,
    int limit = 25,
  }) async {
    requests.add('$search:$offset');
    if (pending != null) {
      final gate = pending!;
      pending = null;
      return gate.future;
    }
    if (failNext) {
      failNext = false;
      throw const CivicFailure('Try loading again.');
    }
    final data = await DemoCivicRepository().loadInitialData();
    fixture ??= data.projects.first;
    final items = List.generate(
      28,
      (i) => projectFromJson({
        ...projectToJson(fixture!),
        'id': 'p-page-$i',
        'title': 'Public road project $i',
        'authorityId': 'a',
        'revision': 1,
      }),
    );
    final filtered = items
        .where((p) => search.isEmpty || p.title.contains(search))
        .toList();
    return ProjectPage(
      projects: filtered.skip(offset).take(limit).toList(),
      total: filtered.length,
    );
  }
}

void main() {
  test(
    'project codec preserves authority, revisions, milestones, private updates and document links',
    () async {
      final data = await DemoCivicRepository().loadInitialData();
      final p = data.projects.first.copyWith(
        authorityId: 'a',
        revision: 7,
        documents: const [
          PublicDocument(
            name: 'Plan',
            kind: 'PDF',
            sizeLabel: 'Public document',
            url: 'https://example.org/plan.pdf',
          ),
        ],
      );
      final encoded = projectToJson(p);
      final decoded = projectFromJson(jsonDecode(jsonEncode(encoded)));
      expect(decoded.authorityId, 'a');
      expect(decoded.revision, 7);
      expect(decoded.milestones.length, p.milestones.length);
      expect(
        decoded.updates.map((u) => u.isPublic),
        p.updates.map((u) => u.isPublic),
      );
      expect(decoded.documents.single.url, 'https://example.org/plan.pdf');
      expect(
        encoded.containsKey('followerIds'),
        isFalse,
        reason: 'Editing cannot replace subscriptions',
      );
    },
  );

  test(
    'Supabase project RPCs carry filters and revisions, and trust saved server data',
    () async {
      final demo = await DemoCivicRepository().loadInitialData();
      final project = demo.projects.first.copyWith(
        authorityId: 'a',
        revision: 4,
      );
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          final p = {
            ...projectToJson(project.copyWith(revision: 5)),
            'followerIds': ['viewer'],
          };
          return http.Response(
            jsonEncode(
              request.url.path.endsWith('civic_list_projects')
                  ? {
                      'projects': [p],
                      'total': 40,
                    }
                  : p,
            ),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseCivicRepository(client: client);
      final page = await repository.listProjects(
        search: ' road ',
        status: ProjectStatus.planned,
        sort: 'A-Z',
        offset: 25,
      );
      expect(page.total, 40);
      expect(jsonDecode(requests.last.body), {
        'search_text': 'road',
        'status_filter': 'planned',
        'sort_order': 'A-Z',
        'page_offset': 25,
        'page_size': 25,
      });
      final saved = await repository.saveChanges(
        CivicChanges(projects: [project]),
      );
      expect(saved.projects.single.revision, 5);
      expect(jsonDecode(requests.last.body)['payload']['revision'], 4);
      expect(requests.last.url.path, endsWith('/civic_save_project'));
      final followed = await repository.followProject(
        project,
        'untrusted',
        true,
      );
      expect(followed.followerIds, {'viewer'});
      expect(jsonDecode(requests.last.body), {
        'project_id': project.id,
        'following': true,
      });
      await repository.getProject(project.id);
      expect(requests.last.url.path, endsWith('/civic_get_project'));
      await expectLater(
        repository.saveChanges(
          CivicChanges(projects: [project], users: [demo.users.first]),
        ),
        throwsA(isA<CivicFailure>()),
      );
      expect(
        requests.length,
        4,
        reason: 'Mixed writes must be rejected before any request',
      );
    },
  );

  test('residents can follow but cannot edit projects', () async {
    final repository = DemoCivicRepository();
    final controller = AppController(repository);
    addTearDown(controller.dispose);
    await controller.bootstrap();
    await controller.signIn(
      email: 'citizen@smart-sabha.lk',
      password: 'demo12345',
    );
    final project = controller.projects.first;
    await expectLater(
      controller.saveProject(project.copyWith(progress: 99)),
      throwsA(isA<CivicFailure>()),
    );
    await controller.toggleProjectFollow(project.id);
    final reloaded = await repository.getProject(project.id);
    expect(reloaded!.progress, project.progress);
    expect(
      reloaded.followerIds.contains(controller.currentUser!.id),
      !project.followerIds.contains(controller.currentUser!.id),
    );
  });

  test('late project search cannot restore data after sign-out', () async {
    final auth = FakeAuth()..currentUser = resident;
    final repository = ProjectTestRepository(auth);
    final controller = AppController(repository, auth: auth);
    addTearDown(controller.dispose);
    await controller.bootstrap();
    final data = await DemoCivicRepository().loadInitialData();
    final gate = Completer<ProjectPage>();
    repository.pending = gate;
    final request = controller.searchProjects();
    await controller.signOut();
    final assertion = expectLater(request, throwsA(isA<CivicFailure>()));
    gate.complete(
      ProjectPage(projects: data.projects, total: data.projects.length),
    );
    await assertion;
    expect(controller.projects, isEmpty);
  });

  testWidgets('project editor preserves the request and draft after failure', (
    tester,
  ) async {
    final auth = FakeAuth()..currentUser = resident;
    final repository = ProjectTestRepository(auth)..rejectSave = true;
    final controller = AppController(repository, auth: auth);
    addTearDown(controller.dispose);
    await tester.runAsync(controller.bootstrap);
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          home: const AdminShell(initialSection: AdminSection.projects),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New project'));
    await tester.pumpAndSettle();
    for (final field in {
      'Project title': 'School crossing upgrade',
      'Public description':
          'Improve the school crossing and repair the nearby road surface.',
      'Location label': 'School entrance',
    }.entries) {
      final finder = find.widgetWithText(TextFormField, field.key);
      await tester.ensureVisible(finder);
      await tester.enterText(finder, field.value);
    }
    final saveButton = find.widgetWithText(FilledButton, 'Create project');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text('Project save failed. Please retry.'), findsOneWidget);
    expect(repository.saveAttempts, hasLength(1));
    expect(
      repository.saveAttempts.single.authorityId,
      controller.currentUser!.localAuthorityId,
    );
    repository.rejectSave = false;
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
    );
    await tester.pumpAndSettle();
    expect(repository.saveAttempts, hasLength(2));
    expect(
      projectToJson(repository.saveAttempts[0]),
      projectToJson(repository.saveAttempts[1]),
    );
    expect(find.text('Manage project'), findsNothing);
    expect(saveButton, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets(
      'connected project list and editor fit $width with enlarged text',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final auth = FakeAuth()..currentUser = resident;
        final repository = ProjectTestRepository(auth);
        final controller = AppController(repository, auth: auth);
        addTearDown(controller.dispose);
        await tester.runAsync(controller.bootstrap);
        await tester.pumpWidget(
          AppScope(
            controller: controller,
            child: MaterialApp(
              theme: AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: const AdminShell(initialSection: AdminSection.projects),
            ),
          ),
        );
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 350)),
        );
        await tester.pumpAndSettle();
        expect(find.text('28 projects'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('New project'));
        await tester.pumpAndSettle();
        expect(find.text('Create project'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'project search debounces, reports failures, retries, and requests the next page',
    (tester) async {
      final auth = FakeAuth()..currentUser = resident;
      final repository = ProjectTestRepository(auth);
      final controller = AppController(repository, auth: auth);
      addTearDown(controller.dispose);
      await tester.runAsync(controller.bootstrap);
      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(
            home: Scaffold(body: ConnectedProjectList(onOpen: (_) async {})),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 350)),
      );
      await tester.pumpAndSettle();
      final list = find.byType(ListView);
      await tester.dragUntilVisible(
        find.text('Load more projects'),
        list,
        const Offset(0, -1000),
        maxIteration: 40,
      );
      await tester.tap(find.text('Load more projects'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 350)),
      );
      await tester.pumpAndSettle();
      expect(repository.requests, contains(':25'));
      await tester.dragUntilVisible(
        find.byType(TextField),
        list,
        const Offset(0, 1200),
        maxIteration: 40,
      );
      repository.failNext = true;
      await tester.enterText(find.byType(TextField), 'project 2');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Try loading again.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 350)),
      );
      await tester.pumpAndSettle();
      expect(find.text('9 projects'), findsOneWidget);
      expect(repository.requests.last, 'project 2:0');
      final requestsBeforeRefresh = repository.requests.length;
      await tester.runAsync(controller.refreshData);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 350)),
      );
      await tester.pumpAndSettle();
      expect(repository.requests.length, requestsBeforeRefresh + 1);
      expect(repository.requests.last, 'project 2:0');
      expect(find.text('9 projects'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
