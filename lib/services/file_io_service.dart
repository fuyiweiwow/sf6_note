import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_data.dart';

class FileIoService {
  static const _fileName = 'sf6_data.json';

  /// Get the local auto-save file path.
  Future<File> _getLocalFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Load data from local auto-save file.
  /// Returns empty AppData if file doesn't exist.
  Future<AppData> loadLocal() async {
    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        return AppData.fromJson(
          json.decode(content) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Corrupt file or permission issue - start fresh
    }
    return AppData.empty();
  }

  /// Save data to local auto-save file.
  Future<void> saveLocal(AppData data) async {
    final file = await _getLocalFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data.toJson()),
    );
  }

  /// Let user pick a file and import data from it.
  /// Returns the imported AppData, or null if cancelled.
  Future<AppData?> importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return null;

      final path = result.files.first.path;
      if (path == null) return null;

      final content = await File(path).readAsString();
      return AppData.fromJson(
        json.decode(content) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Export data to a user-chosen file path.
  /// Returns true on success.
  Future<bool> exportToFile(AppData data) async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '导出 SF6 招式数据',
        fileName: 'sf6_data.json',
        allowedExtensions: ['json'],
      );
      if (result == null) return false;

      final file = File(result);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data.toJson()),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
