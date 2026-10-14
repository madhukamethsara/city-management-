import 'package:flutter/material.dart';

import '../../data/civic_failure.dart';
import '../../models/consultation_results.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_widgets.dart';

class ConsultationResultsScreen extends StatefulWidget {
  const ConsultationResultsScreen({super.key, required this.consultationId});

  final String consultationId;

  @override
  State<ConsultationResultsScreen> createState() =>
      _ConsultationResultsScreenState();
}

class _ConsultationResultsScreenState extends State<ConsultationResultsScreen> {
  Future<ConsultationResults>? _results;
  String? _session;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    if (!app.isOfficer) {
      _session = app.sessionKey;
      _results = null;
      return;
    }
    if (_results == null || _session != app.sessionKey) {
      _session = app.sessionKey;
      _results = app.consultationResults(widget.consultationId);
    }
  }

  void _refresh() => setState(() {
    _results = AppScope.of(context).consultationResults(widget.consultationId);
  });

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultation results'),
        actions: [
          if (app.isOfficer)
            IconButton(
              tooltip: 'Refresh results',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: ResponsivePage(
        child: !app.isOfficer
            ? const Center(child: Text('Officer access required.'))
            : FutureBuilder<ConsultationResults>(
                future: _results,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            error is CivicFailure
                                ? error.message
                                : 'Could not load results. Please try again.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _refresh,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    );
                  }
                  final results = snapshot.data!;
                  return ListView(
                    children: [
                      Text(
                        app.consultationById(widget.consultationId)?.title ??
                            'Results',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text('${results.totalResponses} total responses'),
                      const SizedBox(height: 8),
                      const Text(
                        'Individual identities and written answers remain private.',
                      ),
                      if (results.totalResponses == 0) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'No responses yet. Refresh after residents participate.',
                        ),
                      ],
                      for (final question in results.questions) ...[
                        const SizedBox(height: 16),
                        CivicCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                question.question,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text('${question.responseCount} answers'),
                              if (question.allowsLongText) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Written responses are private; only the answer count is shown.',
                                ),
                              ] else
                                for (final option
                                    in question.optionCounts.entries) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    '${option.key}: ${option.value} (${_percentage(option.value, question.responseCount)}%)',
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: question.responseCount == 0
                                        ? 0
                                        : option.value / question.responseCount,
                                    semanticsLabel: option.key,
                                    semanticsValue:
                                        '${option.value} of ${question.responseCount} answers',
                                  ),
                                ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
      ),
    );
  }

  String _percentage(int count, int total) =>
      total == 0 ? '0' : (100 * count / total).toStringAsFixed(1);
}
