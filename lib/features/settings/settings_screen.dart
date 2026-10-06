import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/services/drive_backup_service.dart';
import '../../core/services/app_lock_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/data_export_service.dart';
import '../../core/services/gemini_service.dart';
import '../../providers/providers.dart';
import '../../app.dart' show NotificationReminderPrefs;
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isBackingUp = false;
  bool _isRestoring = false;
  DateTime? _lastBackupTime;

  // Security / notifications / AI toggles.
  bool _appLockEnabled = false;
  bool _remindersEnabled = false;
  int _reminderLeadDays = 1;
  bool _shareAiContext = false;
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadLastBackupTime();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final appLock = await AppLockService.isEnabled();
    final remindersOn = await NotificationReminderPrefs.isEnabled();
    final lead = await NotificationReminderPrefs.leadDays();
    final prefs = await SharedPreferences.getInstance();
    final shareAi = prefs.getBool('ai_share_context') ?? false;
    if (!mounted) return;
    setState(() {
      _appLockEnabled = appLock;
      _remindersEnabled = remindersOn;
      _reminderLeadDays = lead;
      _shareAiContext = shareAi;
    });
  }

  Future<void> _rescheduleReminders() async {
    final recurrings = await ref.read(recurringRepoProvider).getAll();
    final loans = await ref.read(loanRepoProvider).getAll();
    await NotificationService.rescheduleAll(
      recurrings,
      loans,
      _reminderLeadDays,
      currencySymbol: CurrencyFormatter.symbol,
    );
  }

  Future<void> _loadLastBackupTime() async {
    final user = ref.read(authUserProvider);
    if (user != null) {
      final time = await DriveBackupService.getLastBackupTime();
      if (mounted) setState(() => _lastBackupTime = time);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance section
          const _SectionHeader(title: 'Appearance'),
          Card(
            color: cs.surfaceContainerLow,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.palette_outlined, color: cs.primary),
                  title: const Text('Theme'),
                  subtitle: Text(_themeLabel(themeMode)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showThemeDialog(context, ref, themeMode),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.currency_exchange, color: cs.primary),
                  title: const Text('Currency'),
                  subtitle: Text('${CurrencyFormatter.symbol} — ${CurrencyFormatter.availableCurrencies[CurrencyFormatter.symbol] ?? ""}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showCurrencyDialog(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Data management section
          const _SectionHeader(title: 'Data'),
          Card(
            color: cs.surfaceContainerLow,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.category_outlined, color: cs.primary),
                  title: const Text('Categories'),
                  subtitle: const Text('Manage expense categories'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/categories'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.payment_outlined, color: cs.primary),
                  title: const Text('Payment Methods'),
                  subtitle: const Text('Manage payment methods'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/payment-methods'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.label_outlined, color: cs.primary),
                  title: const Text('Expense Groups'),
                  subtitle: const Text('Manage tags and expense groups'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/tags'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.account_balance_outlined, color: cs.primary),
                  title: const Text('Loans & EMI'),
                  subtitle: const Text('Manage loans and EMI tracker'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/loans'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.currency_exchange_outlined, color: cs.primary),
                  title: const Text('Currency Rates'),
                  subtitle: const Text('Manage conversion rates'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/currency-rates'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.repeat_outlined, color: cs.primary),
                  title: const Text('Recurring Expenses'),
                  subtitle: const Text('Manage recurring payments'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/recurring'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.savings_outlined, color: cs.primary),
                  title: const Text('Budgets'),
                  subtitle: const Text('Set monthly budgets'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/budgets'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Account & Backup section
          const _SectionHeader(title: 'Account'),
          _buildGoogleAccountCard(context, ref, cs),
          const SizedBox(height: 20),

          // Backup & Restore (only when signed in)
          if (ref.watch(authUserProvider) != null) ...[
            const _SectionHeader(title: 'Backup & Restore'),
            _buildBackupRestoreCard(context, ref, cs),
            const SizedBox(height: 20),
          ],

          // Security & reminders
          const _SectionHeader(title: 'Security & Reminders'),
          _buildSecurityCard(context, cs),
          const SizedBox(height: 20),

          // Export / import
          const _SectionHeader(title: 'Export & Import'),
          _buildExportImportCard(context, cs),
          const SizedBox(height: 20),

          // AI
          const _SectionHeader(title: 'AI Assistant'),
          Card(
            color: cs.surfaceContainerLow,
            child: SwitchListTile(
              secondary: Icon(Icons.auto_awesome_outlined, color: cs.primary),
              title: const Text('Share transaction context with AI'),
              subtitle: const Text(
                'Lets the AI assistant see recent transactions for better answers',
                style: TextStyle(fontSize: 12),
              ),
              value: _shareAiContext,
              onChanged: (v) async {
                setState(() => _shareAiContext = v);
                GeminiService.shareTransactionContext = v;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('ai_share_context', v);
              },
            ),
          ),
          const SizedBox(height: 20),

          // About
          const _SectionHeader(title: 'About'),
          Card(
            color: cs.surfaceContainerLow,
            child: ListTile(
              leading: Icon(Icons.info_outlined, color: cs.primary),
              title: const Text('SpendSmart'),
              subtitle: const Text('Version 1.0.0'),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildGoogleAccountCard(BuildContext context, WidgetRef ref, ColorScheme cs) {
    final user = ref.watch(authUserProvider);

    if (user != null) {
      return Card(
        color: cs.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ListTile(
            leading: user.photoUrl != null
                ? CircleAvatar(backgroundImage: NetworkImage(user.photoUrl!))
                : CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      (user.displayName ?? user.email).substring(0, 1).toUpperCase(),
                      style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
                    ),
                  ),
            title: Text(user.displayName ?? 'Google Account', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(user.email, style: const TextStyle(fontSize: 12)),
            trailing: TextButton.icon(
              onPressed: () async {
                await ref.read(authUserProvider.notifier).signOut();
                if (mounted) setState(() => _lastBackupTime = null);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Signed out of Google account')),
                  );
                }
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign Out'),
            ),
          ),
        ),
      );
    }

    return Card(
      color: cs.surfaceContainerLow,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(Icons.account_circle, color: cs.primary),
        ),
        title: const Text('Sign in with Google', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Connect your Google account'),
        trailing: FilledButton.icon(
          onPressed: () async {
            final result = await ref.read(authUserProvider.notifier).signIn();
            if (context.mounted) {
              if (result.isSuccess) {
                await _loadLastBackupTime();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Successfully signed in with Google!')),
                );
              } else {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    icon: Icon(Icons.error_outline, color: Theme.of(ctx).colorScheme.error, size: 36),
                    title: const Text('Sign-In Failed'),
                    content: Text(result.error ?? 'Unknown error occurred.'),
                    actions: [
                      FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                    ],
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.login, size: 18),
          label: const Text('Sign In'),
        ),
      ),
    );
  }

  Widget _buildBackupRestoreCard(BuildContext context, WidgetRef ref, ColorScheme cs) {
    final lastBackupText = _lastBackupTime != null
        ? 'Last backup: ${DateFormat('dd MMM yyyy, hh:mm a').format(_lastBackupTime!.toLocal())}'
        : 'No backup yet';

    return Card(
      color: cs.surfaceContainerLow,
      child: Column(
        children: [
          ListTile(
            leading: _isBackingUp
                ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
                : Icon(Icons.cloud_upload_outlined, color: cs.primary),
            title: const Text('Backup to Google Drive'),
            subtitle: Text(lastBackupText, style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            enabled: !_isBackingUp && !_isRestoring,
            onTap: () async {
              setState(() => _isBackingUp = true);
              final result = await DriveBackupService.backupToGoogleDrive();
              if (mounted) {
                setState(() {
                  _isBackingUp = false;
                  if (result.backupTime != null) _lastBackupTime = result.backupTime;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.message),
                    backgroundColor: result.success ? Colors.green : cs.error,
                  ),
                );
              }
            },
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: _isRestoring
                ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
                : Icon(Icons.cloud_download_outlined, color: cs.primary),
            title: const Text('Restore from Google Drive'),
            subtitle: const Text('Replace all current data with backup', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            enabled: !_isBackingUp && !_isRestoring,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  icon: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 40),
                  title: const Text('Restore Backup?'),
                  content: const Text(
                    'This will replace ALL your current data (expenses, categories, budgets, loans, etc.) with the data from your Google Drive backup.\n\nThis action cannot be undone.',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Restore'),
                    ),
                  ],
                ),
              );

              if (confirmed != true || !mounted) return;

              setState(() => _isRestoring = true);
              final result = await DriveBackupService.restoreFromGoogleDrive();
              if (mounted) {
                setState(() => _isRestoring = false);
                if (result.success) {
                  refreshAll(ref);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.message),
                    backgroundColor: result.success ? Colors.green : cs.error,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard(BuildContext context, ColorScheme cs) {
    return Card(
      color: cs.surfaceContainerLow,
      child: Column(
        children: [
          SwitchListTile(
            secondary: Icon(Icons.fingerprint, color: cs.primary),
            title: const Text('App Lock (biometric/PIN)'),
            subtitle: const Text('Require authentication to open the app',
                style: TextStyle(fontSize: 12)),
            value: _appLockEnabled,
            onChanged: (v) async {
              await AppLockService.setEnabled(v);
              if (mounted) setState(() => _appLockEnabled = v);
            },
          ),
          const Divider(height: 1, indent: 56),
          SwitchListTile(
            secondary: Icon(Icons.notifications_active_outlined, color: cs.primary),
            title: const Text('Due-date reminders'),
            subtitle: const Text('Notify before recurring payments and EMIs',
                style: TextStyle(fontSize: 12)),
            value: _remindersEnabled,
            onChanged: (v) async {
              setState(() => _remindersEnabled = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(NotificationReminderPrefs.kEnabled, v);
              if (v) {
                await _rescheduleReminders();
              } else {
                await NotificationService.cancelAll();
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(v ? 'Reminders enabled' : 'Reminders disabled')),
                );
              }
            },
          ),
          if (_remindersEnabled) ...[
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: Icon(Icons.schedule_outlined, color: cs.primary),
              title: const Text('Remind me ahead by'),
              trailing: DropdownButton<int>(
                value: _reminderLeadDays,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 day')),
                  DropdownMenuItem(value: 2, child: Text('2 days')),
                  DropdownMenuItem(value: 3, child: Text('3 days')),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => _reminderLeadDays = v);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt(NotificationReminderPrefs.kLeadDays, v);
                  await _rescheduleReminders();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExportImportCard(BuildContext context, ColorScheme cs) {
    return Card(
      color: cs.surfaceContainerLow,
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.table_view_outlined, color: cs.primary),
            title: const Text('Export transactions to CSV'),
            subtitle: const Text('Share a spreadsheet of all transactions',
                style: TextStyle(fontSize: 12)),
            enabled: !_isExporting && !_isImporting,
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              setState(() => _isExporting = true);
              final result = await DataExportService.exportTransactionsCsv();
              if (mounted) {
                setState(() => _isExporting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.message),
                    backgroundColor: result.success ? Colors.green : cs.error,
                  ),
                );
              }
            },
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: Icon(Icons.file_upload_outlined, color: cs.primary),
            title: const Text('Export all data (JSON)'),
            subtitle: const Text('Full backup you can save or share',
                style: TextStyle(fontSize: 12)),
            enabled: !_isExporting && !_isImporting,
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              setState(() => _isExporting = true);
              final result = await DataExportService.exportJson();
              if (mounted) {
                setState(() => _isExporting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.message),
                    backgroundColor: result.success ? Colors.green : cs.error,
                  ),
                );
              }
            },
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: _isImporting
                ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
                : Icon(Icons.file_download_outlined, color: cs.primary),
            title: const Text('Import data (JSON)'),
            subtitle: const Text('Replace all current data with a JSON backup',
                style: TextStyle(fontSize: 12)),
            enabled: !_isExporting && !_isImporting,
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  icon: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 40),
                  title: const Text('Import Backup?'),
                  content: const Text(
                    'This will replace ALL your current data with the contents of the selected JSON file.\n\nThis action cannot be undone.',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Import'),
                    ),
                  ],
                ),
              );
              if (confirmed != true || !mounted) return;
              setState(() => _isImporting = true);
              final result = await DataExportService.importJson();
              if (mounted) {
                setState(() => _isImporting = false);
                if (result.success) refreshAll(ref);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.message),
                    backgroundColor: result.success ? Colors.green : cs.error,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return 'Light';
      case ThemeMode.dark: return 'Dark';
      case ThemeMode.system: return 'System default';
    }
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref, ThemeMode current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((mode) => RadioListTile<ThemeMode>(
            title: Text(_themeLabel(mode)),
            value: mode,
            groupValue: current,
            onChanged: (v) {
              if (v != null) ref.read(themeModeProvider.notifier).setMode(v);
              Navigator.pop(ctx);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showCurrencyDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Currency'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: CurrencyFormatter.availableCurrencies.entries.map((e) => RadioListTile<String>(
              title: Text('${e.key}  ${e.value}'),
              value: e.key,
              groupValue: CurrencyFormatter.symbol,
              onChanged: (v) async {
                if (v != null) {
                  await CurrencyFormatter.setCurrency(v);
                  refreshAll(ref);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
            )).toList(),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w400,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
