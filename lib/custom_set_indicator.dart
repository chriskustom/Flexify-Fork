import 'package:flexify/database/database.dart';
import 'package:flutter/material.dart';

class CustomSetIndicator extends StatelessWidget {
  const CustomSetIndicator({
    super.key,
    required this.sets,
    required this.max,
  });

  final List<GymSet> sets;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < max; i++) ...[
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (i < sets.length) ...[
                  SizedBox(
                    height: 16,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${(sets[i].reps.toInt())} × '
                        '${(sets[i].weight)} '
                        '${sets[i].unit}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),

                // Always render the ghost/background bar.
                SizedBox(
                  height: 6,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: theme.colorScheme.outlineVariant,
                    ),
                    child: i < sets.length
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          if (i < max - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}
