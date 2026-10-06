import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../data/models.dart';
import '../../data/repositories/currency_rate_repository.dart';
import 'currency_formatter.dart';

class PdfStatementService {
  static const _primary = PdfColor.fromInt(0xFF1A237E);
  static const _primaryLight = PdfColor.fromInt(0xFF3949AB);
  static const _accent = PdfColor.fromInt(0xFFC5CAE9);
  static const _green = PdfColor.fromInt(0xFF2E7D32);
  static const _red = PdfColor.fromInt(0xFFC62828);
  static const _textDark = PdfColor.fromInt(0xFF212121);
  static const _textMedium = PdfColor.fromInt(0xFF616161);
  static const _textLight = PdfColor.fromInt(0xFF9E9E9E);
  static const _border = PdfColor.fromInt(0xFFE0E0E0);
  static const _rowAlt = PdfColor.fromInt(0xFFF8F9FA);

  static String _fmt(double amount) {
    final sym = CurrencyFormatter.symbol;
    if (sym == '₹') {
      final formatter = NumberFormat('#,##,##0.00', 'en_IN');
      return 'Rs. ${formatter.format(amount)}';
    }
    final formatter = NumberFormat('#,##0.00');
    final formatted = formatter.format(amount);
    if (sym == '€') return 'EUR $formatted';
    if (sym == '£') return 'GBP $formatted';
    if (sym == '¥') return 'JPY $formatted';
    return '$sym $formatted';
  }

  static String _fmtCurrency(double amount, String currencyCode) {
    final sym = CurrencyFormatter.symbolFor(currencyCode);
    if (currencyCode == 'INR') {
      final formatter = NumberFormat('#,##,##0.00', 'en_IN');
      return 'Rs. ${formatter.format(amount)}';
    }
    if (currencyCode == 'JPY') {
      final formatter = NumberFormat('#,##0', 'en_US');
      return '$sym${formatter.format(amount)}';
    }
    final formatter = NumberFormat('#,##0.00');
    return '$sym ${formatter.format(amount)}';
  }

