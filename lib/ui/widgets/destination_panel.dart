import 'package:flutter/material.dart';

import '../../domain/destination.dart';
import '../theme.dart';
import 'key_chip.dart';

/// The permanent map of "which key sends where", with a running total.
///
/// It never scrolls out of view and never collapses: a user three thousand
/// files into a session should not have to remember a mapping, and seeing the
/// counts grow is the only feedback that the session is going anywhere.
class DestinationPanel extends StatelessWidget {
  final List<Destination> destinations;
  final Map<int, int> counts;

  /// The slot that just received a file, briefly highlighted.
  final int? flashedSlot;

  const DestinationPanel({
    super.key,
    required this.destinations,
    required this.counts,
    this.flashedSlot,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: TriaColors.surface,
        border: Border(left: BorderSide(color: TriaColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DESTINATIONS',
            style: TextStyle(
              color: TriaColors.textDim,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: destinations.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final destination = destinations[index];
                return DestinationTile(
                  destination: destination,
                  count: counts[destination.slot] ?? 0,
                  flashed: flashedSlot == destination.slot,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One destination: its key, its name, and how many files have gone there.
class DestinationTile extends StatelessWidget {
  final Destination destination;
  final int count;
  final bool flashed;

  const DestinationTile({
    super.key,
    required this.destination,
    required this.count,
    this.flashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TriaMotion.decision,
      curve: TriaMotion.curve,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: flashed
            ? TriaColors.accent.withValues(alpha: 0.18)
            : TriaColors.surfaceHigh,
        border: Border.all(
          color: flashed ? TriaColors.accent : TriaColors.border,
        ),
        borderRadius: BorderRadius.circular(kTriaRadius),
      ),
      child: Row(
        children: [
          KeyChip(label: '${destination.slot}'),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              destination.label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: TriaColors.text, fontSize: 14),
            ),
          ),
          Text(
            '$count',
            key: Key('count-${destination.slot}'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}
