import 'package:flutter/material.dart';

import '../models/move_step.dart';

/// A circular button for an attack. Uses Unicode characters: ✊ for punch, ⚡ for kick.
/// Light=blue, Medium=yellow/amber, Heavy=red.
class AttackButton extends StatelessWidget {
  const AttackButton({
    super.key,
    required this.attack,
    this.size = 48,
  });

  final Attack attack;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Draggable<MoveStep>(
      data: MoveStepAttack(attack),
      feedback: _buildButton(opacity: 0.85),
      childWhenDragging: _buildButton(opacity: 0.25),
      child: _buildButton(),
    );
  }

  Color _getBorderColor() => attack.isLight
      ? Colors.blue.shade400
      : attack.isMedium
          ? Colors.amber.shade500
          : Colors.red.shade400;

  Color _getFillColor() => attack.isLight
      ? Colors.blue.shade50
      : attack.isMedium
          ? Colors.amber.shade50
          : Colors.red.shade50;

  Color _getTextColor() => attack.isLight
      ? Colors.blue.shade700
      : attack.isMedium
          ? Colors.amber.shade800
          : Colors.red.shade700;

  Widget _buildButton({double opacity = 1.0}) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _getBorderColor(), width: 2),
          color: _getFillColor(),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Unicode symbol: ✊ for punch, ⚡ for kick
            Text(
              attack.symbol,
              style: TextStyle(
                fontSize: size * 0.35,
                color: _getTextColor(),
              ),
            ),
            // Label: LP/MP/HP or LK/MK/HK
            Text(
              attack.label,
              style: TextStyle(
                fontSize: size * 0.22,
                fontWeight: FontWeight.bold,
                color: _getTextColor(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
