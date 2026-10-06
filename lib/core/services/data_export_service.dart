import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/database/app_database.dart';

class ExportResult {
  final bool success;
  final String message;
  ExportResult({required this.success, required this.message});
}

/// CSV + full JSON export/import, independent of DriveBackupService but reusing
/// the same table set and completeness-validation pattern on import.
///
/// Static methods, defensively coded (try/catch + debugPrint). Sharing uses
/// share_plus (XFile); JSON import uses file_picker.
class DataExportService {
  DataExportService._();

  // Same set + FK-safe order as DriveBackupService._tables. Kept as a private
  // copy here so this service is self-contained (DriveBackupService is not
  // edited). Keep in sync if tables are added.
  static const List<String> _tables = [
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

  static const int _dbVersion = 8;

  // --- CSV export of transactions ---

  static Future<ExportResult> exportTransactionsCsv() async {
    try {
      final db = await AppDatabase.database;

      final categories = await db.query('categories');
      final catName = {
        for (final c in categories) c['id'] as int?: (c['name'] as String?) ?? ''
      };
      final paymentMethods = await db.query('payment_methods');
      final pmName = {
        for (final p in paymentMethods)
          p['id'] as int?: (p['name'] as String?) ?? ''
      };

      final expenses = await db.query('expenses', orderBy: 'date DESC');

      final buffer = StringBuffer();
      buffer.writeln('Date,Type,Amount,Currency,Category,Payment Method,Note');
      final df = DateFormat('yyyy-MM-dd HH:mm');
      for (final e in expenses) {
        final dateMs = e['date'] as int?;
        final date = dateMs != null
            ? df.format(DateTime.fromMillisecondsSinceEpoch(dateMs))
            : '';
        final type = (e['type'] as String?) ?? 'EXPENSE';
        final amount = (e['amount'] as num?)?.toString() ?? '0';
        final currency = (e['currency'] as String?) ?? '';
        final category = catName[e['categoryId'] as int?] ?? '';
        final pm = pmName[e['paymentMethodId'] as int?] ?? '';
        final note = (e['note'] as String?) ?? '';
        buffer.writeln([
          date,
          type,
          amount,
          currency,
          category,
          pm,
          note,
        ].map(_csvCell).join(','));
      }

      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/spendsmart_transactions_$stamp.csv');
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'SpendSmart transactions',
      );
      return ExportResult(success: true, message: 'Transactions exported.');
    } catch (e) {
      debugPrint('DataExportService.exportTransactionsCsv error: $e');
      return ExportResult(success: false, message: 'CSV export failed: $e');
    }
  }

  static String _csvCell(String value) {
    final needsQuote =
        value.contains(',') || value.contains('"') || value.contains('\n');
    final escaped = value.replaceAll('"', '""');
    return needsQuote ? '"$escaped"' : escaped;
  }

  // --- Full JSON export ---

  static Future<ExportResult> exportJson() async {
    try {
      final db = await AppDatabase.database;
      final data = <String, dynamic>{
        'appName': 'SpendSmart',
        'dbVersion': _dbVersion,
        'backupTime': DateTime.now().toIso8601String(),
        'tables': <String, dynamic>{},
      };
      for (final table in _tables) {
        data['tables'][table] = await db.query(table);
      }

      final jsonString = jsonEncode(data);
      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/spendsmart_backup_$stamp.json');
      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'SpendSmart backup',
      );
      return ExportResult(success: true, message: 'Data exported to JSON.');
    } catch (e) {
      debugPrint('DataExportService.exportJson error: $e');
      return ExportResult(success: false, message: 'JSON export failed: $e');
    }
  }

  // --- Full JSON import (replaces all data) ---

  static Future<ExportResult> importJson() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        return ExportResult(success: false, message: 'Import cancelled.');
      }

      final f = picked.files.first;
      String jsonString;
      if (f.bytes != null) {
        jsonString = utf8.decode(f.bytes!);
      } else if (f.path != null) {
        jsonString = await File(f.path!).readAsString();
      } else {
        return ExportResult(success: false, message: 'Could not read file.');
      }

      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return ExportResult(success: false, message: 'Invalid backup file.');
      }

      if (decoded['appName'] != 'SpendSmart') {
        return ExportResult(success: false, message: 'Invalid backup file.');
      }
      if (decoded['dbVersion'] != _dbVersion) {
        debugPrint(
            'Import warning: dbVersion ${decoded['dbVersion']} != expected $_dbVersion');
      }

      final tables = decoded['tables'];
      if (tables is! Map<String, dynamic>) {
        return ExportResult(success: false, message: 'Invalid backup file.');
      }

      // Validate completeness BEFORE deleting anything (same guard as restore).
      final missing = _tables.where((t) => !tables.containsKey(t)).toList();
      if (missing.isNotEmpty) {
        return ExportResult(
          success: false,
          message:
              'Backup is incomplete (missing: ${missing.join(', ')}). Import aborted to prevent data loss.',
        );
      }

      final db = await AppDatabase.database;
      await db.transaction((txn) async {
        for (final table in _tables.reversed) {
          await txn.delete(table);
        }
        for (final table in _tables) {
          final rows = tables[table] as List<dynamic>?;
          if (rows == null) continue;
          for (final row in rows) {
            await txn.insert(table, Map<String, dynamic>.from(row as Map));
          }
        }
      });

      return ExportResult(
          success: true, message: 'Data imported successfully! Reloading...');
    } catch (e) {
      debugPrint('DataExportService.importJson error: $e');
      return ExportResult(success: false, message: 'Import failed: $e');
    }
  }
}
