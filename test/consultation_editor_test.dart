import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_sabha/data/civic_failure.dart';
import 'package:smart_sabha/data/demo_civic_repository.dart';
import 'package:smart_sabha/features/community/consultation_editor.dart';
import 'package:smart_sabha/models/domain_models.dart';
import 'package:smart_sabha/state/app_controller.dart';
import 'package:smart_sabha/state/app_scope.dart';

class RecordingConsultations extends DemoCivicRepository {
  final attempts = <Consultation>[];

  @override
  Future<Consultation> createConsultation(Consultation consultation) async {
    attempts.add(consultation);
    if (attempts.length == 1) {
      throw const CivicFailure('Connection lost. Please retry.');
    }
    return consultation;
  }
}

void main() {
  testWidgets(
    'mixed questions validate, publish and preserve a failed request',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = RecordingConsultations();
      final app = AppController(repo);
      addTearDown(app.dispose);
      await tester.runAsync(app.bootstrap);
      await app.signIn(email: 'officer@smart-sabha.lk', password: 'demo12345');
      await tester.pumpWidget(
        AppScope(
          controller: app,
          child: MaterialApp(
            home: const ConsultationEditor(),
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Published')),
            ),
          ),
        ),
      );
      Future<void> enter(String label, String value) async {
        final field = find.widgetWithText(TextFormField, label);
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
        await tester.pumpAndSettle();
      }

      await enter('Consultation title', 'Neighbourhood transport plans');
      await enter(
        'What decision will these answers inform?',
        'Help decide which transport improvements to prioritise next year.',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(app.departments.first.name).last);
      await tester.pumpAndSettle();
      await enter('Question 1', 'Which improvement should come first?');
      await tester.tap(find.byType(DropdownButtonFormField<bool>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Single choice').last);
      await tester.pumpAndSettle();
      await enter('Options (one per line)', 'Paths\n paths ');

      Future<void> publish() async {
        final button = find.text('Publish consultation');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await publish();
      expect(find.text('Each option must be distinct.'), findsOneWidget);
      expect(repo.attempts, isEmpty);
      await enter('Options (one per line)', 'Paths');
      await publish();
      expect(
        find.text('Add 2–20 options, up to 200 characters each.'),
        findsOneWidget,
      );
      expect(repo.attempts, isEmpty);
      await enter('Options (one per line)', ' Paths \n\n Bus stops ');
      await tester.ensureVisible(find.text('Add question'));
      await tester.tap(find.text('Add question'));
      await tester.pumpAndSettle();
      await enter('Question 2', 'Explain your preferred improvement.');
      await tester.ensureVisible(find.text('Add question'));
      await tester.tap(find.text('Add question'));
      await tester.pumpAndSettle();
      await enter('Question 3', 'A question to remove.');
      await tester.ensureVisible(find.text('Remove question 3'));
      await tester.tap(find.text('Remove question 3'));
      await tester.pumpAndSettle();
      await publish();
      expect(repo.attempts, hasLength(1));
      final saved = repo.attempts.single;
      expect(saved.questions, hasLength(2));
      expect(saved.questions.first.options, ['Paths', 'Bus stops']);
      expect(saved.questions.first.allowsLongText, isFalse);
      expect(saved.questions.last.allowsLongText, isTrue);
      expect(saved.questions.last.options, isEmpty);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.widgetWithText(TextFormField, 'Question 2'),
                matching: find.byType(TextField),
              ),
            )
            .readOnly,
        isTrue,
      );
      await publish();
      expect(repo.attempts, hasLength(2));
      expect(identical(repo.attempts.first, repo.attempts.last), isTrue);
      expect(find.text('Published'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
