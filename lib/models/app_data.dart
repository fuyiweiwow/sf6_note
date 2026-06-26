import 'character.dart';
import 'move_template.dart';
import '../services/pdf_export_service.dart';

/// Top-level data container for the entire app.
class AppData {
  AppData({
    List<Character>? characters,
    List<MoveTemplate>? globalTemplates,
    this.pdfExportMode = PdfNotationMode.direction,
  })  : characters = characters ?? [],
        globalTemplates = globalTemplates ?? [];

  /// Characters each carry their own (per-character) templates.
  List<Character> characters;

  /// Templates visible to ALL characters. Stored at the app root so a single
  /// edit applies everywhere (e.g. common motions like 波动拳/旋风腿).
  List<MoveTemplate> globalTemplates;

  PdfNotationMode pdfExportMode;

  static const int currentVersion = 1;

  Map<String, dynamic> toJson() => {
        'version': currentVersion,
        'pdfExportMode': pdfExportMode.index,
        'globalTemplates': globalTemplates.map((t) => t.toJson()).toList(),
        'characters': characters.map((c) => c.toJson()).toList(),
      };

  static AppData fromJson(Map<String, dynamic> json) {
    final modeIndex = json['pdfExportMode'] as int?;
    final PdfNotationMode mode;
    if (modeIndex != null && modeIndex >= 0 && modeIndex < PdfNotationMode.values.length) {
      mode = PdfNotationMode.values[modeIndex];
    } else {
      mode = PdfNotationMode.direction;
    }
    return AppData(
      pdfExportMode: mode,
      globalTemplates: (json['globalTemplates'] as List<dynamic>?)
              ?.map((t) => MoveTemplate.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      characters: (json['characters'] as List<dynamic>?)
              ?.map((c) => Character.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  static AppData empty() => AppData();
}
