class Category {
  final int? id;
  final String name;
  final String icon;
  final int color;
  final bool isDefault;
  final String type; // 'EXPENSE', 'INCOME', or 'BOTH'

  Category({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isDefault = false,
    this.type = 'EXPENSE',
  });

  factory Category.fromMap(Map<String, dynamic> map) => Category(
    id: map['id'] as int?,
    name: map['name'] as String,
    icon: map['icon'] as String,
    color: map['color'] as int,
    isDefault: (map['isDefault'] as int) == 1,
    type: (map['type'] as String?) ?? 'EXPENSE',
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'icon': icon,
    'color': color,
    'isDefault': isDefault ? 1 : 0,
    'type': type,
  };

  Category copyWith({int? id, String? name, String? icon, int? color, bool? isDefault, String? type}) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    isDefault: isDefault ?? this.isDefault,
    type: type ?? this.type,
  );
}

class PaymentMethod {
  final int? id;
  final String name;
  final String type;
  final bool isDefault;

  PaymentMethod({this.id, required this.name, required this.type, this.isDefault = false});

  factory PaymentMethod.fromMap(Map<String, dynamic> map) => PaymentMethod(
    id: map['id'] as int?,
    name: map['name'] as String,
    type: map['type'] as String,
    isDefault: (map['isDefault'] as int) == 1,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'type': type,
    'isDefault': isDefault ? 1 : 0,
  };
}

class Tag {
  final int? id;
  final String name;
  final bool isDefault;

  Tag({this.id, required this.name, this.isDefault = false});

  factory Tag.fromMap(Map<String, dynamic> map) => Tag(
    id: map['id'] as int?,
    name: map['name'] as String,
    isDefault: (map['isDefault'] as int) == 1,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'isDefault': isDefault ? 1 : 0,
  };

  Tag copyWith({int? id, String? name, bool? isDefault}) => Tag(
    id: id ?? this.id,
    name: name ?? this.name,
    isDefault: isDefault ?? this.isDefault,
  );
}

class Expense {
  final int? id;
  final double amount;
  final int categoryId;
  final int paymentMethodId;
  final String? note;
  final DateTime date;
  final DateTime createdAt;
  final String type;
  final String? tag;
  final String currency;

  Expense({
    this.id,
    required this.amount,
    required this.categoryId,
    required this.paymentMethodId,
    this.note,
    required this.date,
    DateTime? createdAt,
    this.type = 'EXPENSE',
    this.tag,
    this.currency = 'INR',
  }) : createdAt = createdAt ?? DateTime.now();

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
    id: map['id'] as int?,
    amount: (map['amount'] as num).toDouble(),
    categoryId: map['categoryId'] as int,
    paymentMethodId: map['paymentMethodId'] as int,
    note: map['note'] as String?,
    date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    type: (map['type'] as String?) ?? 'EXPENSE',
    tag: map['tag'] as String?,
    currency: (map['currency'] as String?) ?? 'INR',
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'amount': amount,
    'categoryId': categoryId,
    'paymentMethodId': paymentMethodId,
    'note': note,
    'date': date.millisecondsSinceEpoch,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'type': type,
    'tag': tag,
    'currency': currency,
  };

  Expense copyWith({
    int? id,
    double? amount,
    int? categoryId,
    int? paymentMethodId,
    String? note,
    DateTime? date,
    String? type,
    String? tag,
    String? currency,
  }) => Expense(
    id: id ?? this.id,
    amount: amount ?? this.amount,
    categoryId: categoryId ?? this.categoryId,
    paymentMethodId: paymentMethodId ?? this.paymentMethodId,
    note: note ?? this.note,
    date: date ?? this.date,
    createdAt: createdAt,
    type: type ?? this.type,
    tag: tag ?? this.tag,
    currency: currency ?? this.currency,
  );

  bool get isIncome => type == 'INCOME';
}

class Budget {
  final int? id;
  final int? categoryId;
  final double amount;
  final int month;

  Budget({this.id, this.categoryId, required this.amount, required this.month});

  factory Budget.fromMap(Map<String, dynamic> map) => Budget(
    id: map['id'] as int?,
    categoryId: map['categoryId'] as int?,
    amount: (map['amount'] as num).toDouble(),
    month: map['month'] as int,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'categoryId': categoryId,
    'amount': amount,
    'month': month,
  };
}

