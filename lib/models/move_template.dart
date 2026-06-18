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
    this.notes = '',
    this.useNameInPdf = false,
    this.colorValue,
  })  : id = id ?? _uuid.v4(),
        steps = steps ?? [];

  final String id;
  String name;
  List<MoveStep> steps;
  /// Remark shown in PDF after the notation, inside the parentheses.
  String notes;
  /// When true, PDF export shows the template name instead of its steps.
  bool useNameInPdf;
  /// ARGB color int (e.g. 0xFFFF0000 = red). null = default black.
  int? colorValue;

  /// Short display text: name or step summary.
  String get displayText {
    if (name.isNotEmpty) return name;
    return steps.map((s) => s.displayText).join('');
  }

  /// One-line preview of the steps.
  String get stepsPreview => steps.map((s) => s.displayText).join(' ');

  /// Convert to a MoveStepTemplate for use in notation.
  /// Note: notes/useNameInPdf live on the template and are looked up by id
  /// at export time, so they are intentionally NOT copied into the step.
  MoveStepTemplate toMoveStep() => MoveStepTemplate(
        templateId: id,
        templateName: name,
        templateSteps: List.from(steps),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'steps': steps.map((s) => s.toJson()).toList(),
        'notes': notes,
        'useNameInPdf': useNameInPdf,
        if (colorValue != null) 'color': colorValue,
      };

  static MoveTemplate fromJson(Map<String, dynamic> json) => MoveTemplate(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        steps: (json['steps'] as List<dynamic>?)
                ?.map((s) => moveStepFromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        notes: json['notes'] as String? ?? '',
        useNameInPdf: json['useNameInPdf'] as bool? ?? false,
        colorValue: json['color'] as int?,
      );
}
