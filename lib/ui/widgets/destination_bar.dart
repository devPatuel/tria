import 'package:flutter/material.dart';

import '../../domain/destination.dart';

/// Always-visible reminder of what each number key does.
///
/// It stays on screen permanently by design: a user three thousand files into
/// a session should never have to recall a mapping.
class DestinationBar extends StatelessWidget {
  final List<Destination> destinations;

  const DestinationBar({super.key, required this.destinations});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final d in destinations)
          Chip(
            avatar: CircleAvatar(child: Text('${d.slot}')),
            label: Text(d.label),
          ),
      ],
    );
  }
}
