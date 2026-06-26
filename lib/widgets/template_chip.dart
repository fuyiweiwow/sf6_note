import 'package:flutter/material.dart';

import '../models/move_step.dart';
import '../models/move_template.dart';

/// A draggable chip representing a move template.
/// Can be dragged into the notation area to insert as a MoveStepTemplate.
///
/// Sized for touch: a tall enough tap target (~40px+) with a larger font, so
/// it's easy to drag on phones.
///
/// Optional [badge]: a small widget (e.g. a "promote to global" globe) shown
/// at the chip's trailing edge. Its taps are independent of the chip's own
/// long-press (delete) gesture.
class TemplateChip extends StatelessWidget {
  const TemplateChip({
    super.key,
    required this.template,
    this.onLongPress,
    this.badge,
  });

  final MoveTemplate template;
  final VoidCallback? onLongPress;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Draggable<MoveStep>(
      data: template.toMoveStep(),
      feedback: Material(
        color: Colors.transparent,
        elevation: 4,
        child: _buildChip(opacity: 0.85),
      ),
      childWhenDragging: _buildChip(opacity: 0.2),
      child: GestureDetector(
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: _buildChip(),
      ),
    );
  }

  Widget _buildChip({double opacity = 1.0}) {
    return Opacity(
      opacity: opacity,
      child: Container(
        // Generous padding for a comfortable touch target on phones.
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.purple.shade300, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              template.displayText,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              // Badge itself is wrapped for a reliable touch area.
              badge!,
            ],
          ],
        ),
      ),
    );
  }
}
