import 'package:flutter/material.dart';

import '../models/move_step.dart';

/// A chip in the notation sequence. Tap to delete. Drag handle to reorder.
class MoveStepChip extends StatelessWidget {
  const MoveStepChip({
    super.key,
    required this.step,
    required this.index,
    required this.onDelete,
    this.selected = false,
    this.onTap,
    this.numpadMode = false,
  });

  final MoveStep step;
  final int index;
  final VoidCallback onDelete;
  final bool selected;
  final VoidCallback? onTap;
  final bool numpadMode;

  @override
  Widget build(BuildContext context) {
    return Draggable<int>(
      data: index,
      feedback: Material(
        color: Colors.transparent,
        elevation: 4,
        child: _buildChip(opacity: 0.85, isDragging: true),
      ),
      childWhenDragging: _buildChip(opacity: 0.2),
      child: GestureDetector(
        onTap: onTap ?? onDelete,
        child: _buildChip(),
      ),
    );
  }

  (Color, Color) _getColors() {
    return switch (step) {
      MoveStepAttack(:final attack) => attack.isLight
          ? (Colors.blue.shade700, Colors.blue.shade50)
          : attack.isMedium
              ? (Colors.amber.shade700, Colors.amber.shade50)
              : (Colors.red.shade700, Colors.red.shade50),
      MoveStepTemplate() => (Colors.purple.shade700, Colors.purple.shade50),
      MoveStepDirection() => (Colors.grey.shade800, Colors.grey.shade200),
    };
  }

  Widget _buildChip({double opacity = 1.0, bool isDragging = false}) {
    final (color, bgColor) = _getColors();

    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: color,
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.drag_indicator,
              size: 14,
              color: color.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 4),
            if (step case MoveStepTemplate tmpl)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tmpl.displayText,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                  Text(numpadMode ? tmpl.numpadText : tmpl.stepsPreview,
                      style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.6))),
                ],
              )
            else
              Text(numpadMode ? step.numpadText : step.displayText,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            // Delete button (always available, independent of selection tap)
            if (!isDragging)
              GestureDetector(
                onTap: onDelete,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.close, size: 14, color: color.withValues(alpha: 0.5)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
