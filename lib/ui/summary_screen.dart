import 'package:flutter/material.dart';

import '../core/fs/reverter.dart';
import '../core/fs/soft_trash.dart';

/// End of a session: what happened, and the two exits from it.
///
/// Emptying the trash is the only destructive action in Tría, so it is the
/// only one behind a confirmation dialog that states plainly what is lost.
class SummaryScreen extends StatefulWidget {
  final SoftTrash trash;
  final Reverter reverter;
  final String sessionId;

  const SummaryScreen({
    super.key,
    required this.trash,
    required this.reverter,
    required this.sessionId,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  int _trashCount = 0;
  String? _message;

  @override
  void initState() {
    super.initState();
    widget.trash.count().then((c) {
      if (mounted) setState(() => _trashCount = c);
    });
  }

  Future<void> _confirmEmpty() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty the trash?'),
        content: Text(
          '$_trashCount files will be deleted permanently. '
          'This is the only action in Tría that cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-empty'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final deleted = await widget.trash.empty();
    if (!mounted) return;
    setState(() {
      _trashCount = 0;
      _message = 'Deleted $deleted files';
    });
  }

  Future<void> _revertSession() async {
    final reverted = await widget.reverter.revertSession(widget.sessionId);
    if (!mounted) return;
    setState(() => _message = 'Put $reverted files back where they were');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session summary')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$_trashCount files waiting in the soft trash'),
            const SizedBox(height: 24),
            FilledButton.tonal(
              key: const Key('empty-trash'),
              onPressed: _trashCount == 0 ? null : _confirmEmpty,
              child: const Text('Empty trash'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('revert-session'),
              onPressed: _revertSession,
              child: const Text('Revert the whole session'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 24),
              Text(_message!),
            ],
          ],
        ),
      ),
    );
  }
}
