import 'package:flutter/material.dart';

import '../domain/destination.dart';
import '../domain/session_config.dart';

/// Where a session is configured: source folder, recursion, and the nine
/// destination slots.
class SetupScreen extends StatefulWidget {
  final void Function(SessionConfig) onStart;

  const SetupScreen({super.key, required this.onStart});

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

  void _start() {
    widget.onStart(SessionConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sourceRoot: _sourceController.text,
      recursive: _recursive,
      destinations: _destinations,
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
    return Scaffold(
      appBar: AppBar(title: const Text('New session')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('source-root'),
              controller: _sourceController,
              decoration: const InputDecoration(labelText: 'Source folder'),
              onChanged: (_) => setState(() {}),
            ),
            SwitchListTile(
              title: const Text('Include subfolders'),
              value: _recursive,
              onChanged: (v) => setState(() => _recursive = v),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('destination-label'),
                    controller: _labelController,
                    decoration: const InputDecoration(labelText: 'Label'),
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
                IconButton(
                  key: const Key('add-destination'),
                  icon: const Icon(Icons.add),
                  onPressed: _addDestination,
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.orange)),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                key: const Key('destination-list'),
                children: [
                  for (final d in _destinations)
                    ListTile(
                      leading: CircleAvatar(child: Text('${d.slot}')),
                      title: Text(d.label),
                      subtitle: Text(d.path),
                    ),
                ],
              ),
            ),
            FilledButton(
              onPressed: _sourceController.text.isEmpty ? null : _start,
              child: const Text('Start sorting'),
            ),
          ],
        ),
      ),
    );
  }
}
