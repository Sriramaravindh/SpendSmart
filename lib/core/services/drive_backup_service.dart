import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;
import '../../data/database/app_database.dart';
import 'auth_service.dart';

class BackupResult {
  final bool success;
  final String message;
  final DateTime? backupTime;
  BackupResult({required this.success, required this.message, this.backupTime});
}

class DriveBackupService {
  static const _backupFileName = 'spendsmart_backup.json';
  static const _backupMimeType = 'application/json';

  // FK parents must precede children (insert order). loan_rate_changes
  // references loans, so it comes after loans/loan_payments. currency_rates
  // has no FK so its position is free.
  static const _tables = [
    'categories',
    'payment_methods',
    'expenses',
    'budgets',
    'loans',
    'loan_payments',
    'loan_rate_changes',
    'recurring_expenses',
    'savings_goals',
    'tags',
    'currency_rates',
  ];

  static Future<BackupResult> backupToGoogleDrive() async {
    http.Client? client;
    try {
      client = await AuthService.getAuthClient();
      if (client == null) {
        return BackupResult(success: false, message: 'Not signed in. Please sign in first.');
      }

      final driveApi = drive.DriveApi(client);
      final db = await AppDatabase.database;

      final backupData = <String, dynamic>{
        'appName': 'SpendSmart',
        'dbVersion': 8,
        'backupTime': DateTime.now().toIso8601String(),
        'tables': {},
      };

      for (final table in _tables) {
        final rows = await db.query(table);
        backupData['tables'][table] = rows;
      }

      final jsonString = jsonEncode(backupData);
      final bytes = utf8.encode(jsonString);
      final media = drive.Media(Stream.value(bytes), bytes.length);

      final existingFileId = await _findBackupFileId(driveApi);

      if (existingFileId != null) {
        await driveApi.files.update(
          drive.File()..name = _backupFileName,
          existingFileId,
          uploadMedia: media,
        );
      } else {
        final fileMetadata = drive.File()
          ..name = _backupFileName
          ..mimeType = _backupMimeType
          ..parents = ['appDataFolder'];

        await driveApi.files.create(
          fileMetadata,
          uploadMedia: media,
        );
      }

      final backupTime = DateTime.now();
      return BackupResult(
        success: true,
        message: 'Backup completed successfully!',
        backupTime: backupTime,
      );
    } catch (e) {
      debugPrint('Backup error: $e');
      return BackupResult(success: false, message: 'Backup failed: ${e.toString()}');
    } finally {
      client?.close();
    }
  }

  static Future<BackupResult> restoreFromGoogleDrive() async {
    http.Client? client;
    try {
      client = await AuthService.getAuthClient();
      if (client == null) {
        return BackupResult(success: false, message: 'Not signed in. Please sign in first.');
      }

      final driveApi = drive.DriveApi(client);
      final fileId = await _findBackupFileId(driveApi);

      if (fileId == null) {
        return BackupResult(success: false, message: 'No backup found on Google Drive.');
      }

      final response = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final dataBytes = <int>[];
      await for (final chunk in response.stream) {
        dataBytes.addAll(chunk);
      }

      final jsonString = utf8.decode(dataBytes);
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

      if (backupData['appName'] != 'SpendSmart') {
        return BackupResult(success: false, message: 'Invalid backup file.');
      }

      // Schema is additive via migrations, so a mismatched version is not fatal.
      if (backupData['dbVersion'] != 8) {
        debugPrint('Restore warning: backup dbVersion ${backupData['dbVersion']} != expected 8');
      }

      final tables = backupData['tables'] as Map<String, dynamic>;

      // Validate the backup BEFORE deleting anything, to prevent data loss from
      // an incomplete backup. Every expected table must be present.
      final missing = _tables.where((t) => !tables.containsKey(t)).toList();
      if (missing.isNotEmpty) {
        return BackupResult(
          success: false,
          message: 'Backup is incomplete (missing: ${missing.join(', ')}). Restore aborted to prevent data loss.',
        );
      }

      final db = await AppDatabase.database;

      await db.transaction((txn) async {
        // Delete in reverse order to respect foreign keys
        for (final table in _tables.reversed) {
          await txn.delete(table);
        }

        for (final table in _tables) {
          final rows = tables[table] as List<dynamic>?;
          if (rows == null) continue;
          for (final row in rows) {
            final map = Map<String, dynamic>.from(row as Map);
            await txn.insert(table, map);
          }
        }
      });

      return BackupResult(
        success: true,
        message: 'Data restored successfully! Reloading...',
        backupTime: DateTime.tryParse(backupData['backupTime'] ?? ''),
      );
    } catch (e) {
      debugPrint('Restore error: $e');
      return BackupResult(success: false, message: 'Restore failed: ${e.toString()}');
    } finally {
      client?.close();
    }
  }

  static Future<DateTime?> getLastBackupTime() async {
    http.Client? client;
    try {
      client = await AuthService.getAuthClient();
      if (client == null) return null;

      final driveApi = drive.DriveApi(client);
      final fileId = await _findBackupFileId(driveApi);

      if (fileId == null) {
        return null;
      }

      final file = await driveApi.files.get(
        fileId,
        $fields: 'modifiedTime',
      ) as drive.File;

      return file.modifiedTime;
    } catch (e) {
      debugPrint('Get last backup time error: $e');
      return null;
    } finally {
      client?.close();
    }
  }

  static Future<String?> _findBackupFileId(drive.DriveApi driveApi) async {
    try {
      // Defensively escape single quotes for the Drive q filter.
      final safeName = _backupFileName.replaceAll("'", "\\'");
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$safeName'",
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id;
      }
    } catch (e) {
      debugPrint('Find backup file error: $e');
    }
    return null;
  }
}
