import 'character.dart';
import '../services/pdf_export_service.dart';

/// Top-level data container for the entire app.
class AppData {
  AppData({List<Character>? characters, this.pdfExportMode = PdfNotationMode.direction}) : characters = characters ?? [];

  List<Character> characters;
  PdfNotationMode pdfExportMode;

  static const int currentVersion = 1;

  Map<String, dynamic> toJson() => {
        'version': currentVersion,
        'pdfExportMode': pdfExportMode.index,
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
      characters: (json['characters'] as List<dynamic>?)
              ?.map((c) => Character.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  static AppData empty() => AppData();
}
