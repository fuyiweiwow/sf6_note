import 'combo.dart';
import 'move_step.dart';

/// Built-in and custom entry types for organizing combos.
enum EntryType {
  lightStarter('轻攻击起手连段'),
  mediumStarter('中攻击起手连段'),
  heavyStarter('重攻击起手连段'),
  okizeme('压起身连段'),
  punishCounter('确反连段'),
  wallCombo('迸墙连段'),
  custom('自定义');

  const EntryType(this.label);
  final String label;

  String get jsonKey => name;

  static EntryType fromJson(String key) => EntryType.values.firstWhere(
        (e) => e.jsonKey == key,
        orElse: () => EntryType.custom,
      );

  static List<EntryType> get defaults => [
        EntryType.lightStarter,
        EntryType.mediumStarter,
        EntryType.heavyStarter,
        EntryType.okizeme,
        EntryType.punishCounter,
        EntryType.wallCombo,
      ];
}

/// An entry holds a list of combos (e.g. all light-starter combos).
class Entry {
  Entry({
    required this.id,
    required this.type,
    this.customName = '',
    List<Combo>? combos,
  }) : combos = combos ?? [];

  final String id;
  final EntryType type;
  String customName;
  List<Combo> combos;

  String get displayName =>
      type == EntryType.custom ? customName : type.label;

  int get comboCount => combos.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.jsonKey,
        'customName': customName,
        'combos': combos.map((c) => c.toJson()).toList(),
      };

  /// Backward compatible: handles old format (notation + notes) and new (combos).
  static Entry fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final type = EntryType.fromJson(json['type'] as String);
    final customName = json['customName'] as String? ?? '';

    // New format: has 'combos' array
    if (json.containsKey('combos')) {
      final combos = (json['combos'] as List<dynamic>)
          .map((c) => Combo.fromJson(c as Map<String, dynamic>))
          .toList();
      return Entry(
        id: id,
        type: type,
        customName: customName,
        combos: combos,
      );
    }

    // Old format: single notation + notes → migrate to one combo
    final notation = (json['notation'] as List<dynamic>?)
        ?.map((s) => moveStepFromJson(s as Map<String, dynamic>))
        .toList();
    final notes = json['notes'] as String? ?? '';

    return Entry(
      id: id,
      type: type,
      customName: customName,
      combos: [
        if (notation != null && notation.isNotEmpty)
          Combo(notation: notation, notes: notes)
      ],
    );
  }
}
