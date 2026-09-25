import 'package:flutter/material.dart';

final _pendingSaves = <Object>{};

/// Keeps the current form open on failure and prevents overlapping saves from it.
Future<bool> saveCivicAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  final Object token = context;
  if (!_pendingSaves.add(token)) return false;
  try {
    await action();
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your changes. Please try again.'),
        ),
      );
    }
    return false;
  } finally {
    _pendingSaves.remove(token);
  }
}
