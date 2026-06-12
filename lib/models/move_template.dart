import 'package:uuid/uuid.dart';

import 'move_step.dart';

const _uuid = Uuid();

/// A reusable move template composed of direction + attack steps.
/// Stored per-character, can be dragged into combo notation as a unit.
class MoveTemplate {
  MoveTemplate({
    String? id,
    required this.name,
    List<MoveStep>? steps,
  })  : id = id ?? _uuid.v4(),
        steps = steps ?? [];

  final String id;
  String name;
  List<MoveStep> steps;

  /// Short display text: name or step summary.
  String get displayText {
    if (name.isNotEmpty) return name;
    return steps.map((s) => s.displayText).join('');
  }

  /// One-line preview of the steps.
  String get stepsPreview => steps.map((s) => s.displayText).join(' ');

  /// Convert to a MoveStepTemplate for use in notation.
  MoveStepTemplate toMoveStep() => MoveStepTemplate(
        templateId: id,
        templateName: name,
        templateSteps: List.from(steps),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'steps': steps.map((s) => s.toJson()).toList(),
      };

  static MoveTemplate fromJson(Map<String, dynamic> json) => MoveTemplate(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        steps: (json['steps'] as List<dynamic>?)
                ?.map((s) => moveStepFromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
