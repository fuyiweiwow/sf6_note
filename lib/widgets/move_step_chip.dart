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
      onDraggableCanceled: (_, __) => onDelete(),
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
    final isTemplate = step is MoveStepTemplate;

    final inner = Container(
      width: isTemplate ? null : 48,
      height: isTemplate ? null : 48,
      padding: isTemplate
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
          : null,
      decoration: BoxDecoration(
        shape: isTemplate ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: isTemplate ? BorderRadius.circular(6) : null,
        color: selected ? color.withValues(alpha: 0.25) : bgColor,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Center(
        child: Text(
          numpadMode ? step.numpadText : step.displayText,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
          textAlign: TextAlign.center,
        ),
      ),
    );

    // Wrap selected chips in a clear purple ring so the selection is obvious
    // regardless of the chip's own color.
    final chip = selected
        ? Container(
            decoration: BoxDecoration(
              shape: isTemplate ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isTemplate ? BorderRadius.circular(8) : null,
              border: Border.all(color: Colors.purple, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.purple, blurRadius: 6, spreadRadius: 1),
              ],
            ),
            padding: const EdgeInsets.all(2),
            child: inner,
          )
        : inner;

    return Opacity(
      opacity: opacity,
      child: isTemplate
          ? ConstrainedBox(constraints: const BoxConstraints(maxWidth: 120), child: chip)
          : chip,
    );
  }
}
