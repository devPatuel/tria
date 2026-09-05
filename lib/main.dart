import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import 'core/fs/file_mover.dart';
import 'core/fs/operation_queue.dart';
import 'core/fs/reverter.dart';
import 'core/fs/soft_trash.dart';
import 'core/journal/journal.dart';
import 'core/scanner/file_scanner.dart';
import 'core/storage/app_paths.dart';
import 'domain/session_config.dart';
import 'state/session_controller.dart';
import 'ui/setup_screen.dart';
import 'ui/summary_screen.dart';
import 'ui/theme.dart';
import 'ui/triage_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Not strictly required while PDFs are only shown through pdfrx widgets, but
  // it costs one line and removes a whole class of runtime-only failure.
  pdfrxFlutterInitialize();
  runApp(const TriaApp());
}

/// Root widget of the application.
///
/// Holds only theming and the initial route; all behaviour lives in the
/// controllers under `lib/state/`.
class TriaApp extends StatelessWidget {
  const TriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tría',
      debugShowCheckedModeBanner: false,
      theme: triaDarkTheme(),
      home: Builder(
        builder: (context) => SetupScreen(
          onStart: (config) => _startSession(context, config),
        ),
      ),
    );
  }

  /// Builds the whole session stack and hands it to the triage screen.
  ///
  /// The journal lives in the OS application-support directory, never next to
  /// the user's files: it records full paths and must not end up inside a
  /// folder the user is about to sort or share.
  Future<void> _startSession(BuildContext context, SessionConfig config) async {
    final journal = JsonlJournal(await AppPaths.journalFor(config.id));
    final mover = FileMover();
    final trash = SoftTrash(config.trashPath, mover);
    final reverter = Reverter(journal, mover);
    final queue = OperationQueue(
      config: config,
      journal: journal,
      mover: mover,
      trash: trash,
    );
    final controller = SessionController(
      config: config,
      queue: queue,
      reverter: reverter,
      scanner: FileScanner(),
    );
    await controller.start();

    if (!context.mounted) return;
    final navigator = Navigator.of(context);

    navigator.push(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: controller,
        child: TriageScreen(
          onFinish: () async {
            // The last decisions may still be in flight; the summary counts
            // what is on disk, so it must wait for the disk.
            await queue.drain();
            navigator.push(MaterialPageRoute(
              builder: (_) => SummaryScreen(
                trash: trash,
                reverter: reverter,
                sessionId: config.id,
                destinations: config.destinations,
                movedPerSlot: controller.movedPerSlot,
                keptCount: controller.keptCount,
                decidedCount: controller.decidedCount,
                elapsed: controller.elapsed,
                // Back to the very first screen: a finished session is done,
                // and its controller and queue go with it.
                onNewSession: () =>
                    navigator.popUntil((route) => route.isFirst),
              ),
            ));
          },
        ),
      ),
    ));
  }
}