  static Future<Uint8List> generateStatementPdf({
    required DateTime startDate,
    required DateTime endDate,
    required double totalIncome,
    required double totalExpense,
    required List<Expense> transactions,
    required Map<int, Category> categoryMap,
    required Map<int, PaymentMethod> paymentMethodMap,
    String? filterName,
    Map<String, double> rateMap = const {},
  }) async {
    final pdf = pw.Document(title: 'Expense Statement', author: 'SpendSmart');
    final dateFmt = DateFormat('dd MMM yyyy');
    final timeFmt = DateFormat('dd MMM yyyy, hh:mm a');

    final expenses = transactions.where((t) => !t.isIncome).toList();
    final incomes = transactions.where((t) => t.isIncome).toList();

    final defaultCurrency = CurrencyFormatter.defaultCurrencyCode;
    final catBreakdown = _buildCategoryBreakdown(expenses, categoryMap, rateMap, defaultCurrency);
    final pmBreakdown = _buildPaymentMethodBreakdown(expenses, paymentMethodMap, rateMap, defaultCurrency);
    final topExpense = expenses.isEmpty ? null : expenses.reduce((a, b) {
      final aConverted = CurrencyRateRepository.convertAmount(a.amount, a.currency, defaultCurrency, rateMap);
      final bConverted = CurrencyRateRepository.convertAmount(b.amount, b.currency, defaultCurrency, rateMap);
      return aConverted > bConverted ? a : b;
    });
    final avgExpense = expenses.isEmpty ? 0.0 : totalExpense / expenses.length;

    final numDays = endDate.difference(startDate).inDays + 1;
    final dailyAvg = numDays > 0 ? totalExpense / numDays : 0.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(left: 36, right: 36, top: 28, bottom: 28),
        header: (ctx) {
          if (ctx.pageNumber == 1) return pw.SizedBox.shrink();
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.only(bottom: 4),
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.5))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('SpendSmart', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _primary)),
                pw.Text('${dateFmt.format(startDate)} to ${dateFmt.format(endDate)}', style: const pw.TextStyle(fontSize: 7.5, color: _textLight)),
              ],
            ),
          );
        },
        footer: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          padding: const pw.EdgeInsets.only(top: 4),
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _border, width: 0.5))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('This is a system-generated statement.', style: const pw.TextStyle(fontSize: 6.5, color: _textLight)),
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: _textMedium)),
            ],
          ),
        ),
        build: (ctx) => [
          _titleBanner(dateFmt, timeFmt, startDate, endDate, filterName),
          pw.SizedBox(height: 18),

          _summaryRow(totalIncome, totalExpense, transactions.length, expenses.length, incomes.length),
          pw.SizedBox(height: 18),

          _sectionLabel('Key Metrics'),
          pw.SizedBox(height: 6),
          _metricsRow(dailyAvg, avgExpense, topExpense, categoryMap, numDays),
          pw.SizedBox(height: 22),

          if (catBreakdown.isNotEmpty) ...[
            _sectionLabel('Category Breakdown'),
            pw.SizedBox(height: 8),
            _categoryTable(catBreakdown, totalExpense),
            pw.SizedBox(height: 22),
          ],

          if (pmBreakdown.isNotEmpty) ...[
            _sectionLabel('Payment Method Breakdown'),
            pw.SizedBox(height: 8),
            _paymentMethodTable(pmBreakdown, totalExpense),
            pw.SizedBox(height: 22),
          ],

          _sectionLabel('Transaction Details (${transactions.length} records)'),
          pw.SizedBox(height: 8),
          _transactionTable(transactions, categoryMap, paymentMethodMap, dateFmt),
          pw.SizedBox(height: 14),

          _grandTotalBar(totalIncome, totalExpense),
          pw.SizedBox(height: 20),

          pw.Divider(thickness: 0.5, color: _border),
          pw.SizedBox(height: 6),
          pw.Center(child: pw.Text('- End of Statement -', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _textLight))),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _titleBanner(DateFormat dateFmt, DateFormat timeFmt, DateTime start, DateTime end, String? filterName) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: pw.BoxDecoration(color: _primary, borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('EXPENSE TRACKER', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 2)),
                pw.SizedBox(height: 4),
                pw.Container(width: 40, height: 2, color: _accent),
                pw.SizedBox(height: 6),
                pw.Text(filterName ?? 'Account Statement', style: const pw.TextStyle(fontSize: 10, color: _accent)),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(color: _primaryLight, borderRadius: pw.BorderRadius.circular(2)),
                child: pw.Text('${dateFmt.format(start)}  -  ${dateFmt.format(end)}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              ),
              pw.SizedBox(height: 6),
              pw.Text('Generated: ${timeFmt.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 7, color: _accent)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryRow(double income, double expense, int total, int expCount, int incCount) {
    return pw.Row(
      children: [
        _summaryCard('Total Income', _fmt(income), _green, '$incCount entries'),
        pw.SizedBox(width: 10),
        _summaryCard('Total Expenses', _fmt(expense), _red, '$expCount entries'),
        pw.SizedBox(width: 10),
        _summaryCard('Total Transactions', '$total', _primary, 'All types'),
      ],
    );
  }

  static pw.Widget _summaryCard(String label, String value, PdfColor color, String sub) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _border, width: 0.5), borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label.toUpperCase(), style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: _textLight, letterSpacing: 0.5)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
            pw.SizedBox(height: 2),
            pw.Text(sub, style: const pw.TextStyle(fontSize: 6.5, color: _textLight)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _metricsRow(double dailyAvg, double avgExpense, Expense? topExpense, Map<int, Category> catMap, int numDays) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xFFF5F5F5), borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Row(
        children: [
          _metricItem('Period', '$numDays days'),
          _metricDivider(),
          _metricItem('Daily Average', _fmt(dailyAvg)),
          _metricDivider(),
          _metricItem('Avg per Txn', _fmt(avgExpense)),
          _metricDivider(),
          _metricItem('Highest Expense', topExpense != null ? _fmtCurrency(topExpense.amount, topExpense.currency) : '-'),
        ],
      ),
    );
  }

  static pw.Widget _metricItem(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        children: [
          pw.Text(label.toUpperCase(), style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: _textLight, letterSpacing: 0.3)),
          pw.SizedBox(height: 3),
          pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _textDark)),
        ],
      ),
    );
  }

  static pw.Widget _metricDivider() => pw.Container(width: 0.5, height: 22, color: _border);

  static pw.Widget _sectionLabel(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 3),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _primary, width: 1.5))),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _primary)),
    );
  }

  static List<_CatRow> _buildCategoryBreakdown(List<Expense> expenses, Map<int, Category> catMap, Map<String, double> rateMap, String defaultCurrency) {
    final map = <int, double>{};
    final countMap = <int, int>{};
    for (final t in expenses) {
      final converted = CurrencyRateRepository.convertAmount(t.amount, t.currency, defaultCurrency, rateMap);
      map[t.categoryId] = (map[t.categoryId] ?? 0) + converted;
      countMap[t.categoryId] = (countMap[t.categoryId] ?? 0) + 1;
    }
    final rows = map.entries.map((e) => _CatRow(
      name: catMap[e.key]?.name ?? 'Other',
      amount: e.value,
      count: countMap[e.key] ?? 0,
    )).toList();
    rows.sort((a, b) => b.amount.compareTo(a.amount));
    return rows;
  }

  static pw.Widget _categoryTable(List<_CatRow> rows, double total) {
    final hStyle = pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _primary, letterSpacing: 0.3);
    final cStyle = const pw.TextStyle(fontSize: 7.5, color: _textDark);
    final bStyle = pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _textDark);

    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _border, width: 0.3),
        bottom: pw.BorderSide(color: _primary, width: 1),
        top: pw.BorderSide(color: _primary, width: 1),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FixedColumnWidth(40),
        2: pw.FlexColumnWidth(2.5),
        3: pw.FixedColumnWidth(45),
      },
      children: [
        pw.TableRow(children: [
          _tc('CATEGORY', hStyle, pw.Alignment.centerLeft),
          _tc('COUNT', hStyle, pw.Alignment.center),
          _tc('AMOUNT', hStyle, pw.Alignment.centerRight),
          _tc('SHARE', hStyle, pw.Alignment.centerRight),
        ]),
        ...rows.map((r) {
          final pct = total > 0 ? (r.amount / total * 100) : 0.0;
          return pw.TableRow(
            children: [
              _tc(r.name, cStyle, pw.Alignment.centerLeft),
              _tc('${r.count}', cStyle, pw.Alignment.center),
              _tc(_fmt(r.amount), cStyle, pw.Alignment.centerRight),
              _tc('${pct.toStringAsFixed(1)}%', bStyle, pw.Alignment.centerRight),
            ],
          );
        }),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)),
          children: [
            _tc('TOTAL', bStyle, pw.Alignment.centerLeft),
            _tc('${rows.fold(0, (s, r) => s + r.count)}', bStyle, pw.Alignment.center),
            _tc(_fmt(total), pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _red), pw.Alignment.centerRight),
            _tc('100%', bStyle, pw.Alignment.centerRight),
          ],
        ),
      ],
    );
  }

  static List<_CatRow> _buildPaymentMethodBreakdown(List<Expense> expenses, Map<int, PaymentMethod> pmMap, Map<String, double> rateMap, String defaultCurrency) {
    final map = <int, double>{};
    final countMap = <int, int>{};
    for (final t in expenses) {
      final converted = CurrencyRateRepository.convertAmount(t.amount, t.currency, defaultCurrency, rateMap);
      map[t.paymentMethodId] = (map[t.paymentMethodId] ?? 0) + converted;
      countMap[t.paymentMethodId] = (countMap[t.paymentMethodId] ?? 0) + 1;
    }
    final rows = map.entries.map((e) => _CatRow(
      name: pmMap[e.key]?.name ?? 'Other',
      amount: e.value,
      count: countMap[e.key] ?? 0,
    )).toList();
    rows.sort((a, b) => b.amount.compareTo(a.amount));
    return rows;
  }

  static pw.Widget _paymentMethodTable(List<_CatRow> rows, double total) {
    final hStyle = pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _primary, letterSpacing: 0.3);
    final cStyle = const pw.TextStyle(fontSize: 7.5, color: _textDark);
    final bStyle = pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _textDark);

    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _border, width: 0.3),
        bottom: pw.BorderSide(color: _primary, width: 1),
        top: pw.BorderSide(color: _primary, width: 1),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FixedColumnWidth(40),
        2: pw.FlexColumnWidth(2.5),
        3: pw.FixedColumnWidth(45),
      },
      children: [
        pw.TableRow(children: [
          _tc('METHOD', hStyle, pw.Alignment.centerLeft),
          _tc('COUNT', hStyle, pw.Alignment.center),
          _tc('AMOUNT', hStyle, pw.Alignment.centerRight),
          _tc('SHARE', hStyle, pw.Alignment.centerRight),
        ]),
        ...rows.map((r) {
          final pct = total > 0 ? (r.amount / total * 100) : 0.0;
          return pw.TableRow(
            children: [
              _tc(r.name, cStyle, pw.Alignment.centerLeft),
              _tc('${r.count}', cStyle, pw.Alignment.center),
              _tc(_fmt(r.amount), cStyle, pw.Alignment.centerRight),
              _tc('${pct.toStringAsFixed(1)}%', bStyle, pw.Alignment.centerRight),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _transactionTable(List<Expense> transactions, Map<int, Category> catMap, Map<int, PaymentMethod> pmMap, DateFormat dateFmt) {
    if (transactions.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 30),
        alignment: pw.Alignment.center,
        child: pw.Text('No transactions for this period.', style: const pw.TextStyle(fontSize: 9, color: _textLight)),
      );
    }

    final hStyle = pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _primary, letterSpacing: 0.3);
    final cStyle = const pw.TextStyle(fontSize: 7.5, color: _textDark);
    final bStyle = pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold);

    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _border, width: 0.25),
        bottom: pw.BorderSide(color: _border, width: 0.5),
        top: pw.BorderSide(color: _primary, width: 1),
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(24),
        1: pw.FixedColumnWidth(58),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FlexColumnWidth(1.3),
        5: pw.FlexColumnWidth(2.5),
        6: pw.FixedColumnWidth(78),
      },
      children: [
        pw.TableRow(children: [
          _tc('#', hStyle, pw.Alignment.center),
          _tc('DATE', hStyle, pw.Alignment.centerLeft),
          _tc('CATEGORY', hStyle, pw.Alignment.centerLeft),
          _tc('TAG', hStyle, pw.Alignment.centerLeft),
          _tc('METHOD', hStyle, pw.Alignment.centerLeft),
          _tc('NOTE', hStyle, pw.Alignment.centerLeft),
          _tc('AMOUNT', hStyle, pw.Alignment.centerRight),
        ]),
        ...transactions.asMap().entries.map((entry) {
          final i = entry.key;
          final t = entry.value;
          final cat = catMap[t.categoryId]?.name ?? 'Other';
          final pm = pmMap[t.paymentMethodId]?.name ?? '-';
          final tag = (t.tag != null && t.tag!.isNotEmpty) ? t.tag! : '-';
          final isInc = t.isIncome;
          final amtColor = isInc ? _green : _red;
          final bg = i.isOdd ? _rowAlt : PdfColors.white;

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              _tc('${i + 1}', cStyle, pw.Alignment.center),
              _tc(dateFmt.format(t.date), cStyle, pw.Alignment.centerLeft),
              _tc(cat, cStyle, pw.Alignment.centerLeft),
              _tc(tag, cStyle, pw.Alignment.centerLeft),
              _tc(pm, cStyle, pw.Alignment.centerLeft),
              _tc(t.note ?? '-', cStyle, pw.Alignment.centerLeft, maxLines: 2),
              _tc('${isInc ? '+' : '-'} ${_fmtCurrency(t.amount, t.currency)}', bStyle.copyWith(color: amtColor), pw.Alignment.centerRight),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _grandTotalBar(double income, double expense) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF5F5F5),
        borderRadius: pw.BorderRadius.circular(3),
        border: pw.Border.all(color: _border, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text('TOTAL INCOME:  ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _textLight)),
          pw.Text(_fmt(income), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _green)),
          pw.SizedBox(width: 30),
          pw.Text('TOTAL EXPENSES:  ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _textLight)),
          pw.Text(_fmt(expense), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _red)),
        ],
      ),
    );
  }

  static pw.Widget _tc(String text, pw.TextStyle style, pw.Alignment align, {int maxLines = 1}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      alignment: align,
      child: pw.Text(text, style: style, maxLines: maxLines, overflow: pw.TextOverflow.clip),
    );
  }
}

class _CatRow {
  final String name;
  final double amount;
  final int count;
  _CatRow({required this.name, required this.amount, required this.count});
}
