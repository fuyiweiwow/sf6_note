import 'package:flutter/material.dart';

import '../models/move_step.dart';
import 'move_step_chip.dart';

/// Drop target for building notation. Always keeps minimum drop space.
class NotationDropTarget extends StatelessWidget {
  const NotationDropTarget({
    super.key,
    required this.notation,
    required this.onAppend,
    required this.onDelete,
    required this.onReorder,
    this.onStepTap,
    this.isStepSelected,
    this.numpadMode = false,
    this.enabled = true,
  });

  final List<MoveStep> notation;
  final ValueChanged<MoveStep> onAppend;
  final void Function(int index) onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index)? onStepTap;
  final bool Function(int index)? isStepSelected;
  final bool numpadMode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DragTarget<MoveStep>(
      onWillAcceptWithDetails: (_) => enabled,
      onAcceptWithDetails: enabled ? (details) => onAppend(details.data) : null,
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return Container(
          decoration: BoxDecoration(
            color: isHovering ? Colors.amber.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isHovering ? Colors.amber.shade400 : Colors.grey.shade400,
              width: isHovering ? 2.0 : 1.5,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: notation.isEmpty
                ? Center(
                    child: Text(
                      '将方向或拳脚拖拽到此处\n点击步骤可删除',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : IgnorePointer(
                    ignoring: !enabled,
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: _buildChips(),
                      ),
                      // Always keep empty row at bottom for dropping
                      const SizedBox(height: 40),
                    ],
                  ),
                    ),
          ),
        );
      },
    );
  }

  List<Widget> _buildChips() {
    final chips = <Widget>[];
    for (int i = 0; i < notation.length; i++) {
      if (i > 0) {
        chips.add(Text(
          '+',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ));
      }
      chips.add(
        DragTarget<int>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (details) {
            onReorder(details.data, i);
          },
          builder: (context, candidateData, rejectedData) {
            return MoveStepChip(
              key: ValueKey('$i-${notation[i].kind}'),
              step: notation[i],
              index: i,
              onDelete: () => onDelete(i),
              selected: isStepSelected?.call(i) ?? false,
              onTap: onStepTap != null ? () => onStepTap!(i) : null,
              numpadMode: numpadMode,
            );
          },
        ),
      );
    }
    return chips;
  }
}
