import 'package:flutter/material.dart';

import '../models/move_step.dart';

/// A circular button showing a direction arrow that can be dragged.
class DirectionButton extends StatelessWidget {
  const DirectionButton({
    super.key,
    required this.direction,
    this.size = 48,
    this.numpadMode = false,
  });

  final Direction direction;
  final double size;
  final bool numpadMode;

  @override
  Widget build(BuildContext context) {
    return Draggable<MoveStep>(
      data: MoveStepDirection(direction),
      feedback: _buildButton(opacity: 0.8),
      childWhenDragging: _buildButton(opacity: 0.3),
      child: _buildButton(),
    );
  }

  Widget _buildButton({double opacity = 1.0}) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.grey.shade600,
            width: 2,
          ),
          color: Colors.grey.shade100,
        ),
        child: Center(
          child: Text(
            numpadMode ? direction.numpad.toString() : direction.symbol,
            style: TextStyle(
              fontSize: size * 0.45,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade800,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
