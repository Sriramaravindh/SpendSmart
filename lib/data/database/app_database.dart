import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  /// Closes the cached database connection and clears the handle so the next
  /// [database] access re-opens it. Useful after a restore/import that replaces
  /// the underlying file, and for test isolation.
  static Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null) {
      await db.close();
    }
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'expense_tracker.db');

    return await openDatabase(
      path,
      version: 8,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE categories ADD COLUMN type TEXT NOT NULL DEFAULT "EXPENSE"');
      } catch (e) { debugPrint('Migration: $e'); }
      try {
        await db.execute('ALTER TABLE expenses ADD COLUMN type TEXT NOT NULL DEFAULT "EXPENSE"');
      } catch (e) { debugPrint('Migration: $e'); }
      await db.execute('''
        CREATE TABLE IF NOT EXISTS savings_goals (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          targetAmount REAL NOT NULL,
          savedAmount REAL NOT NULL DEFAULT 0,
          targetDate INTEGER,
          color INTEGER NOT NULL,
          icon TEXT NOT NULL
        )
      ''');
      await _seedIncomeCategories(db);
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE recurring_expenses ADD COLUMN endDate INTEGER');
      } catch (e) { debugPrint('Migration: $e'); }
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE expenses ADD COLUMN tag TEXT');
      } catch (e) { debugPrint('Migration: $e'); }
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tags (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          isDefault INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await _seedDefaultTags(db);
      final existingTags = await db.rawQuery(
        'SELECT DISTINCT tag FROM expenses WHERE tag IS NOT NULL AND tag != "" AND tag != "Home Expense"'
      );
      for (final row in existingTags) {
        final tagName = row['tag'] as String;
        try {
          await db.insert('tags', {'name': tagName, 'isDefault': 0});
        } catch (e) { debugPrint('Migration tag import: $e'); }
      }
    }
    if (oldVersion < 6) {
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN currency TEXT NOT NULL DEFAULT 'INR'");
      } catch (e) { debugPrint('Migration: $e'); }
      try {
        await db.execute("ALTER TABLE loans ADD COLUMN currency TEXT NOT NULL DEFAULT 'INR'");
      } catch (e) { debugPrint('Migration: $e'); }
      try {
        await db.execute("ALTER TABLE loan_payments ADD COLUMN currency TEXT NOT NULL DEFAULT 'INR'");
      } catch (e) { debugPrint('Migration: $e'); }
      await db.execute('''
        CREATE TABLE IF NOT EXISTS currency_rates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          fromCurrency TEXT NOT NULL,
          toCurrency TEXT NOT NULL,
          rate REAL NOT NULL,
          updatedAt INTEGER NOT NULL,
          UNIQUE(fromCurrency, toCurrency)
        )
      ''');
    }
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE loans ADD COLUMN disbursementDate INTEGER');
      } catch (e) { debugPrint('Migration: $e'); }
      await db.execute('''
        CREATE TABLE IF NOT EXISTS loan_rate_changes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          loanId INTEGER NOT NULL,
          effectiveDate INTEGER NOT NULL,
          rate REAL NOT NULL,
          FOREIGN KEY (loanId) REFERENCES loans(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_loan_rate_changes_loan ON loan_rate_changes(loanId)');
      final existingLoans = await db.query('loans');
      for (final loan in existingLoans) {
        final loanId = loan['id'] as int;
        final rate = (loan['interestRate'] as num).toDouble();
        final startDate = loan['startDate'] as int;
        await db.insert('loan_rate_changes', {
          'loanId': loanId,
          'effectiveDate': startDate,
          'rate': rate,
        });
      }
    }
    if (oldVersion < 8) {
      try {
        await db.execute("ALTER TABLE loans ADD COLUMN preEmiInterest REAL NOT NULL DEFAULT 0");
      } catch (e) { debugPrint('Migration: $e'); }
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        isDefault INTEGER NOT NULL DEFAULT 0,
        type TEXT NOT NULL DEFAULT 'EXPENSE'
      )
    ''');

    await db.execute('''
      CREATE TABLE payment_methods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        isDefault INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        categoryId INTEGER NOT NULL,
        paymentMethodId INTEGER NOT NULL,
        note TEXT,
        date INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        type TEXT NOT NULL DEFAULT 'EXPENSE',
        tag TEXT,
        currency TEXT NOT NULL DEFAULT 'INR',
        FOREIGN KEY (categoryId) REFERENCES categories(id),
        FOREIGN KEY (paymentMethodId) REFERENCES payment_methods(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoryId INTEGER,
        amount REAL NOT NULL,
        month INTEGER NOT NULL,
        FOREIGN KEY (categoryId) REFERENCES categories(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        emiAmount REAL NOT NULL,
        interestRate REAL NOT NULL,
        tenureMonths INTEGER NOT NULL,
        deductionDay INTEGER NOT NULL,
        categoryId INTEGER NOT NULL,
        startDate INTEGER NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        currency TEXT NOT NULL DEFAULT 'INR',
        disbursementDate INTEGER,
        preEmiInterest REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (categoryId) REFERENCES categories(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE loan_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loanId INTEGER NOT NULL,
        amount REAL NOT NULL,
        principal REAL NOT NULL,
        interest REAL NOT NULL,
        paymentDate INTEGER NOT NULL,
        isExtraPayment INTEGER NOT NULL DEFAULT 0,
        expenseId INTEGER,
        currency TEXT NOT NULL DEFAULT 'INR',
        FOREIGN KEY (loanId) REFERENCES loans(id),
        FOREIGN KEY (expenseId) REFERENCES expenses(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE loan_rate_changes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loanId INTEGER NOT NULL,
        effectiveDate INTEGER NOT NULL,
        rate REAL NOT NULL,
        FOREIGN KEY (loanId) REFERENCES loans(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE recurring_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        categoryId INTEGER NOT NULL,
        paymentMethodId INTEGER NOT NULL,
        note TEXT,
        frequency TEXT NOT NULL,
        startDate INTEGER NOT NULL,
        endDate INTEGER,
        lastProcessedDate INTEGER,
        isActive INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (categoryId) REFERENCES categories(id),
        FOREIGN KEY (paymentMethodId) REFERENCES payment_methods(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE savings_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        targetAmount REAL NOT NULL,
        savedAmount REAL NOT NULL DEFAULT 0,
        targetDate INTEGER,
        color INTEGER NOT NULL,
        icon TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        isDefault INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE currency_rates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fromCurrency TEXT NOT NULL,
        toCurrency TEXT NOT NULL,
        rate REAL NOT NULL,
        updatedAt INTEGER NOT NULL,
        UNIQUE(fromCurrency, toCurrency)
      )
    ''');

    await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
    await db.execute('CREATE INDEX idx_expenses_category ON expenses(categoryId)');
    await db.execute('CREATE INDEX idx_expenses_payment ON expenses(paymentMethodId)');
    await db.execute('CREATE INDEX idx_loans_active ON loans(isActive)');
    await db.execute('CREATE INDEX idx_loan_payments_loan ON loan_payments(loanId)');
    await db.execute('CREATE INDEX idx_loan_rate_changes_loan ON loan_rate_changes(loanId)');

    await _seedDefaults(db);
  }

  static Future<void> _seedDefaults(Database db) async {
    final categories = [
      {'name': 'Food', 'icon': 'restaurant', 'color': 0xFFE57373, 'isDefault': 1, 'type': 'EXPENSE'},
      {'name': 'Transport', 'icon': 'directions_car', 'color': 0xFF64B5F6, 'isDefault': 1, 'type': 'EXPENSE'},
      {'name': 'Shopping', 'icon': 'shopping_bag', 'color': 0xFFFFB74D, 'isDefault': 1, 'type': 'EXPENSE'},
      {'name': 'Entertainment', 'icon': 'movie', 'color': 0xFFBA68C8, 'isDefault': 1, 'type': 'EXPENSE'},
      {'name': 'Bills', 'icon': 'receipt', 'color': 0xFF4DB6AC, 'isDefault': 1, 'type': 'EXPENSE'},
      {'name': 'Health', 'icon': 'local_hospital', 'color': 0xFFF06292, 'isDefault': 1, 'type': 'EXPENSE'},
      {'name': 'Education', 'icon': 'school', 'color': 0xFF7986CB, 'isDefault': 1, 'type': 'EXPENSE'},
      {'name': 'Others', 'icon': 'more_horiz', 'color': 0xFF90A4AE, 'isDefault': 1, 'type': 'EXPENSE'},
      {'name': 'Home Loan', 'icon': 'home', 'color': 0xFF5C6BC0, 'isDefault': 1, 'type': 'EXPENSE'},
      {'name': 'Bike Loan', 'icon': 'two_wheeler', 'color': 0xFF26A69A, 'isDefault': 1, 'type': 'EXPENSE'},
    ];

    for (final cat in categories) {
      await db.insert('categories', cat);
    }

    await _seedIncomeCategories(db);

    final paymentMethods = [
      {'name': 'Cash', 'type': 'CASH', 'isDefault': 1},
      {'name': 'UPI', 'type': 'UPI', 'isDefault': 1},
      {'name': 'Kiwi CC', 'type': 'CREDIT_CARD', 'isDefault': 1},
      {'name': 'Axis CC', 'type': 'CREDIT_CARD', 'isDefault': 1},
      {'name': 'SBI CC', 'type': 'CREDIT_CARD', 'isDefault': 1},
    ];

    for (final pm in paymentMethods) {
      await db.insert('payment_methods', pm);
    }

    await _seedDefaultTags(db);
  }

  static Future<void> _seedDefaultTags(Database db) async {
    final defaultTags = [
      {'name': 'Home Expense', 'isDefault': 1},
    ];
    for (final tag in defaultTags) {
      final existing = await db.query('tags', where: 'name = ?', whereArgs: [tag['name']]);
      if (existing.isEmpty) {
        await db.insert('tags', tag);
      }
    }
  }

  static Future<void> _seedIncomeCategories(Database db) async {
    final incomeCategories = [
      {'name': 'Salary', 'icon': 'account_balance_wallet', 'color': 0xFF66BB6A, 'isDefault': 1, 'type': 'INCOME'},
      {'name': 'Freelance', 'icon': 'work', 'color': 0xFF42A5F5, 'isDefault': 1, 'type': 'INCOME'},
      {'name': 'Investments', 'icon': 'trending_up', 'color': 0xFFAB47BC, 'isDefault': 1, 'type': 'INCOME'},
      {'name': 'Business', 'icon': 'store', 'color': 0xFFFFA726, 'isDefault': 1, 'type': 'INCOME'},
      {'name': 'Other Income', 'icon': 'attach_money', 'color': 0xFF26A69A, 'isDefault': 1, 'type': 'INCOME'},
    ];

    for (final cat in incomeCategories) {
      final existing = await db.query('categories', where: 'name = ? AND type = ?', whereArgs: [cat['name'], 'INCOME']);
      if (existing.isEmpty) {
        await db.insert('categories', cat);
      }
    }
  }
}
