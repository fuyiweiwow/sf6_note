import 'character.dart';

/// Top-level data container for the entire app.
class AppData {
  AppData({List<Character>? characters}) : characters = characters ?? [];

  List<Character> characters;

  static const int currentVersion = 1;

  Map<String, dynamic> toJson() => {
        'version': currentVersion,
        'characters': characters.map((c) => c.toJson()).toList(),
      };

  static AppData fromJson(Map<String, dynamic> json) => AppData(
        characters: (json['characters'] as List<dynamic>?)
                ?.map((c) => Character.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
      );

  static AppData empty() => AppData();
}