class Loan {
  final int? id;
  final String name;
  final double totalAmount;
  final double emiAmount;
  final double interestRate;
  final int tenureMonths;
  final int deductionDay;
  final int categoryId;
  final DateTime startDate;
  final bool isActive;
  final String currency;
  final DateTime? disbursementDate;
  final List<LoanRateChange> rateHistory;
  final double preEmiInterest;

  Loan({
    this.id,
    required this.name,
    required this.totalAmount,
    required this.emiAmount,
    required this.interestRate,
    required this.tenureMonths,
    required this.deductionDay,
    required this.categoryId,
    required this.startDate,
    this.isActive = true,
    this.currency = 'INR',
    this.disbursementDate,
    this.rateHistory = const [],
    this.preEmiInterest = 0,
  });

  DateTime get effectiveDisbursementDate => disbursementDate ?? startDate;

  factory Loan.fromMap(Map<String, dynamic> map) => Loan(
    id: map['id'] as int?,
    name: map['name'] as String,
    totalAmount: (map['totalAmount'] as num).toDouble(),
    emiAmount: (map['emiAmount'] as num).toDouble(),
    interestRate: (map['interestRate'] as num).toDouble(),
    tenureMonths: map['tenureMonths'] as int,
    deductionDay: map['deductionDay'] as int,
    categoryId: map['categoryId'] as int,
    startDate: DateTime.fromMillisecondsSinceEpoch(map['startDate'] as int),
    isActive: (map['isActive'] as int) == 1,
    currency: (map['currency'] as String?) ?? 'INR',
    disbursementDate: map['disbursementDate'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['disbursementDate'] as int)
        : null,
    preEmiInterest: (map['preEmiInterest'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'totalAmount': totalAmount,
    'emiAmount': emiAmount,
    'interestRate': interestRate,
    'tenureMonths': tenureMonths,
    'deductionDay': deductionDay,
    'categoryId': categoryId,
    'startDate': startDate.millisecondsSinceEpoch,
    'isActive': isActive ? 1 : 0,
    'currency': currency,
    'disbursementDate': disbursementDate?.millisecondsSinceEpoch,
    'preEmiInterest': preEmiInterest,
  };

  Loan copyWith({
    int? id,
    String? name,
    double? totalAmount,
    double? emiAmount,
    double? interestRate,
    int? tenureMonths,
    int? deductionDay,
    int? categoryId,
    DateTime? startDate,
    bool? isActive,
    String? currency,
    DateTime? disbursementDate,
    List<LoanRateChange>? rateHistory,
    double? preEmiInterest,
  }) => Loan(
    id: id ?? this.id,
    name: name ?? this.name,
    totalAmount: totalAmount ?? this.totalAmount,
    emiAmount: emiAmount ?? this.emiAmount,
    interestRate: interestRate ?? this.interestRate,
    tenureMonths: tenureMonths ?? this.tenureMonths,
    deductionDay: deductionDay ?? this.deductionDay,
    categoryId: categoryId ?? this.categoryId,
    startDate: startDate ?? this.startDate,
    isActive: isActive ?? this.isActive,
    currency: currency ?? this.currency,
    disbursementDate: disbursementDate ?? this.disbursementDate,
    rateHistory: rateHistory ?? this.rateHistory,
    preEmiInterest: preEmiInterest ?? this.preEmiInterest,
  );
}

class LoanRateChange {
  final int? id;
  final int loanId;
  final DateTime effectiveDate;
  final double rate;

  LoanRateChange({
    this.id,
    required this.loanId,
    required this.effectiveDate,
    required this.rate,
  });

  factory LoanRateChange.fromMap(Map<String, dynamic> map) => LoanRateChange(
    id: map['id'] as int?,
    loanId: map['loanId'] as int,
    effectiveDate: DateTime.fromMillisecondsSinceEpoch(map['effectiveDate'] as int),
    rate: (map['rate'] as num).toDouble(),
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'loanId': loanId,
    'effectiveDate': effectiveDate.millisecondsSinceEpoch,
    'rate': rate,
  };
}

class LoanPayment {
  final int? id;
  final int loanId;
  final double amount;
  final double principal;
  final double interest;
  final DateTime paymentDate;
  final bool isExtraPayment;
  final int? expenseId;
  final String currency;

  LoanPayment({
    this.id,
    required this.loanId,
    required this.amount,
    required this.principal,
    required this.interest,
    required this.paymentDate,
    this.isExtraPayment = false,
    this.expenseId,
    this.currency = 'INR',
  });

  factory LoanPayment.fromMap(Map<String, dynamic> map) => LoanPayment(
    id: map['id'] as int?,
    loanId: map['loanId'] as int,
    amount: (map['amount'] as num).toDouble(),
    principal: (map['principal'] as num).toDouble(),
    interest: (map['interest'] as num).toDouble(),
    paymentDate: DateTime.fromMillisecondsSinceEpoch(map['paymentDate'] as int),
    isExtraPayment: (map['isExtraPayment'] as int) == 1,
    expenseId: map['expenseId'] as int?,
    currency: (map['currency'] as String?) ?? 'INR',
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'loanId': loanId,
    'amount': amount,
    'principal': principal,
    'interest': interest,
    'paymentDate': paymentDate.millisecondsSinceEpoch,
    'isExtraPayment': isExtraPayment ? 1 : 0,
    'expenseId': expenseId,
    'currency': currency,
  };
}

class CurrencyRate {
  final int? id;
  final String fromCurrency;
  final String toCurrency;
  final double rate;
  final DateTime updatedAt;

  CurrencyRate({
    this.id,
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory CurrencyRate.fromMap(Map<String, dynamic> map) => CurrencyRate(
    id: map['id'] as int?,
    fromCurrency: map['fromCurrency'] as String,
    toCurrency: map['toCurrency'] as String,
    rate: (map['rate'] as num).toDouble(),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'fromCurrency': fromCurrency,
    'toCurrency': toCurrency,
    'rate': rate,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };
}

class RecurringExpense {
  final int? id;
  final double amount;
  final int categoryId;
  final int paymentMethodId;
  final String? note;
  final String frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? lastProcessedDate;
  final bool isActive;

  RecurringExpense({
    this.id,
    required this.amount,
    required this.categoryId,
    required this.paymentMethodId,
    this.note,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.lastProcessedDate,
    this.isActive = true,
  });

  factory RecurringExpense.fromMap(Map<String, dynamic> map) => RecurringExpense(
    id: map['id'] as int?,
    amount: (map['amount'] as num).toDouble(),
    categoryId: map['categoryId'] as int,
    paymentMethodId: map['paymentMethodId'] as int,
    note: map['note'] as String?,
    frequency: map['frequency'] as String,
    startDate: DateTime.fromMillisecondsSinceEpoch(map['startDate'] as int),
    endDate: map['endDate'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['endDate'] as int)
        : null,
    lastProcessedDate: map['lastProcessedDate'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['lastProcessedDate'] as int)
        : null,
    isActive: (map['isActive'] as int) == 1,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'amount': amount,
    'categoryId': categoryId,
    'paymentMethodId': paymentMethodId,
    'note': note,
    'frequency': frequency,
    'startDate': startDate.millisecondsSinceEpoch,
    'endDate': endDate?.millisecondsSinceEpoch,
    'lastProcessedDate': lastProcessedDate?.millisecondsSinceEpoch,
    'isActive': isActive ? 1 : 0,
  };
}

class CategoryTotal {
  final int? categoryId;
  final double total;
  CategoryTotal({this.categoryId, required this.total});
}

class PaymentMethodTotal {
  final int? paymentMethodId;
  final double total;
  PaymentMethodTotal({this.paymentMethodId, required this.total});
}

class DailyTotal {
  final DateTime date;
  final double total;
  DailyTotal({required this.date, required this.total});
}

class SavingsGoal {
  final int? id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final DateTime? targetDate;
  final int color;
  final String icon;

  SavingsGoal({
    this.id,
    required this.name,
    required this.targetAmount,
    this.savedAmount = 0.0,
    this.targetDate,
    required this.color,
    required this.icon,
  });

  factory SavingsGoal.fromMap(Map<String, dynamic> map) => SavingsGoal(
    id: map['id'] as int?,
    name: map['name'] as String,
    targetAmount: (map['targetAmount'] as num).toDouble(),
    savedAmount: (map['savedAmount'] as num).toDouble(),
    targetDate: map['targetDate'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['targetDate'] as int)
        : null,
    color: map['color'] as int,
    icon: map['icon'] as String,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'targetAmount': targetAmount,
    'savedAmount': savedAmount,
    'targetDate': targetDate?.millisecondsSinceEpoch,
    'color': color,
    'icon': icon,
  };

  double get progress => targetAmount > 0 ? (savedAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  bool get isCompleted => savedAmount >= targetAmount - 0.005;
}
