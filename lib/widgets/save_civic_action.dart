import '../data/civic_failure.dart';
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
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is CivicFailure
                ? error.message
                : 'Could not save your changes. Please try again.',
          ),
        ),
      );
    }
    return false;
  } finally {
    _pendingSaves.remove(token);
  }
}
