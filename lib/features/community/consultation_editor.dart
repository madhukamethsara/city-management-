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
  final _questions = TextEditingController();
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
    _questions.dispose();
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
    final lines = _questions.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final consultation = Consultation(
      id: _id,
      title: _title.text.trim(),
      description: _description.text.trim(),
      department: _department!,
      openingDate: _opening,
      closingDate: _closing,
      questions: [
        for (var i = 0; i < lines.length; i++)
          ConsultationQuestion(
            id: 'q-$i',
            question: lines[i],
            options: const [],
            allowsLongText: true,
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
                  TextFormField(
                    controller: _questions,
                    minLines: 4,
                    maxLines: 12,
                    readOnly: _attempt != null,
                    decoration: const InputDecoration(
                      labelText: 'Questions (one per line)',
                      helperText:
                          'Residents answer each question in their own words.',
                    ),
                    validator: (s) {
                      final lines = (s ?? '')
                          .split('\n')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList();
                      return lines.isEmpty ||
                              lines.length > 20 ||
                              lines.any((q) => q.length < 4 || q.length > 500)
                          ? 'Add 1–20 questions, each 4–500 characters.'
                          : null;
                    },
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
