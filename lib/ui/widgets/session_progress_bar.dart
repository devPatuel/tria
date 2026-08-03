import 'package:flutter/material.dart';

import '../theme.dart';

/// How far into the session the user is, and how fast they are going.
///
/// The rate is not vanity: it is what tells someone with 30,000 files whether
/// this is a coffee-length job or an evening, and it is the number that makes
/// the tool feel worth using.
class SessionProgressBar extends StatelessWidget {
  final int decided;
  final int total;
  final double filesPerSecond;

  const SessionProgressBar({
    super.key,
    required this.decided,
    required this.total,
    required this.filesPerSecond,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : decided / total;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: TriaColors.surfaceHigh,
              valueColor: const AlwaysStoppedAnimation(TriaColors.accent),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text('$decided/$total', style: Theme.of(context).textTheme.labelLarge),
        if (filesPerSecond > 0) ...[
          const SizedBox(width: 10),
          Text(
            '· ${filesPerSecond.toStringAsFixed(1)}/s',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: TriaColors.textDim),
          ),
        ],
      ],
    );
  }
}
