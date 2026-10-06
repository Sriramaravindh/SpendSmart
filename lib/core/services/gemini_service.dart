import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' hide Category;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../data/models.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/payment_method_repository.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/currency_formatter.dart';

class GeminiService {
  static final _apiKey = _k.join();
  static const _k = [
    'AQ.Ab8RN6JMeQ',
    '1D3eIiucQLa91',
    'kwzFIKe6S5qNU',
    '7B1QlIvFVBw_3g',
  ];

  static const _modelFallbacks = [
    'gemini-3.5-flash-lite',
    'gemini-3.8-flash',
    'gemini-flash-latest',
  ];

  static final _expenseRepo = ExpenseRepository();
  static final _categoryRepo = CategoryRepository();
  static final _paymentMethodRepo = PaymentMethodRepository();

  static List<Category> _cachedCategories = [];
  static List<PaymentMethod> _cachedPaymentMethods = [];
  static Future<void>? _loadingFuture;

  // When false, PII-sensitive free text (transaction notes / recent
  // transaction list) is omitted from the AI context. Other code can set this
  // from a saved preference to grant consent.
  static bool shareTransactionContext = false;

  static GenerativeModel _createModel(String modelName, {double temp = 0.7}) {
    return GenerativeModel(
      model: modelName,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: temp,
        maxOutputTokens: 32768,
      ),
    );
  }

  static Future<void> _loadCaches() async {
    if (_cachedCategories.isNotEmpty && _cachedPaymentMethods.isNotEmpty) return;
    // Memoize the in-flight load so concurrent callers share one load instead
    // of racing (which could leave caches half-populated).
    if (_loadingFuture != null) {
      await _loadingFuture;
      return;
    }
    _loadingFuture = () async {
      if (_cachedCategories.isEmpty) {
        _cachedCategories = await _categoryRepo.getAll();
      }
      if (_cachedPaymentMethods.isEmpty) {
        _cachedPaymentMethods = await _paymentMethodRepo.getAll();
      }
    }();
    try {
      await _loadingFuture;
    } finally {
      _loadingFuture = null;
    }
  }

  static void refreshCaches() {
    _cachedCategories = [];
    _cachedPaymentMethods = [];
    _loadingFuture = null;
  }

  static String? getCategoryName(int? id) {
    if (id == null) return null;
    try {
      return _cachedCategories.firstWhere((c) => c.id == id).name;
    } catch (_) {
      return null;
    }
  }

  static String? getPaymentMethodName(int? id) {
    if (id == null) return null;
    try {
      return _cachedPaymentMethods.firstWhere((p) => p.id == id).name;
    } catch (_) {
      return null;
    }
  }

  static Future<String> _getContextPrompt() async {
    await _loadCaches();
    final categories = _cachedCategories;
    final paymentMethods = _cachedPaymentMethods;
    final now = DateTime.now();
    final monthStart = AppDateUtils.monthStart();
    final monthEnd = AppDateUtils.monthEnd();
    final monthExpenses = await _expenseRepo.getByDateRange(monthStart, monthEnd);

    final totalExpense = monthExpenses
        .where((e) => e.type == 'EXPENSE')
        .fold(0.0, (sum, e) => sum + e.amount);
    final totalIncome = monthExpenses
        .where((e) => e.type == 'INCOME')
        .fold(0.0, (sum, e) => sum + e.amount);

    final expenseCategories = categories.where((c) => c.type == 'EXPENSE' || c.type == 'BOTH').toList();
    final incomeCategories = categories.where((c) => c.type == 'INCOME' || c.type == 'BOTH').toList();

    final categoryBySpend = <String, double>{};
    for (final e in monthExpenses.where((e) => e.type == 'EXPENSE')) {
      final catName = getCategoryName(e.categoryId) ?? 'Unknown';
      categoryBySpend[catName] = (categoryBySpend[catName] ?? 0) + e.amount;
    }
    final topCategories = categoryBySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // PII gate: the per-transaction list includes free-text notes. Only build
    // and include it when the user has consented via shareTransactionContext.
    final recentTransactionsBlock = shareTransactionContext
        ? '''

RECENT TRANSACTIONS (these are CONFIRMED and SAVED in the database):
${monthExpenses.take(30).map((e) {
            final cat = getCategoryName(e.categoryId) ?? 'Unknown';
            final pm = getPaymentMethodName(e.paymentMethodId) ?? '';
            final sym = CurrencyFormatter.symbolFor(e.currency);
            return '- ${e.type == "INCOME" ? "Income" : "Expense"}: $sym${e.amount} ${e.currency} | $cat | ${e.note ?? "no note"} | $pm | ${e.date.day}/${e.date.month}/${e.date.year}';
          }).join('\n')}'''
        : '';

    final defaultCurrency = CurrencyFormatter.defaultCurrencyCode;
    final defaultSym = CurrencyFormatter.symbolFor(defaultCurrency);
    final yesterday = now.subtract(const Duration(days: 1));
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    return '''
You are SpendSmart AI Assistant — a smart, concise, and friendly assistant inside the SpendSmart expense tracking app. Keep responses short and helpful.

Today: ${now.day}/${now.month}/${now.year} (${['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][now.weekday - 1]})
User's default currency: $defaultCurrency ($defaultSym)

EXPENSE CATEGORIES (id: name):
${expenseCategories.map((c) => '${c.id}: ${c.name}').join(', ')}

INCOME CATEGORIES (id: name):
${incomeCategories.map((c) => '${c.id}: ${c.name}').join(', ')}

PAYMENT METHODS (id: name):
${paymentMethods.map((p) => '${p.id}: ${p.name} [${p.type}]').join(', ')}

THIS MONTH SUMMARY:
Income: $defaultSym${totalIncome.toStringAsFixed(0)} | Expense: $defaultSym${totalExpense.toStringAsFixed(0)} | Balance: $defaultSym${(totalIncome - totalExpense).toStringAsFixed(0)}
${topCategories.isNotEmpty ? 'Top spending: ${topCategories.take(5).map((e) => '${e.key} $defaultSym${e.value.toStringAsFixed(0)}').join(', ')}' : ''}
$recentTransactionsBlock

ADDING EXPENSES/INCOME:
When user wants to add an expense or income, include a \`\`\`action JSON block. For EACH separate item, include a SEPARATE \`\`\`action block.

Format:
\`\`\`action
{"type":"add_expense","amount":500,"categoryId":1,"paymentMethodId":1,"note":"Dinner","expenseType":"EXPENSE","currency":"$defaultCurrency","date":"$todayStr"}
\`\`\`

Multiple items — ALWAYS separate blocks (movie 500, biryani 300):
\`\`\`action
{"type":"add_expense","amount":500,"categoryId":3,"paymentMethodId":1,"note":"Movie","expenseType":"EXPENSE","currency":"$defaultCurrency","date":"$todayStr"}
\`\`\`
\`\`\`action
{"type":"add_expense","amount":300,"categoryId":1,"paymentMethodId":1,"note":"Biryani","expenseType":"EXPENSE","currency":"$defaultCurrency","date":"$todayStr"}
\`\`\`

RULES:
1. MULTIPLE ITEMS: When user mentions multiple items in ANY format ("movie 500 biryani 300", "coffee and sandwich 250 each", "lunch 400 uber 200"), ALWAYS create SEPARATE action blocks. Never combine. Never ask to clarify — parse and split intelligently. Even without commas or "and", detect item-amount pairs.
2. CONFIRM FLOW: When you create action blocks, say "Here's what I'll add — tap Confirm to save". The user sees a Confirm button below each item. Once they tap it, the expense IS SAVED to the database.
3. ALREADY SAVED: The RECENT TRANSACTIONS above are real, confirmed, saved data. If a user asks about expenses they just added and confirmed, check the list — they ARE there. NEVER say "they were never added" or "you didn't confirm".
4. DELETING: You cannot delete expenses. Tell the user: "Go to History tab, swipe left on the transaction to delete it." or "Long-press the transaction on the Home screen to delete."
5. EDITING: Tell the user: "Tap any transaction in History to edit it."
6. CATEGORIES: Pick the closest matching category from the list. Default payment method is 1 (Cash) unless user specifies.
7. DATES: Default is today ($todayStr). "Yesterday" = $yesterdayStr. Parse natural dates like "last friday", "3 days ago", etc.
8. CURRENCY: Always include "currency" in the action block. Supported: INR, USD, EUR, GBP, JPY, AUD, CAD, CHF, SGD, AED. Default: "$defaultCurrency".
   - "yen"/"¥" → JPY, "\$"/"dollars" → USD, "€"/"euros" → EUR, "£"/"pounds" → GBP, "₹"/"rupees" → INR
   - "2000 yen" or "¥2000" → currency: "JPY". "\$50" → currency: "USD". No currency mentioned → "$defaultCurrency"
9. INCOMPLETE INFO: If user says "movie 500", still create the action with best guesses. Don't ask for missing info.
10. INCOME: For salary, freelance, etc., use expenseType: "INCOME" and pick from income categories.

SPENDING QUERIES:
- Answer using the RECENT TRANSACTIONS and SUMMARY data above — be specific with real numbers
- If asked about trends, use the data you see
- Offer actionable tips, not generic advice

APP FEATURES:
- PDF/Statements → "Use the Statements tab (📄) for PDF reports"
- Budgets → "Settings → Budgets"
- Loans → "Settings → Loans & EMI"
- Recurring → "Settings → Recurring Expenses"
- Categories → "Settings → Categories"
- Currency rates → "Settings → Currency Rates"
- Backup → "Settings → Backup & Restore (Google Drive)"

PERSONALITY:
- Concise — max 3-4 sentences for simple queries
- Use bullet points for lists
- Add relevant emoji sparingly
- You can help with ANYTHING — finance, general knowledge, advice, fun conversations, coding, etc.
''';
  }

  // -----------------------------------------------------------------------
  // Send text message — stateless (fresh context every call, always accurate)
  // -----------------------------------------------------------------------
  static Future<String> sendMessage(String message) async {
    final context = await _getContextPrompt();
    final fullPrompt = '$context\n\nUser message: $message';

    return _callWithFallback(
      (model) => model.generateContent([Content.text(fullPrompt)]),
    );
  }

  // -----------------------------------------------------------------------
  // Send image message
  // -----------------------------------------------------------------------
  static Future<String> sendImageMessage(String message, Uint8List imageBytes, String mimeType) async {
    final context = await _getContextPrompt();
    final prompt = '''
$context

The user uploaded an image (likely a receipt, bill, or expense document).
1. Extract: amounts, items, date, shop/vendor name
2. Summarize what you see
3. Create action blocks for each item found
4. Say "tap Confirm to save"

User message: ${message.isEmpty ? "Scan this receipt and help me add the expense." : message}
''';

    return _callWithFallback(
      (model) => model.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType, imageBytes),
        ]),
      ]),
    );
  }

  // -----------------------------------------------------------------------
  // Core: call Gemini with automatic model fallback
  // -----------------------------------------------------------------------
  static Future<String> _callWithFallback(
    Future<GenerateContentResponse> Function(GenerativeModel model) apiCall,
  ) async {
    String lastError = '';

    for (var i = 0; i < _modelFallbacks.length; i++) {
      final modelName = _modelFallbacks[i];
      try {
        final model = _createModel(modelName);
        final response = await apiCall(model);
        final text = response.text;
        if (text != null && text.isNotEmpty) return text;
        return 'I got an empty response. Please try again.';
      } catch (e) {
        final msg = e.toString();
        lastError = msg;
        debugPrint('GeminiService: Model $modelName failed: $msg');

        if (msg.contains('quota') || msg.contains('429') || msg.contains('RESOURCE_EXHAUSTED')) {
          return '⏳ Rate limit reached. Please wait a minute and try again.\n\nFree tier: 15 requests/min, 500/day.';
        }
        if (msg.contains('API_KEY') || msg.contains('PERMISSION_DENIED') || msg.contains('authentication')) {
          return '🔑 API key error. Please contact the app developer.';
        }

        final isModelError = msg.contains('503') ||
            msg.contains('404') ||
            msg.contains('not found') ||
            msg.contains('not available') ||
            msg.contains('no longer available') ||
            msg.contains('Server Error') ||
            msg.contains('UNAVAILABLE');

        if (isModelError && i < _modelFallbacks.length - 1) {
          debugPrint('GeminiService: Falling back from $modelName to ${_modelFallbacks[i + 1]}');
          continue;
        }
      }
    }

    final safeError = lastError.replaceAll(_apiKey, '***');
    final truncated = safeError.length > 120 ? safeError.substring(0, 120) : safeError;
    return '❌ All AI models are currently unavailable. Please try again in a few minutes.\n\nError: $truncated';
  }

  // -----------------------------------------------------------------------
  // Parse action blocks from response
  // -----------------------------------------------------------------------
  static Future<Map<String, dynamic>?> parseAction(String response) async {
    final actions = await parseActions(response);
    return actions.isNotEmpty ? actions.first : null;
  }

  static Future<List<Map<String, dynamic>>> parseActions(String response) async {
    final actionRegex = RegExp(r'```action\s*\n?(.*?)\n?```', dotAll: true);
    final matches = actionRegex.allMatches(response);
    if (matches.isEmpty) return [];

    await _loadCaches();
    final results = <Map<String, dynamic>>[];
    for (final match in matches) {
      try {
        final jsonStr = match.group(1)!.trim();
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        json['_categoryName'] = getCategoryName(json['categoryId'] as int?) ?? 'Unknown';
        json['_paymentMethodName'] = getPaymentMethodName(json['paymentMethodId'] as int?) ?? 'Cash';
        results.add(json);
      } catch (e) {
        debugPrint('GeminiService: Failed to parse action block: $e');
      }
    }
    return results;
  }

  // -----------------------------------------------------------------------
  // Execute an action (save expense to DB)
  // -----------------------------------------------------------------------
  static Future<bool> executeAction(Map<String, dynamic> action) async {
    try {
      if (action['type'] == 'add_expense') {
        final dateParts = (action['date'] as String?)?.split('-');
        DateTime date;
        if (dateParts != null && dateParts.length == 3) {
          date = DateTime(int.parse(dateParts[0]), int.parse(dateParts[1]), int.parse(dateParts[2]));
        } else {
          date = DateTime.now();
        }

        final amount = (action['amount'] as num?)?.toDouble();
        if (amount == null) {
          debugPrint('GeminiService: executeAction missing/invalid amount');
          return false;
        }

        final categoryId = action['categoryId'] as int? ??
            (_cachedCategories.isNotEmpty ? _cachedCategories.first.id : null);
        if (categoryId == null) {
          debugPrint('GeminiService: executeAction missing categoryId and no categories available');
          return false;
        }

        final expense = Expense(
          amount: amount,
          categoryId: categoryId,
          paymentMethodId: action['paymentMethodId'] as int? ?? 1,
          note: action['note'] as String?,
          date: date,
          type: action['expenseType'] as String? ?? 'EXPENSE',
          tag: action['tag'] as String?,
          currency: action['currency'] as String? ?? CurrencyFormatter.defaultCurrencyCode,
        );

        await _expenseRepo.insert(expense);
        refreshCaches();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('GeminiService: executeAction failed: $e');
      return false;
    }
  }

  static String removeActionBlock(String response) {
    return response.replaceAll(RegExp(r'```action\s*\n?.*?\n?```', dotAll: true), '').trim();
  }

  // Keep for backward compat but no longer used internally
  static void resetChat() {
    refreshCaches();
  }
}
