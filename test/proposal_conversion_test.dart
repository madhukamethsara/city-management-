import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_sabha/data/civic_failure.dart';
import 'package:smart_sabha/data/civic_repository.dart';
import 'package:smart_sabha/data/demo_civic_repository.dart';
import 'package:smart_sabha/data/participation_codec.dart';
import 'package:smart_sabha/data/project_codec.dart';
import 'package:smart_sabha/data/supabase_civic_repository.dart';
import 'package:smart_sabha/features/community/community_screens.dart';
import 'package:smart_sabha/models/domain_models.dart';
import 'package:smart_sabha/state/app_controller.dart';
import 'package:smart_sabha/state/app_scope.dart';

class ConversionRepository extends DemoCivicRepository {
  bool fail = false;
  Completer<CivicChanges>? gate;
  final attempts = <Project>[];

  @override
  Future<CivicChanges> convertProposal(Proposal proposal, Project project) {
    attempts.add(project);
    if (fail) {
      fail = false;
      throw const CivicFailure('Connection failed. Try again.');
    }
    return gate?.future ?? super.convertProposal(proposal, project);
  }
}

Future<AppController> setup(ConversionRepository repository) async {
  final app = AppController(repository);
  await app.bootstrap();
  await app.signIn(email: 'citizen@smart-sabha.lk', password: 'demo12345');
  await app.submitProposal(
    const ProposalDraft(
      title: 'Safe school crossing',
      description: 'Install a raised crossing beside the busy school entrance.',
      category: 'Roads',
      locationLabel: 'School road',
      expectedBenefit: 'Children can safely cross the busy road.',
      attachmentNames: [],
    ),
    requestId: 'pr-conversion',
  );
  await app.signOut();
  await app.signIn(email: 'officer@smart-sabha.lk', password: 'demo12345');
  await app.reviewProposal('pr-conversion', ProposalStatus.approved);
  return app;
}

Project projectFor(AppController app) => app.buildProject(
  ProjectDraft(
    title: 'Safe school crossing',
    description: 'Install a raised crossing beside the busy school entrance.',
    category: 'Roads',
    locationLabel: 'School road',
    status: ProjectStatus.planned,
    progress: 0,
    budget: 0,
    department: app.departments.first.name,
  ),
);

void main() {
  test(
    'conversion persists its link, retries once and rejects changed requests',
    () async {
      final repo = ConversionRepository();
      final app = await setup(repo);
      addTearDown(app.dispose);
      final proposal = app.proposalById('pr-conversion')!;
      final project = projectFor(app);
      await app.convertProposal(proposal, project);
      await app.convertProposal(proposal, project);
      await app.refreshData();
      expect(app.proposalById(proposal.id)!.projectId, project.id);
      expect(
        app.proposalById(proposal.id)!.status,
        ProposalStatus.convertedToProject,
      );
      expect(app.projects.where((p) => p.id == project.id), hasLength(1));
      await expectLater(
        app.convertProposal(
          proposal,
          project.copyWith(title: 'Changed project title'),
        ),
        throwsA(isA<CivicFailure>()),
      );
      await expectLater(
        app.reviewProposal(proposal.id, ProposalStatus.approved),
        throwsA(isA<CivicFailure>()),
      );
    },
  );

  test('residents and unapproved proposals cannot convert', () async {
    final repo = ConversionRepository();
    final app = await setup(repo);
    addTearDown(app.dispose);
    final proposal = app.proposalById('pr-conversion')!;
    final project = projectFor(app);
    await expectLater(
      app.convertProposal(
        proposal.copyWith(status: ProposalStatus.submitted),
        project,
      ),
      throwsA(isA<CivicFailure>()),
    );
    await app.signOut();
    await app.signIn(email: 'citizen@smart-sabha.lk', password: 'demo12345');
    await expectLater(
      app.convertProposal(proposal, project),
      throwsA(isA<CivicFailure>()),
    );
    expect(repo.attempts, isEmpty);
  });

  test(
    'late conversion responses cannot populate a different account',
    () async {
      final repo = ConversionRepository();
      final app = await setup(repo);
      addTearDown(app.dispose);
      final proposal = app.proposalById('pr-conversion')!;
      final project = projectFor(app);
      repo.gate = Completer<CivicChanges>();
      final rejected = expectLater(
        app.convertProposal(proposal, project),
        throwsA(isA<CivicFailure>()),
      );
      await app.signOut();
      await app.signIn(email: 'citizen@smart-sabha.lk', password: 'demo12345');
      repo.gate!.complete(
        CivicChanges(
          proposals: [proposal.copyWith(projectId: project.id)],
          projects: [project],
        ),
      );
      await rejected;
      expect(app.projectById(project.id), isNull);
      expect(app.proposalById(proposal.id)!.projectId, isNull);
    },
  );

  test(
    'connected conversion sends revision and decodes the server-owned link',
    () async {
      final app = await setup(ConversionRepository());
      addTearDown(app.dispose);
      final proposal = app.proposalById('pr-conversion')!;
      final project = projectFor(app);
      http.Request? sent;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'public',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({
              'proposal': {
                ...proposalToJson(proposal),
                'status': 'convertedToProject',
                'revision': 7,
                'projectId': project.id,
                'supportCount': 1,
                'author': proposal.author,
                'createdAt': proposal.createdAt.toIso8601String(),
                'supporterIds': [],
                'followerIds': [],
                'comments': [],
              },
              'project': {
                ...projectToJson(project),
                'revision': 1,
                'followerIds': [],
                'comments': [],
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final result = await SupabaseCivicRepository(
        client: client,
      ).convertProposal(proposal, project);
      expect(sent!.url.path, '/rest/v1/rpc/civic_convert_proposal');
      final body = jsonDecode(sent!.body) as Map;
      expect(body['proposal_id'], proposal.id);
      expect(body['expected_revision'], proposal.revision);
      expect(body['payload'], projectToJson(project));
      expect(result.proposals.single.projectId, project.id);
      expect(result.proposals.single.revision, 7);
      expect(result.projects.single.revision, 1);
    },
  );

  testWidgets(
    'conversion editor prefills proposal and preserves failed request for retry',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = ConversionRepository();
      final app = (await tester.runAsync(() => setup(repo)))!;
      addTearDown(app.dispose);
      repo.fail = true;
      await tester.pumpWidget(
        AppScope(
          controller: app,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const ProposalDetailScreen(proposalId: 'pr-conversion'),
          ),
        ),
      );
      await tester.tap(find.text('Convert to project'));
      await tester.pumpAndSettle();
      expect(find.text('Convert proposal to project'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Safe school crossing'),
        findsOneWidget,
      );
      final save = find.widgetWithText(FilledButton, 'Convert to project');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Connection failed. Try again.'), findsOneWidget);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(repo.attempts, hasLength(2));
      expect(
        projectToJson(repo.attempts.first),
        projectToJson(repo.attempts.last),
      );
      expect(find.text('View resulting project'), findsOneWidget);
      expect(find.text('Officer review status'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
