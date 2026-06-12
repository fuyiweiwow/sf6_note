import 'entry.dart';
import 'move_template.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// A fighting game character with entries and reusable move templates.
class Character {
  Character({
    String? id,
    required this.name,
    List<Entry>? entries,
    List<MoveTemplate>? templates,
  })  : id = id ?? _uuid.v4(),
        entries = entries ?? _createDefaultEntries(),
        templates = templates ?? [];

  final String id;
  String name;
  List<Entry> entries;
  List<MoveTemplate> templates;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'entries': entries.map((e) => e.toJson()).toList(),
        'templates': templates.map((t) => t.toJson()).toList(),
      };

  static Character fromJson(Map<String, dynamic> json) => Character(
        id: json['id'] as String,
        name: json['name'] as String,
        entries: (json['entries'] as List<dynamic>)
            .map((e) => Entry.fromJson(e as Map<String, dynamic>))
            .toList(),
        templates: (json['templates'] as List<dynamic>?)
                ?.map((t) =>
                    MoveTemplate.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
      );

  /// Create the 6 default entries for a new character.
  static List<Entry> _createDefaultEntries() => EntryType.defaults
      .map((type) => Entry(id: _uuid.v4(), type: type))
      .toList();
}
