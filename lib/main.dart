import 'package:flutter/material.dart';
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
import 'ui/triage_screen.dart';

void main() => runApp(const TriaApp());

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
      theme: ThemeData.dark(useMaterial3: true),
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
    final controller = SessionController(
      config: config,
      queue: OperationQueue(
        config: config,
        journal: journal,
        mover: mover,
        trash: SoftTrash(config.trashPath, mover),
      ),
      reverter: Reverter(journal, mover),
      scanner: FileScanner(),
    );
    await controller.start();

    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: controller,
        child: const TriageScreen(),
      ),
    ));
  }
}
