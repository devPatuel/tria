import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/preview/preview_cache.dart';
import '../state/session_controller.dart';
import 'key_bindings.dart';
import 'widgets/destination_bar.dart';
import 'widgets/preview_pane.dart';

/// The screen where the whole session happens: one file, one keystroke.
class TriageScreen extends StatefulWidget {
  /// Injectable so widget tests can run without touching the disk.
  final PreviewCache? cache;

  const TriageScreen({super.key, this.cache});

  @override
  State<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends State<TriageScreen> {
  final _focusNode = FocusNode();
  late final PreviewCache _cache = widget.cache ?? PreviewCache();
  Uint8List? _bytes;
  String? _loadedPath;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _syncPreview(SessionController controller) async {
    final entry = controller.current;
    if (entry == null || entry.path == _loadedPath) return;
    _loadedPath = entry.path;

    final bytes = await _cache.load(entry.path);
    if (mounted) setState(() => _bytes = bytes);

    // Warm the next few files while the user looks at this one.
    final upcoming = <String>[];
    for (var i = 1; i <= 3; i++) {
      final index = controller.decidedCount + i;
      if (index < controller.totalCount) upcoming.add(controller.fileAt(index).path);
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
    final decision = decisionForKey(event.logicalKey, entry.path);
    if (decision != null) controller.decide(decision);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();
    // Reading the file is a side effect, so it happens after the frame rather
    // than during build.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _syncPreview(controller));

    if (controller.isFinished) {
      return const Scaffold(body: Center(child: Text('Session finished')));
    }

    final entry = controller.current!;
    return Scaffold(
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) => _onKey(event, controller),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(entry.path.split('/').last,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text('${controller.decidedCount}/${controller.totalCount}'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: PreviewPane(entry: entry, bytes: _bytes)),
              const SizedBox(height: 12),
              DestinationBar(destinations: controller.config.destinations),
            ],
          ),
        ),
      ),
    );
  }
}
