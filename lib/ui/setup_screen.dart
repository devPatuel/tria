import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../core/fs/folder_access.dart';
import '../domain/destination.dart';
import '../domain/session_config.dart';
import 'theme.dart';
import 'widgets/key_chip.dart';

/// Where a session is configured: source folder, recursion, and the nine
/// destination slots.
class SetupScreen extends StatefulWidget {
  final void Function(SessionConfig) onStart;

  /// Injected so the screen's own tests never touch the disk.
  final FolderAccess? access;

  const SetupScreen({super.key, required this.onStart, this.access});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _labelController = TextEditingController();
  final _pathController = TextEditingController();
  final _sourceController = TextEditingController();
  final _destinations = <Destination>[];
  var _recursive = true;
  String? _error;
  var _checking = false;

  late final FolderAccess _access = widget.access ?? FolderAccess();

  /// Opens the system folder dialog.
  ///
  /// On macOS this is not cosmetic: picking a folder through the system dialog
  /// is what grants a sandboxed app access to it. A path typed by hand grants
  /// nothing, and the session would come up empty.
  Future<void> _pickSourceFolder() async {
    final path = await getDirectoryPath();
    if (path == null || !mounted) return;
    setState(() => _sourceController.text = path);
  }

  Future<void> _pickDestinationFolder() async {
    final path = await getDirectoryPath();
    if (path == null || !mounted) return;
    setState(() => _pathController.text = path);
  }

  void _addDestination() {
    if (_destinations.length >= 9) {
      setState(() => _error = 'All nine slots are taken');
      return;
    }
    if (_labelController.text.isEmpty || _pathController.text.isEmpty) return;

    setState(() {
      _destinations.add(Destination(
        slot: _destinations.length + 1,
        label: _labelController.text,
        path: _pathController.text,
      ));
      _labelController.clear();
      _pathController.clear();
      _error = null;
    });
  }

  void _removeDestination(int index) {
    setState(() {
      _destinations.removeAt(index);
      // Slots are keyboard positions, so they must stay contiguous from 1.
      final renumbered = <Destination>[];
      for (var i = 0; i < _destinations.length; i++) {
        renumbered.add(Destination(
          slot: i + 1,
          label: _destinations[i].label,
          path: _destinations[i].path,
        ));
      }
      _destinations
        ..clear()
        ..addAll(renumbered);
      _error = null;
    });
  }

  bool get _canStart =>
      !_checking &&
      _sourceController.text.isNotEmpty &&
      _destinations.isNotEmpty;

  /// Why the session cannot start, in the user's terms.
  ///
  /// A disabled button with no explanation is the single most common way an
  /// interface reads as broken.
  String? get _blockingReason {
    if (_error != null) return _error;
    if (_checking) return 'Checking the folders…';
    if (_sourceController.text.isEmpty) return 'Choose a source folder to start';
    if (_destinations.isEmpty) return 'Add at least one destination';
    return null;
  }

  /// Checks every folder before the session exists.
  ///
  /// A move needs write access on both ends, and a drive mounted read-only
  /// accepts none of it while still looking normal. Finding that out here
  /// costs a moment; finding it out mid-session means hundreds of decisions
  /// that went nowhere.
  Future<void> _start() async {
    setState(() {
      _checking = true;
      _error = null;
    });

    final source = _sourceController.text;
    var problem =
        await _access.isWritable(source) ? null : 'The source folder ($source)';
    if (problem == null) {
      for (final destination in _destinations) {
        if (!await _access.isWritable(destination.path)) {
          problem = '${destination.label} (${destination.path})';
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() => _checking = false);

    if (problem != null) {
      setState(() => _error = '$problem cannot be written to. '
          'If it is an external drive, check that it is not read-only.');
      return;
    }

    widget.onStart(SessionConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sourceRoot: _sourceController.text,
      recursive: _recursive,
      destinations: List.of(_destinations),
    ));
  }

  @override
  void dispose() {
    _labelController.dispose();
    _pathController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reason = _blockingReason;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New session', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text(
              'Point Tría at a folder and give each number key a destination.',
              style: TextStyle(color: TriaColors.textDim, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _SectionCard(
              title: 'Source',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('source-root'),
                          controller: _sourceController,
                          decoration: const InputDecoration(
                            labelText: 'Folder to sort',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        key: const Key('pick-source'),
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('Choose folder…'),
                        onPressed: _pickSourceFolder,
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include subfolders'),
                    subtitle: const Text(
                      'Everything below the folder is flattened into one queue',
                      style: TextStyle(color: TriaColors.textDim, fontSize: 12),
                    ),
                    value: _recursive,
                    onChanged: (v) => setState(() => _recursive = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _SectionCard(
                title: 'Destinations',
                trailing: Text(
                  '${_destinations.length}/9',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: TriaColors.textDim,
                      ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 160,
                          child: TextField(
                            key: const Key('destination-label'),
                            controller: _labelController,
                            decoration: const InputDecoration(labelText: 'Name'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            key: const Key('destination-path'),
                            controller: _pathController,
                            decoration: const InputDecoration(labelText: 'Folder'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          key: const Key('pick-destination'),
                          icon: const Icon(Icons.folder_open, size: 18),
                          tooltip: 'Choose folder',
                          onPressed: _pickDestinationFolder,
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          key: const Key('add-destination'),
                          onPressed: _addDestination,
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _destinations.isEmpty
                          ? const Center(
                              child: Text(
                                'No destinations yet.\nThe first one becomes key 1.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: TriaColors.textDim),
                              ),
                            )
                          : ListView.separated(
                              key: const Key('destination-list'),
                              itemCount: _destinations.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final d = _destinations[index];
                                return _DestinationRow(
                                  destination: d,
                                  onRemove: () => _removeDestination(index),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (reason != null)
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          _error == null
                              ? Icons.info_outline
                              : Icons.warning_amber_rounded,
                          size: 16,
                          color: _error == null
                              ? TriaColors.textDim
                              : TriaColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reason,
                            style: TextStyle(
                              color: _error == null
                                  ? TriaColors.textDim
                                  : TriaColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Spacer(),
                FilledButton(
                  key: const Key('start-sorting'),
                  onPressed: _canStart ? _start : null,
                  child: const Text('Start sorting'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled panel. Definition comes from a hairline border, not a shadow:
/// shadows on a near-black background read as smudges.
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    // Material, not a decorated Container: ListTiles paint their background and
    // ink on the nearest Material ancestor, and a DecoratedBox in between
    // swallows both.
    return Material(
      color: TriaColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: TriaColors.border),
        borderRadius: BorderRadius.circular(kTriaRadius + 4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: TriaColors.textDim,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

class _DestinationRow extends StatelessWidget {
  final Destination destination;
  final VoidCallback onRemove;

  const _DestinationRow({required this.destination, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kTriaRadius),
        side: const BorderSide(color: TriaColors.border),
      ),
      tileColor: TriaColors.surfaceHigh,
      leading: KeyChip(label: '${destination.slot}'),
      title: Text(destination.label),
      subtitle: Text(
        destination.path,
        style: const TextStyle(color: TriaColors.textDim, fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 16),
        tooltip: 'Remove',
        onPressed: onRemove,
      ),
    );
  }
}
