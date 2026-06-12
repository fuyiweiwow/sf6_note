import 'package:uuid/uuid.dart';

import 'move_step.dart';

const _uuid = Uuid();

/// A single combo: a sequence of move steps + notes.
/// An Entry contains multiple Combos.
class Combo {
  Combo({
    String? id,
    this.name = '',
    List<MoveStep>? notation,
    this.notes = '',
  })  : id = id ?? _uuid.v4(),
        notation = notation ?? [];

  final String id;
  String name;
  List<MoveStep> notation;
  String notes;

  /// Short notation text for preview. Shows name if set, else notation.
  String get preview => name.isNotEmpty
      ? name
      : notation.map((s) => s.displayText).join(' > ');

  /// Expanded notation: template steps flattened.
  String get expandedPreview {
    final expanded = <MoveStep>[];
    for (final step in notation) {
      if (step is MoveStepTemplate) {
        expanded.addAll(step.templateSteps);
      } else {
        expanded.add(step);
      }
    }
    return expanded.map((s) => s.displayText).join(' > ');
  }

  /// Numpad notation preview (template steps flattened).
  String get numpadNotationPreview {
    final expanded = <MoveStep>[];
    for (final step in notation) {
      if (step is MoveStepTemplate) {
        expanded.addAll(step.templateSteps);
      } else {
        expanded.add(step);
      }
    }
    return numpadPreview(expanded);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'notation': notation.map((s) => s.toJson()).toList(),
        'notes': notes,
      };

  static Combo fromJson(Map<String, dynamic> json) => Combo(
        id: json['id'] as String? ?? _uuid.v4(),
        name: json['name'] as String? ?? '',
        notation: (json['notation'] as List<dynamic>?)
                ?.map((s) => moveStepFromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        notes: json['notes'] as String? ?? '',
      );
}
