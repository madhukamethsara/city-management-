import 'package:flutter/material.dart';
import '../../state/app_scope.dart';
import '../../widgets/save_civic_action.dart';

/// Shared paging controls keep the server cursor independent of detail lookups.
class AnnouncementControls extends StatefulWidget {
  const AnnouncementControls({super.key});
  @override
  State<AnnouncementControls> createState() => _AnnouncementControlsState();
}

class _AnnouncementControlsState extends State<AnnouncementControls> {
  bool _busy = false;
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await saveCivicAction(context, action);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (!controller.usesPersistentData) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(controller.refreshData),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh notices'),
          ),
          if (controller.hasMoreAnnouncements)
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(controller.loadMoreAnnouncements),
              child: const Text('Load more notices'),
            ),
          if (_busy)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}
