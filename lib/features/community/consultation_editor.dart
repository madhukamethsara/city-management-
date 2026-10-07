import 'package:flutter/material.dart';
import '../../models/domain_models.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/save_civic_action.dart';

class ConsultationEditor extends StatefulWidget {
  const ConsultationEditor({super.key});
  @override
  State<ConsultationEditor> createState() => _ConsultationEditorState();
}

class _ConsultationEditorState extends State<ConsultationEditor> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _questions = <_QuestionDraft>[_QuestionDraft(0)];
  int _nextQuestionId = 1;
  final _id = 'con-${DateTime.now().microsecondsSinceEpoch}';
  String? _department;
  DateTime _opening = DateTime.now();
  DateTime _closing = DateTime.now().add(const Duration(days: 14));
  bool _saving = false;
  Consultation? _attempt;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  Future<void> _date(bool opening) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: opening ? _opening : _closing,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (selected != null && mounted) {
      setState(() {
        if (opening) {
          _opening = selected;
        } else {
          _closing = selected;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final app = AppScope.of(context);
    if (!_closing.isAfter(_opening)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Closing date must follow the opening date.'),
        ),
      );
      return;
    }
    final consultation = Consultation(
      id: _id,
      title: _title.text.trim(),
      description: _description.text.trim(),
      department: _department!,
      openingDate: _opening,
      closingDate: _closing,
      questions: [
        for (final draft in _questions)
          ConsultationQuestion(
            id: 'q-${draft.id}',
            question: draft.text.text.trim(),
            options: draft.allowsLongText ? const [] : draft.choices,
            allowsLongText: draft.allowsLongText,
          ),
      ],
      respondedUserIds: const {},
    );
    // Retain the exact request after an uncertain network result.
    _attempt ??= consultation;
    setState(() => _saving = true);
    final success = await saveCivicAction(
      context,
      () => app.createConsultation(_attempt!),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) Navigator.pushReplacementNamed(context, '/consultations/$_id');
  }

  Widget _questionEditor(_QuestionDraft draft, int index) {
    final locked = _attempt != null;
    return Card(
      key: ValueKey(draft.id),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: draft.text,
              readOnly: locked,
              maxLength: 500,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(labelText: 'Question ${index + 1}'),
              validator: (s) => (s?.trim().length ?? 0) < 4
                  ? 'Enter at least 4 characters.'
                  : null,
            ),
            DropdownButtonFormField<bool>(
              value: draft.allowsLongText,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Answer type'),
              items: const [
                DropdownMenuItem(value: true, child: Text('Written answer')),
                DropdownMenuItem(value: false, child: Text('Single choice')),
              ],
              onChanged: locked
                  ? null
                  : (value) => setState(() => draft.allowsLongText = value!),
            ),
            if (!draft.allowsLongText) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: draft.options,
                readOnly: locked,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Options (one per line)',
                  helperText:
                      'Add 2–20 distinct options, up to 200 characters each.',
                  helperMaxLines: 3,
                ),
                validator: (_) {
                  final choices = draft.choices;
                  if (choices.length < 2 ||
                      choices.length > 20 ||
                      choices.any((s) => s.length > 200)) {
                    return 'Add 2–20 options, up to 200 characters each.';
                  }
                  if (choices.map((s) => s.toLowerCase()).toSet().length !=
                      choices.length) {
                    return 'Each option must be distinct.';
                  }
                  return null;
                },
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: locked || _questions.length == 1
                    ? null
                    : () {
                        setState(() => _questions.remove(draft));
                        // Wait until the removed fields detach their listeners.
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          draft.dispose();
                        });
                      },
                icon: const Icon(Icons.delete_outline),
                label: Text('Remove question ${index + 1}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!(app.currentUser?.role.canManageAuthority ?? false)) {
      return const NotFoundScreen(
        message: 'Only officers can create consultations.',
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('New consultation')),
      body: ResponsivePage(
        child: ListView(
          children: [
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _title,
                    maxLength: 130,
                    readOnly: _attempt != null,
                    decoration: const InputDecoration(
                      labelText: 'Consultation title',
                    ),
                    validator: (s) => (s?.trim().length ?? 0) < 8
                        ? 'Enter at least 8 characters.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 10000,
                    readOnly: _attempt != null,
                    decoration: const InputDecoration(
                      labelText: 'What decision will these answers inform?',
                    ),
                    validator: (s) => (s?.trim().length ?? 0) < 20
                        ? 'Enter at least 20 characters.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _department,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Department'),
                    items: app.departments
                        .map(
                          (d) => DropdownMenuItem(
                            value: d.name,
                            child: Text(d.name),
                          ),
                        )
                        .toList(),
                    onChanged: _attempt != null
                        ? null
                        : (s) => setState(() => _department = s),
                    validator: (s) => s == null ? 'Choose a department.' : null,
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _questions.length; i++)
                    _questionEditor(_questions[i], i),
                  OutlinedButton.icon(
                    onPressed: _attempt != null || _questions.length >= 20
                        ? null
                        : () => setState(() {
                            _questions.add(_QuestionDraft(_nextQuestionId++));
                          }),
                    icon: const Icon(Icons.add),
                    label: const Text('Add question'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _attempt != null ? null : () => _date(true),
                    child: Text(
                      'Opens ${_opening.toLocal().toString().split(' ').first}',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _attempt != null ? null : () => _date(false),
                    child: Text(
                      'Closes ${_closing.toLocal().toString().split(' ').first}',
                    ),
                  ),
                  if (_attempt != null)
                    const Text(
                      'Retrying keeps the original consultation details.',
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : 'Publish consultation'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionDraft {
  _QuestionDraft(this.id);

  final int id;
  final text = TextEditingController();
  final options = TextEditingController();
  bool allowsLongText = true;

  List<String> get choices => options.text
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  void dispose() {
    text.dispose();
    options.dispose();
  }
}
