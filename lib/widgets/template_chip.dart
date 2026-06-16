import 'package:flutter/material.dart';

import '../models/move_step.dart';
import '../models/move_template.dart';

/// A draggable chip representing a move template.
/// Can be dragged into the notation area to insert as a MoveStepTemplate.
class TemplateChip extends StatelessWidget {
  const TemplateChip({
    super.key,
    required this.template,
    this.onLongPress,
  });

  final MoveTemplate template;
  final VoidCallback? onLongPress;

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
        child: _buildChip(),
      ),
    );
  }

  Widget _buildChip({double opacity = 1.0}) {
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.purple.shade300, width: 1.5),
        ),
        child: Text(
          template.displayText,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.purple.shade700,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
