import 'package:flutter/material.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_widgets.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});
  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  final List<Map<String, dynamic>> _events = [];
  String? _session;
  bool _loading = false;
  bool _more = true;
  bool _failed = false;
  int _generation = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = AppScope.of(context).sessionKey;
    if (_session != session) {
      _session = session;
      _events.clear();
      _more = true;
      _load(refresh: true);
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading && !refresh) return;
    final app = AppScope.of(context);
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await app.auditEvents(
        beforeId: refresh || _events.isEmpty ? null : _events.last['id'] as int,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (refresh) _events.clear();
        _events.addAll(page);
        _more = page.length == 50;
      });
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!app.canManageUsers) {
      return const NotFoundScreen(message: 'Administrator access required.');
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration history'),
        actions: [
          IconButton(
            tooltip: 'Refresh history',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _load(refresh: true),
          ),
        ],
      ),
      body: ResponsivePage(
        child: ListView(
          children: [
            if (_events.isEmpty && !_loading && !_failed)
              const Text('No recorded changes yet.'),
            for (final event in _events)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CivicCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${event['action']} · ${event['entity']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Record: ${event['recordId']}'),
                      Text(
                        'By: ${event['actorId'] ?? 'Database administrator'}',
                      ),
                      Text(
                        formatDate(
                          DateTime.parse(
                            event['createdAt'] as String,
                          ).toLocal(),
                          includeYear: true,
                        ),
                      ),
                      for (final entry in Map<String, dynamic>.from(
                        event['changes'] as Map,
                      ).entries)
                        Text(
                          '${entry.key}: ${entry.value['before'] ?? '—'} → ${entry.value['after'] ?? '—'}',
                        ),
                    ],
                  ),
                ),
              ),
            if (_failed)
              TextButton(
                onPressed: () => _load(refresh: _events.isEmpty),
                child: const Text('Could not load history. Retry'),
              ),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_more && !_loading && !_failed)
              TextButton(
                onPressed: _load,
                child: const Text('Load older changes'),
              ),
          ],
        ),
      ),
    );
  }
}
