import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../core/preview/preview_cache.dart';
import '../core/preview/preview_types.dart';
import '../domain/decision.dart';
import '../state/session_controller.dart';
import 'key_bindings.dart';
import 'theme.dart';
import 'widgets/destination_panel.dart';
import 'widgets/file_meta.dart';
import 'widgets/key_chip.dart';
import 'widgets/preview_pane.dart';
import 'widgets/session_progress_bar.dart';

/// The screen where the whole session happens: one file, one keystroke.
class TriageScreen extends StatefulWidget {
  /// Injectable so widget tests can run without touching the disk.
  final PreviewCache? cache;

  /// Called when the user asks to see the summary.
  final VoidCallback? onFinish;

  const TriageScreen({super.key, this.cache, this.onFinish});

  @override
  State<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends State<TriageScreen> {
  final _focusNode = FocusNode();
  late final PreviewCache _cache = widget.cache ?? PreviewCache();
  Uint8List? _bytes;
  String? _loadedPath;

  /// Where the last decided file went, so the outgoing image can travel that
  /// way. Motion that points somewhere answers "did that register, and where
  /// did it go?" without a single word of interface.
  Offset _exitDirection = const Offset(1, 0);
  int? _flashedSlot;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _syncPreview(SessionController controller) async {
    final entry = controller.current;
    if (entry == null || entry.path == _loadedPath) return;
    _loadedPath = entry.path;

    // Only read what the preview will actually use. A PDF is rendered from its
    // path, and an archive is never rendered at all — reading either into
    // memory would cost the user gigabytes for nothing.
    final bytes = switch (previewKindFor(entry)) {
      PreviewKind.image => await _cache.load(entry.path),
      PreviewKind.text => await _cache.loadHead(entry.path),
      _ => null,
    };
    if (mounted) setState(() => _bytes = bytes);

    // Warm the next few files while the user looks at this one, images only:
    // they are the ones whose decoding would otherwise be visible.
    final upcoming = <String>[];
    for (var i = 1; i <= 3; i++) {
      final index = controller.decidedCount + i;
      if (index >= controller.totalCount) break;
      final next = controller.fileAt(index);
      if (previewKindFor(next) == PreviewKind.image) upcoming.add(next.path);
    }
    _cache.preload(upcoming);
  }

  void _onKey(KeyEvent event, SessionController controller) {
    if (event is! KeyDownEvent) return;
    final entry = controller.current;
    if (entry == null) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      controller.undo();
      return;
    }

    // Stopping is a normal way to end a session, not an escape hatch: nobody
    // sorts thirty thousand files in one sitting, and the totals so far are
    // worth seeing.
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onFinish?.call();
      return;
    }

    final decision = decisionForKey(event.logicalKey, entry.path);
    if (decision == null) return;

    setState(() {
      _exitDirection = switch (decision.kind) {
        DecisionKind.move => const Offset(1, 0), // toward the panel
        DecisionKind.trash => const Offset(0, -1),
        DecisionKind.postpone => const Offset(0, 1),
        DecisionKind.keep => const Offset(0.4, 0),
      };
      _flashedSlot = decision.kind == DecisionKind.move ? decision.slot : null;
    });

    controller.decide(decision);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();
    // Reading the file is a side effect, so it happens after the frame rather
    // than during build.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _syncPreview(controller));

    if (controller.isFinished) return _FinishedState(controller: controller, onFinish: widget.onFinish);

    final entry = controller.current!;

    return Scaffold(
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) => _onKey(event, controller),
        child: Column(
          children: [
            if (controller.failures.isNotEmpty)
              _FailureBanner(count: controller.failures.length),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.basename(controller.config.sourceRoot),
                            style: const TextStyle(
                              color: TriaColors.textDim,
                              fontSize: 12,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: TriaMotion.decision,
                              switchInCurve: TriaMotion.curve,
                              switchOutCurve: TriaMotion.curve,
                              transitionBuilder: (child, animation) {
                                final isIncoming =
                                    child.key == ValueKey(entry.path);
                                final begin = isIncoming
                                    ? -_exitDirection * 0.06
                                    : _exitDirection * 0.35;
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: begin,
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: PreviewPane(
                                key: ValueKey(entry.path),
                                entry: entry,
                                bytes: _bytes,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          FileMeta(entry: entry),
                        ],
                      ),
                    ),
                  ),
                  DestinationPanel(
                    destinations: controller.config.destinations,
                    counts: controller.movedPerSlot,
                    flashedSlot: _flashedSlot,
                  ),
                ],
              ),
            ),
            _BottomBar(controller: controller, onFinish: widget.onFinish),
          ],
        ),
      ),
    );
  }
}

/// Tells the user, mid-session, that the disk refused a file.
///
/// The queue works behind the interface, so without this the session would go
/// on at two decisions per second over a destination that accepts nothing and
/// the user would only find out at the end, or never.
class _FailureBanner extends StatelessWidget {
  final int count;

  const _FailureBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    final plural = count == 1 ? 'file' : 'files';
    return Container(
      key: const Key('failure-banner'),
      width: double.infinity,
      color: TriaColors.danger.withValues(alpha: 0.18),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 18, color: TriaColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count $plural could not be moved and stayed where they were. '
              'Check the destination folder.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final SessionController controller;
  final VoidCallback? onFinish;

  const _BottomBar({required this.controller, this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
      decoration: const BoxDecoration(
        color: TriaColors.surface,
        border: Border(top: BorderSide(color: TriaColors.border)),
      ),
      child: Column(
        children: [
          SessionProgressBar(
            decided: controller.decidedCount,
            total: controller.totalCount,
            filesPerSecond: controller.filesPerSecond,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const _Legend(keyLabel: '↑', action: 'trash'),
              const SizedBox(width: 20),
              const _Legend(keyLabel: '↓', action: 'later'),
              const SizedBox(width: 20),
              const _Legend(keyLabel: '←', action: 'undo'),
              const SizedBox(width: 20),
              const _Legend(keyLabel: '→', action: 'keep'),
              const Spacer(),
              const _Legend(keyLabel: 'esc', action: 'stop'),
              const SizedBox(width: 12),
              OutlinedButton(
                key: const Key('finish-session'),
                onPressed: onFinish,
                child: const Text('Finish'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String keyLabel;
  final String action;

  const _Legend({required this.keyLabel, required this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KeyChip(label: keyLabel, muted: true),
        const SizedBox(width: 8),
        Text(action,
            style: const TextStyle(color: TriaColors.textDim, fontSize: 12)),
      ],
    );
  }
}

class _FinishedState extends StatelessWidget {
  final SessionController controller;
  final VoidCallback? onFinish;

  const _FinishedState({required this.controller, this.onFinish});

  @override
  Widget build(BuildContext context) {
    final postponed = controller.postponed.length;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Session finished',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '${controller.decidedCount} files decided',
              style: const TextStyle(color: TriaColors.textDim),
            ),
            const SizedBox(height: 24),
            if (postponed > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton(
                  key: const Key('review-postponed'),
                  onPressed: controller.startPostponedRound,
                  child: Text('Review $postponed postponed'),
                ),
              ),
            FilledButton(
              key: const Key('view-summary'),
              onPressed: onFinish,
              child: const Text('View summary'),
            ),
          ],
        ),
      ),
    );
  }
}
