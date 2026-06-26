import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/character.dart';
import '../models/entry.dart';
import '../models/move_step.dart';
import '../models/move_template.dart';

enum PdfNotationMode { direction, numpad, mixed }

class PdfExportService {
  /// Export a character's combos to PDF. [templates] should be the character's
  /// *effective* template list (globals + its own) so color/name lookups resolve
  /// for both global and per-character templates.
  Future<void> exportCharacter(
    Character character,
    PdfNotationMode mode, {
    List<MoveTemplate>? templates,
  }) async {
    final font = await _loadChineseFont();
    final bytes = await _buildCharacterPdf(
      character,
      font,
      mode,
      templates ?? character.templates,
    );
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
    List templates,
  ) async {
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: font));
    final theme = pw.ThemeData.withFont(base: font);

    // --- One MultiPage per entry; each starts on a new page and registers a
    //     reader-recognized outline bookmark (PDF navigation tree) via pw.Outline.
    for (final entry in character.entries) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          theme: theme,
          build: (context) => _buildEntrySection(entry, templates, font, mode),
        ),
      );
    }

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

  /// Render one entry's combos. [templates] is the effective template list
  /// (globals + the character's own) used for color/name lookups.
  List<pw.Widget> _buildEntrySection(
    Entry entry,
    List templates,
    pw.Font font,
    PdfNotationMode mode,
  ) {
    final widgets = <pw.Widget>[];

    // Entry name: prominent heading, wrapped in a reader outline bookmark
    // (level 0). The name is also a named anchor for cross-page linking.
    widgets.add(
      pw.Outline(
        name: 'entry-${entry.id}',
        title: entry.displayName,
        level: 0,
        child: pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            entry.displayName,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, font: font),
          ),
        ),
      ),
    );
    // Large gap between the entry title and its content.
    widgets.add(pw.SizedBox(height: 42));

    if (entry.combos.isEmpty) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8, top: 4),
          child: pw.Text('（暂无招式）', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600, font: font)),
        ),
      );
    } else {
      for (int i = 0; i < entry.combos.length; i++) {
        final combo = entry.combos[i];
        final comboBlock = <pw.Widget>[];

        // Combo name as a sub-outline (level 1) when set.
        if (combo.name.isNotEmpty) {
          comboBlock.add(
            pw.Outline(
              name: 'combo-${combo.id}',
              title: combo.name,
              level: 1,
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(left: 4, bottom: 10),
                child: pw.Text(
                  '${i + 1}. ${combo.name}',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, font: font),
                ),
              ),
            ),
          );
        }

        // Notation line(s). For mixed mode render the two notation forms as
        // separate RichText widgets with a comfortable gap between them.
        if (combo.notation.isNotEmpty) {
          if (mode == PdfNotationMode.mixed) {
            comboBlock.add(_notationLine(
              buildColoredNotation(combo.notation, templates, useNumpad: false),
              combo.name.isNotEmpty,
              combo.name.isEmpty ? '${i + 1}. ' : null,
              font,
            ));
            comboBlock.add(pw.SizedBox(height: 10));
            comboBlock.add(_notationLine(
              buildColoredNotation(combo.notation, templates, useNumpad: true),
              combo.name.isNotEmpty,
              null,
              font,
            ));
          } else {
            final colored = buildColoredNotation(
              combo.notation,
              templates,
              useNumpad: mode == PdfNotationMode.numpad,
            );
            comboBlock.add(_notationLine(
              colored,
              combo.name.isNotEmpty,
              combo.name.isEmpty ? '${i + 1}. ' : null,
              font,
            ));
          }
        }

        // Combo's own remark: larger font, with breathing room above it.
        if (combo.notes.isNotEmpty) {
          comboBlock.add(pw.SizedBox(height: 8));
          comboBlock.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 28),
              child: pw.Text(
                combo.notes,
                style: pw.TextStyle(fontSize: 13, color: PdfColors.grey700, font: font),
              ),
            ),
          );
        }

        // Stack this combo's pieces together, with generous spacing between
        // consecutive combos.
        widgets.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(top: i == 0 ? 0 : 18, bottom: 6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: comboBlock,
            ),
          ),
        );
      }
    }

    return widgets;
  }

  /// Build one colored notation line (with optional inline index prefix).
  pw.Widget _notationLine(
    ColoredText colored,
    bool hasName,
    String? indexPrefix,
    pw.Font font,
  ) {
    final children = <pw.InlineSpan>[
      if (indexPrefix != null)
        pw.TextSpan(
          text: indexPrefix,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
      ...colored.spans.map((s) => pw.TextSpan(
            text: s.text,
            style: pw.TextStyle(
              color: s.color == null ? PdfColors.black : PdfColor.fromInt(s.color!),
            ),
          )),
    ];
    return pw.Padding(
      padding: pw.EdgeInsets.only(left: hasName ? 16 : 8),
      child: pw.RichText(
        text: pw.TextSpan(
          children: children,
          style: pw.TextStyle(fontSize: 13, font: font),
        ),
      ),
    );
  }
}
