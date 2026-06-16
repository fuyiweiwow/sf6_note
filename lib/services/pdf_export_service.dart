import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/character.dart';
import '../models/entry.dart';
import '../models/move_step.dart';

enum PdfNotationMode { direction, numpad, mixed }

class PdfExportService {
  Future<void> exportCharacter(
    Character character,
    PdfNotationMode mode,
  ) async {
    final font = await _loadChineseFont();
    final bytes = await _buildCharacterPdf(character, font, mode);
    final suffix = switch (mode) {
      PdfNotationMode.direction => 'direction',
      PdfNotationMode.numpad => 'numpad',
      PdfNotationMode.mixed => 'mixed',
    };
    await _savePdf(bytes, '${character.name}_notes_$suffix.pdf');
  }

  Future<List<int>> _buildCharacterPdf(
    Character character,
    pw.Font font,
    PdfNotationMode mode,
  ) async {
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: font));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Header(level: 0, text: character.name),
          pw.SizedBox(height: 8),
          ...character.entries.expand(
            (entry) => _buildEntrySection(entry, font, mode),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> _savePdf(List<int> bytes, String fileName) async {
    final result = await FilePicker.platform.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
    );
    if (result != null) {
      File(result).writeAsBytesSync(bytes);
    }
  }

  Future<pw.Font> _loadChineseFont() async {
    const paths = [
      'C:/Windows/Fonts/msyh.ttf',
      'C:/Windows/Fonts/msyhbd.ttf',
      'C:/Windows/Fonts/simhei.ttf',
      'C:/Windows/Fonts/simsun.ttc',
    ];
    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        final data = file.readAsBytesSync();
        return pw.Font.ttf(ByteData.view(data.buffer));
      }
    }
    return pw.Font.helvetica();
  }

  /// Build notation string based on the selected mode.
  /// Delegates to shared grouping logic from move_step.dart.
  String _notationToString(List<MoveStep> steps, PdfNotationMode mode) {
    final slots = groupNotationSlots(steps);
    final useNumpad = mode == PdfNotationMode.numpad;
    final joined = slots.map((slot) => buildSlotText(slot, useNumpad)).join(' + ');

    if (mode == PdfNotationMode.mixed) {
      final dirStr = slots.map((slot) => buildSlotText(slot, false)).join(' + ');
      final numStr = slots.map((slot) => buildSlotText(slot, true)).join(' + ');
      return '$dirStr\n$numStr';
    }
    return joined;
  }

  List<pw.Widget> _buildEntrySection(
    Entry entry,
    pw.Font font,
    PdfNotationMode mode,
  ) {
    final widgets = <pw.Widget>[
      pw.SizedBox(height: 16),
      pw.Text(
        entry.displayName,
        style: pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
          font: font,
        ),
      ),
    ];

    if (entry.combos.isEmpty) {
      widgets.add(
        pw.Text('(empty)', style: const pw.TextStyle(fontSize: 12)),
      );
    } else {
      for (int i = 0; i < entry.combos.length; i++) {
        final combo = entry.combos[i];
        final flatSteps = <MoveStep>[];
        for (final step in combo.notation) {
          if (step is MoveStepTemplate) {
            flatSteps.addAll(step.templateSteps);
          } else {
            flatSteps.add(step);
          }
        }
        final notationText = _notationToString(flatSteps, mode);

        // Add + separator between combos
        if (i > 0) {
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 12, top: 4),
              child: pw.Text(
                '+',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.orange,
                ),
              ),
            ),
          );
        }

        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 12, top: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${i + 1}. ',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    notationText,
                    style: const pw.TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );

        if (combo.notes.isNotEmpty) {
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 28, top: 2),
              child: pw.Text(
                combo.notes,
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey600,
                  font: font,
                ),
              ),
            ),
          );
        }
      }
    }

    return widgets;
  }
}
