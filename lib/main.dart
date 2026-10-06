import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart';
import 'core/utils/currency_formatter.dart';
import 'core/services/notification_service.dart';
import 'core/services/gemini_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWebNoWebWorker;
  }
  await CurrencyFormatter.init();

  // Local notifications (due-date reminders). Best-effort; never fatal.
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('NotificationService.init failed: $e');
  }

  // Restore the persisted "share transaction context with AI" preference.
  try {
    final prefs = await SharedPreferences.getInstance();
    GeminiService.shareTransactionContext =
        prefs.getBool('ai_share_context') ?? false;
  } catch (e) {
    debugPrint('Load ai_share_context failed: $e');
  }

  runApp(const ProviderScope(child: App()));
}
