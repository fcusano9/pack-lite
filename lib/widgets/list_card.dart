import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.list, required this.onTap});

  final PackingList list;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
    final ready = list.isReady;

    final String countText;
    if (list.totalItems == 0) {
      countText = '0 items';
    } else if (ready) {
      countText = 'Ready ✓';
    } else {
      countText = '${list.packedItems} of ${list.totalItems}';
    }

    return Container(
      decoration: BoxDecoration(
        color: harbor.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF17202B).withValues(alpha: 0.06),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Text(list.icon, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              list.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                color: harbor.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: ready ? FontWeight.w700 : FontWeight.w500,
                              color: ready ? harbor.good : harbor.mut,
                            ),
                            child: Text(countText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ProgressBar(progress: list.progress, ready: ready),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.progress,
    required this.ready,
    this.height = 4,
    this.rounded = true,
  });

  final double progress;
  final bool ready;
  final double height;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
    final radius = rounded ? BorderRadius.circular(2) : BorderRadius.zero;
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: height,
        color: harbor.line,
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.centerLeft,
          widthFactor: progress.clamp(0.0, 1.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: ready ? harbor.good : harbor.accent,
          ),
        ),
      ),
    );
  }
}
