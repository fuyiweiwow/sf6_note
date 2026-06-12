import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/character.dart';
import '../models/entry.dart';

class PdfExportService {
  Future<void> exportCharacter(Character character) async {
    final bytes = await _buildCharacterPdf(character);
    await _savePdf(bytes, '${character.name}_招式笔记.pdf');
  }

  Future<void> exportEntry(Character character, Entry entry) async {
    final bytes = await _buildEntryPdf(entry);
    await _savePdf(bytes, '${character.name}_${entry.displayName}.pdf');
  }

  Future<List<int>> _buildCharacterPdf(Character character) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Header(level: 0, text: character.name),
          pw.SizedBox(height: 8),
          ...character.entries.expand((entry) => _buildEntrySection(entry)),
        ],
      ),
    );

    return pdf.save();
  }

  Future<List<int>> _buildEntryPdf(Entry entry) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => _buildEntrySection(entry).toList(),
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

  List<pw.Widget> _buildEntrySection(Entry entry) {
    final widgets = <pw.Widget>[
      pw.SizedBox(height: 16),
      pw.Header(level: 1, text: entry.displayName),
    ];

    if (entry.combos.isEmpty) {
      widgets.add(
        pw.Text('(empty)', style: const pw.TextStyle(fontSize: 12)),
      );
    } else {
      for (int i = 0; i < entry.combos.length; i++) {
        final combo = entry.combos[i];
        final displayText =
            combo.name.isNotEmpty ? combo.name : combo.expandedPreview;

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
                    displayText,
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
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey600,
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
