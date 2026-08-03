import 'package:flutter/material.dart';

import '../core/fs/reverter.dart';
import '../core/fs/soft_trash.dart';
import '../core/platform/folder_opener.dart';
import '../domain/destination.dart';
import 'theme.dart';
import 'widgets/key_chip.dart';

/// End of a session: what happened, and the ways out of it.
///
/// Emptying the trash is the only destructive action in Tría, so it is the
/// only one behind a confirmation dialog that states plainly what is lost.
class SummaryScreen extends StatefulWidget {
  final SoftTrash trash;
  final Reverter reverter;
  final String sessionId;

  /// Destinations and their totals, so the user can see where the session went
  /// and go straight to any of those folders.
  final List<Destination> destinations;
  final Map<int, int> movedPerSlot;
  final int keptCount;
  final int decidedCount;
  final Duration elapsed;

  final FolderOpener? opener;
  final VoidCallback? onNewSession;

  const SummaryScreen({
    super.key,
    required this.trash,
    required this.reverter,
    required this.sessionId,
    this.destinations = const [],
    this.movedPerSlot = const {},
    this.keptCount = 0,
    this.decidedCount = 0,
    this.elapsed = Duration.zero,
    this.opener,
    this.onNewSession,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late final FolderOpener _opener = widget.opener ?? FolderOpener();
  int _trashCount = 0;
  String? _message;

  @override
  void initState() {
    super.initState();
    widget.trash.count().then((c) {
      if (mounted) setState(() => _trashCount = c);
    });
  }

  Future<void> _open(String path) async {
    final ok = await _opener.reveal(path);
    if (!mounted || ok) return;
    setState(() => _message = 'That folder is no longer there');
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

  String get _rateLine {
    final seconds = widget.elapsed.inMilliseconds / 1000;
    if (seconds <= 0 || widget.decidedCount == 0) {
      return '${widget.decidedCount} files';
    }
    final rate = (widget.decidedCount / seconds).toStringAsFixed(1);
    final minutes = widget.elapsed.inMinutes;
    final duration = minutes > 0 ? '$minutes min' : '${widget.elapsed.inSeconds} s';
    return '${widget.decidedCount} files · $duration · $rate/s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Session finished',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(_rateLine,
                style: const TextStyle(color: TriaColors.textDim, fontSize: 13)),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  for (final destination in widget.destinations)
                    DestinationTotalRow(
                      keyLabel: '${destination.slot}',
                      label: destination.label,
                      count: widget.movedPerSlot[destination.slot] ?? 0,
                      onOpen: () => _open(destination.path),
                      openKey: Key('open-folder-${destination.slot}'),
                    ),
                  DestinationTotalRow(
                    keyLabel: '→',
                    label: 'Left in place',
                    count: widget.keptCount,
                    muted: true,
                  ),
                  DestinationTotalRow(
                    keyLabel: '↑',
                    label: 'Trash',
                    count: _trashCount,
                    muted: true,
                    danger: true,
                    action: FilledButton.tonal(
                      key: const Key('empty-trash'),
                      onPressed: _trashCount == 0 ? null : _confirmEmpty,
                      child: const Text('Empty…'),
                    ),
                  ),
                ],
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!, style: const TextStyle(color: TriaColors.textDim)),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                OutlinedButton(
                  key: const Key('revert-session'),
                  onPressed: _revertSession,
                  child: const Text('Revert the whole session'),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('new-session'),
                  onPressed: widget.onNewSession,
                  child: const Text('New session'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One line of the final tally: where files went, how many, and a way there.
class DestinationTotalRow extends StatelessWidget {
  final String keyLabel;
  final String label;
  final int count;
  final VoidCallback? onOpen;
  final Key? openKey;
  final bool muted;
  final bool danger;
  final Widget? action;

  const DestinationTotalRow({
    super.key,
    required this.keyLabel,
    required this.label,
    required this.count,
    this.onOpen,
    this.openKey,
    this.muted = false,
    this.danger = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: TriaColors.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: danger ? TriaColors.danger.withValues(alpha: 0.4) : TriaColors.border,
          ),
          borderRadius: BorderRadius.circular(kTriaRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              KeyChip(label: keyLabel, muted: muted),
              const SizedBox(width: 14),
              Expanded(child: Text(label)),
              Text('$count', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(width: 16),
              if (action != null)
                action!
              else if (onOpen != null)
                OutlinedButton.icon(
                  key: openKey,
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Open folder'),
                  onPressed: onOpen,
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
