import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_data.dart';

class FileIoService {
  static const _fileName = 'sf6_data.json';
  static const _backupName = 'sf6_data.json.bak';

  /// Get the local auto-save file path.
  Future<File> _getLocalFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Get the rolling backup file path (previous good save).
  Future<File> _getBackupFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_backupName');
  }

  /// Load data from local auto-save file.
  /// Returns empty AppData if file doesn't exist.
  ///
  /// On a corrupt main file, falls back to the `.bak` backup before giving up,
  /// so a mid-write crash or truncation can't wipe all notes silently.
  Future<AppData> loadLocal() async {
    final file = await _getLocalFile();
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        return AppData.fromJson(
          json.decode(content) as Map<String, dynamic>,
        );
      } catch (_) {
        // Main file corrupt/truncated — try the backup before starting fresh.
        try {
          final backup = await _getBackupFile();
          if (await backup.exists()) {
            final backupContent = await backup.readAsString();
            return AppData.fromJson(
              json.decode(backupContent) as Map<String, dynamic>,
            );
          }
        } catch (_) {
          // Both unreadable — fall through to empty.
        }
      }
    }
    return AppData.empty();
  }

  /// Save data to local auto-save file, keeping the previous good version as
  /// `.bak` so a crash mid-write never destroys the last-known-good state.
  Future<void> saveLocal(AppData data) async {
    final file = await _getLocalFile();
    final payload =
        const JsonEncoder.withIndent('  ').convert(data.toJson());

    // Rotate the current file into the backup slot before overwriting, so the
    // previous successful save survives even if this write fails halfway.
    try {
      if (await file.exists()) {
        final prev = await file.readAsString();
        final backup = await _getBackupFile();
        await backup.writeAsString(prev);
      }
    } catch (_) {
      // Couldn't rotate backup — proceed with the save anyway; better to have
      // the latest data than to skip writing.
    }

    await file.writeAsString(payload);
  }

  /// Let user pick a file and import data from it.
  /// Returns the imported AppData, or null if cancelled or unreadable.
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
