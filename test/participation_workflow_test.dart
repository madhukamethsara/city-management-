import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_sabha/core/theme/app_theme.dart';
import 'package:smart_sabha/data/civic_failure.dart';
import 'package:smart_sabha/data/demo_civic_repository.dart';
import 'package:smart_sabha/data/participation_codec.dart';
import 'package:smart_sabha/data/supabase_civic_repository.dart';
import 'package:smart_sabha/features/community/community_screens.dart';
import 'package:smart_sabha/features/community/consultation_editor.dart';
import 'package:smart_sabha/models/domain_models.dart';
import 'package:smart_sabha/state/app_controller.dart';
import 'package:smart_sabha/state/app_scope.dart';
import 'supabase_auth_repository_test.dart' show session;

class DelayedParticipation extends DemoCivicRepository {
  final gate = Completer<Proposal>();
  Proposal? pending;
  @override
  Future<Proposal> createProposal(Proposal p) {
    pending = p;
    return gate.future;
  }
}

const draft = ProposalDraft(
  title: 'Safe school crossing',
  description: 'Install a raised crossing beside the busy school entrance.',
  category: 'Roads',
  locationLabel: 'School road',
  expectedBenefit: 'Children will be able to cross the road safely.',
  attachmentNames: [],
);

void main() {
  test(
    'project uploads send actual PDF bytes to the public bucket and reject invalid files',
    () async {
      http.Request? upload;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'public',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/auth/')) {
            return http.Response(
              jsonEncode(session()),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          upload = request;
          return http.Response(
            '{"Key":"project-public/test"}',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: 'officer@example.test',
        password: 'password',
      );
      final repo = SupabaseCivicRepository(client: client);
      final bytes = Uint8List.fromList(utf8.encode('%PDF-1.7\nTest document'));
      final path = await repo.uploadProjectAsset(
        'p-test',
        'a',
        'plan.pdf',
        bytes,
      );
      expect(path, startsWith('user-uuid/a/p-test/'));
      expect(upload!.url.path, contains('/storage/v1/object/project-public/'));
      final body = latin1.decode(upload!.bodyBytes);
      expect(body, contains(latin1.decode(bytes)));
      expect(body, contains('content-type: application/pdf'));
      expect(
        upload!.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      expect(
        repo.projectAssetUrl(path),
        contains('/storage/v1/object/public/project-public/'),
      );
      await expectLater(
        repo.uploadProjectAsset('p-test', 'a', 'script.exe', bytes),
        throwsA(isA<CivicFailure>()),
      );
      await expectLater(
        repo.uploadProjectAsset('p-test', 'a', 'empty.pdf', Uint8List(0)),
        throwsA(isA<CivicFailure>()),
      );
    },
  );
  test(
    'consultation answers survive reload, reject missing answers and duplicate participation',
    () async {
      final repository = DemoCivicRepository();
      final app = AppController(repository);
      addTearDown(app.dispose);
      await app.bootstrap();
      await app.signIn(email: 'citizen@smart-sabha.lk', password: 'demo12345');
      final c = app.consultationById('c-walking')!;
      await expectLater(
        app.submitConsultationResponse(c.id),
        throwsA(isA<CivicFailure>()),
      );
      final answers = {
        for (final q in c.questions)
          q.id: q.allowsLongText ? 'Wider paths.' : q.options.first,
      };
      await app.submitConsultationResponse(c.id, answers: answers);
      await app.submitConsultationResponse(
        c.id,
        answers: Map.fromEntries(answers.entries.toList().reversed),
      );
      expect(
        (await repository.loadInitialData()).consultations
            .firstWhere((x) => x.id == c.id)
            .answers[app.currentUser!.id],
        answers,
      );
      await expectLater(
        app.submitConsultationResponse(
          c.id,
          answers: {for (final q in c.questions) q.id: 'Different'},
        ),
        throwsA(isA<CivicFailure>()),
      );
    },
  );

  test(
    'a late proposal save cannot enter a different account session',
    () async {
      final repo = DelayedParticipation();
      final app = AppController(repo);
      addTearDown(app.dispose);
      await app.bootstrap();
      await app.signIn(email: 'citizen@smart-sabha.lk', password: 'demo12345');
      final pending = app.submitProposal(draft, requestId: 'pr-stable');
      final expectation = expectLater(pending, throwsA(isA<CivicFailure>()));
      await app.signOut();
      repo.gate.complete(repo.pending!);
      await expectation;
      expect(app.proposalById('pr-stable'), isNull);
    },
  );

  test(
    'connected mutations send caller-owned preferences and real text answers through separate RPCs',
    () async {
      final app = AppController(DemoCivicRepository());
      addTearDown(app.dispose);
      await app.bootstrap();
      await app.signIn(email: 'citizen@smart-sabha.lk', password: 'demo12345');
      final p = await app.submitProposal(draft);
      final c = app.consultationById('c-walking')!;
      final requests = <String, Map<String, dynamic>>{};
      final client = SupabaseClient(
        'https://example.supabase.co',
        'public',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final name = request.url.pathSegments.last;
          requests[name] = Map.from(jsonDecode(request.body) as Map);
          final result = name == 'civic_answer_consultation'
              ? {
                  ...consultationToJson(c),
                  'responseCount': 1,
                  'respondedUserIds': ['server-user'],
                  'answers': {
                    'server-user': {'q1': 'Actual text'},
                  },
                }
              : {
                  ...proposalToJson(p),
                  'status': 'submitted',
                  'author': 'Server author',
                  'createdAt': '2026-10-06T00:00:00Z',
                  'revision': 1,
                  'supportCount': 25,
                  'supporterIds': ['server-user'],
                  'followerIds': [],
                  'comments': [],
                };
          return http.Response(
            jsonEncode(result),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = SupabaseCivicRepository(client: client);
      final saved = await repo.createProposal(p);
      expect(saved.totalSupport, 25);
      expect(saved.author, 'Server author');
      expect(
        requests['civic_create_proposal']!['payload'],
        isNot(contains('author')),
      );
      await repo.setProposalPreference(p, 'forged-id', supported: true);
      expect(requests['civic_proposal_preference'], {
        'proposal_id': p.id,
        'supported': true,
        'following': null,
      });
      final response = await repo.answerConsultation(c, 'forged-id', {
        'q1': 'Actual text',
      });
      expect(response.answers['server-user']!['q1'], 'Actual text');
      expect(requests['civic_answer_consultation'], {
        'consultation_id': c.id,
        'answers': {'q1': 'Actual text'},
      });
    },
  );

  test('residents cannot review proposals or publish consultations', () async {
    final app = AppController(DemoCivicRepository());
    addTearDown(app.dispose);
    await app.bootstrap();
    await app.signIn(email: 'citizen@smart-sabha.lk', password: 'demo12345');
    await expectLater(
      app.reviewProposal(app.proposals.first.id, ProposalStatus.approved),
      throwsA(isA<CivicFailure>()),
    );
    await expectLater(
      app.createConsultation(app.consultations.first),
      throwsA(isA<CivicFailure>()),
    );
  });

  for (final size in [const Size(320, 640), const Size(1280, 900)]) {
    testWidgets(
      'participation lists and officer editor fit $size with enlarged text',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final app = AppController(DemoCivicRepository());
        addTearDown(app.dispose);
        await tester.runAsync(app.bootstrap);
        await app.signIn(
          email: 'officer@smart-sabha.lk',
          password: 'demo12345',
        );
        for (final page in [
          const ProposalsScreen(),
          const ConsultationsScreen(),
          const ConsultationEditor(),
        ]) {
          await tester.pumpWidget(
            AppScope(
              controller: app,
              child: MaterialApp(
                theme: AppTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.5)),
                  child: child!,
                ),
                home: page,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
        }
      },
    );
  }
}
