import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../providers/providers.dart';
import '../../data/models.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../core/constants/icon_map.dart';
import '../../core/theme/app_colors.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _selectedRange = 'month';
  late DateTime _startDate;
  late DateTime _endDate;

  double _totalSpending = 0;
  List<CategoryTotal> _categoryTotals = [];
  List<PaymentMethodTotal> _pmTotals = [];
  List<DailyTotal> _dailyTotals = [];
  bool _isLoading = true;
  Future<List<DailyTotal>>? _monthlyTotalsFuture;
  int _lastRefreshCount = -1;

  @override
  void initState() {
    super.initState();
    _setDateRange('month');
  }

  void _setDateRange(String range) {
    final now = DateTime.now();
    setState(() {
      _selectedRange = range;
      switch (range) {
        case 'week':
          _startDate = DateTime(now.year, now.month, now.day - 6);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
          break;
        case 'month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
          break;
        case '3months':
          _startDate = DateTime(now.year, now.month - 2, 1);
          _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
          break;
        default:
          return;
      }
    });
    _loadData();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    // Clamp the initial range so start/end never exceed lastDate (now),
    // which would otherwise trip an assert in showDateRangePicker.
    final clampedStart = _startDate.isAfter(now) ? now : _startDate;
    final clampedEnd = _endDate.isAfter(now) ? now : _endDate;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(start: clampedStart, end: clampedEnd),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedRange = 'custom';
        _startDate = picked.start;
        _endDate = DateTime(
          picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999,
        );
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _refreshMonthlyFuture();
    });
    try {
      final repo = ref.read(expenseRepoProvider);
      final results = await Future.wait([
        repo.getTotalExpenseByDateRange(_startDate, _endDate),
        repo.getCategoryTotals(_startDate, _endDate, type: 'EXPENSE'),
        repo.getPaymentMethodTotals(_startDate, _endDate, type: 'EXPENSE'),
        repo.getDailyTotals(_startDate, _endDate, type: 'EXPENSE'),
      ]);
      if (mounted) {
        setState(() {
          _totalSpending = results[0] as double;
          _categoryTotals = results[1] as List<CategoryTotal>;
          _pmTotals = results[2] as List<PaymentMethodTotal>;
          _dailyTotals = results[3] as List<DailyTotal>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _dayCount {
    return _endDate.difference(_startDate).inDays + 1;
  }

  double get _dailyAverage {
    if (_dayCount <= 0) return 0;
    return _totalSpending / _dayCount;
  }

  void _refreshMonthlyFuture() {
    _monthlyTotalsFuture = _getMonthlyTotalsForPast6Months();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categories = ref.watch(categoriesProvider);
    final paymentMethods = ref.watch(paymentMethodsProvider);

    // React to data changes from other screens
    final refreshCount = ref.watch(expenseRefreshProvider);
    if (refreshCount != _lastRefreshCount) {
      _lastRefreshCount = refreshCount;
      if (_lastRefreshCount > 0) {
        // Skip on initial build since _setDateRange already calls _loadData
        Future.microtask(() => _loadData());
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateRangeSelector(colorScheme),
            const SizedBox(height: 16),
            if (_isLoading)
              const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _buildTotalSpendingCard(theme, colorScheme),
              const SizedBox(height: 20),
              categories.when(
                data: (cats) => _buildPieChartSection(theme, colorScheme, cats),
                loading: () => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
              _buildDailyTrendSection(theme, colorScheme),
              const SizedBox(height: 20),
              _buildMonthlyComparisonSection(theme, colorScheme),
              const SizedBox(height: 20),
              paymentMethods.when(
                data: (pms) =>
                    _buildPaymentMethodSection(theme, colorScheme, pms),
                loading: () => const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
              categories.when(
                data: (cats) =>
                    _buildTopCategoriesSection(theme, colorScheme, cats),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- Date Range Chips ----------

  Widget _buildDateRangeSelector(ColorScheme colorScheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _rangeChip('This Week', 'week', colorScheme),
          const SizedBox(width: 8),
          _rangeChip('This Month', 'month', colorScheme),
          const SizedBox(width: 8),
          _rangeChip('3 Months', '3months', colorScheme),
          const SizedBox(width: 8),
          ActionChip(
            avatar: Icon(
              Icons.date_range,
              size: 18,
              color: _selectedRange == 'custom'
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
            label: Text(
              _selectedRange == 'custom'
                  ? '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM').format(_endDate)}'
                  : 'Custom',
            ),
            backgroundColor: _selectedRange == 'custom'
                ? colorScheme.primaryContainer
                : null,
            side: _selectedRange == 'custom'
                ? BorderSide(color: colorScheme.primary.withOpacity(0.5))
                : null,
            onPressed: _pickCustomRange,
          ),
        ],
      ),
    );
  }

  Widget _rangeChip(String label, String value, ColorScheme colorScheme) {
    final selected = _selectedRange == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
      onSelected: (_) => _setDateRange(value),
    );
  }

  // ---------- Total Spending Card ----------

  Widget _buildTotalSpendingCard(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL SPENDING',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w300,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            CurrencyFormatter.format(_totalSpending),
            style: theme.textTheme.headlineLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 36,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${CurrencyFormatter.format(_dailyAverage)} / day avg',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Pie Chart Section ----------

  Widget _buildPieChartSection(
      ThemeData theme, ColorScheme colorScheme, List<Category> categories) {
    if (_categoryTotals.isEmpty) {
      return _buildEmptySection(theme, colorScheme, 'Category Breakdown',
          Icons.pie_chart_outline, 'No expenses in this period');
    }

    final categoryMap = {for (final c in categories) c.id: c};

    return _buildSectionCard(
      theme,
      colorScheme,
      title: 'Category Breakdown',
      icon: Icons.pie_chart_outline,
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sections: _buildPieSections(categoryMap),
                centerSpaceRadius: 52,
                sectionsSpace: 3,
                startDegreeOffset: -90,
              ),
              swapAnimationDuration: const Duration(milliseconds: 600),
              swapAnimationCurve: Curves.easeInOutCubic,
            ),
          ),
          const SizedBox(height: 20),
          _buildPieLegend(theme, categoryMap),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(Map<int?, Category> categoryMap) {
    return List.generate(_categoryTotals.length, (i) {
      final ct = _categoryTotals[i];
      final pct = _totalSpending > 0 ? (ct.total / _totalSpending * 100) : 0.0;
      final color = Color(categoryMap[ct.categoryId]?.color ?? 0xFF6B6B6B);

      return PieChartSectionData(
        value: ct.total,
        color: color,
        radius: 36,
        title: pct >= 5 ? '${pct.toStringAsFixed(0)}%' : '',
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        titlePositionPercentageOffset: 0.55,
      );
    });
  }

  Widget _buildPieLegend(ThemeData theme, Map<int?, Category> categoryMap) {
    return Wrap(
      spacing: 16,
      runSpacing: 10,
      children: List.generate(_categoryTotals.length, (i) {
        final ct = _categoryTotals[i];
        final cat = categoryMap[ct.categoryId];
        final color = Color(cat?.color ?? 0xFF6B6B6B);
        final pct =
            _totalSpending > 0 ? (ct.total / _totalSpending * 100) : 0.0;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              cat?.name ?? 'Unknown',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${pct.toStringAsFixed(1)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      }),
    );
  }

  // ---------- Daily Trend Line Chart ----------

  Widget _buildDailyTrendSection(ThemeData theme, ColorScheme colorScheme) {
    if (_dailyTotals.isEmpty) {
      return _buildEmptySection(theme, colorScheme, 'Daily Spending Trend',
          Icons.show_chart, 'No daily data available');
    }

    final sortedDailies = List<DailyTotal>.from(_dailyTotals)
      ..sort((a, b) => a.date.compareTo(b.date));

    final maxY = sortedDailies.fold<double>(
            0, (prev, dt) => dt.total > prev ? dt.total : prev) *
        1.2;
    final effectiveMaxY = maxY > 0 ? maxY : 100.0;

    return _buildSectionCard(
      theme,
      colorScheme,
      title: 'Daily Spending Trend',
      icon: Icons.show_chart,
      child: SizedBox(
        height: 220,
        child: Padding(
          padding: const EdgeInsets.only(right: 8, top: 8),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: effectiveMaxY / 4,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: colorScheme.outlineVariant.withOpacity(0.4),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 52,
                    interval: effectiveMaxY / 4,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          CurrencyFormatter.formatCompact(value),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: _bottomLabelInterval(sortedDailies.length),
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= sortedDailies.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('dd/MM')
                              .format(sortedDailies[idx].date),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 9,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minY: 0,
              maxY: effectiveMaxY,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) =>
                      colorScheme.inverseSurface,
                  tooltipRoundedRadius: 10,
                  getTooltipItems: (spots) {
                    return spots.map((spot) {
                      final idx = spot.x.toInt();
                      if (idx < 0 || idx >= sortedDailies.length) return null;
                      final dt = sortedDailies[idx];
                      return LineTooltipItem(
                        '${AppDateUtils.formatShortDate(dt.date)}\n',
                        TextStyle(
                          color: colorScheme.onInverseSurface,
                          fontSize: 11,
                        ),
                        children: [
                          TextSpan(
                            text: CurrencyFormatter.format(dt.total),
                            style: TextStyle(
                              color: colorScheme.onInverseSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(sortedDailies.length,
                      (i) => FlSpot(i.toDouble(), sortedDailies[i].total)),
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: colorScheme.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: sortedDailies.length <= 14,
                    getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                      radius: 3.5,
                      color: colorScheme.primary,
                      strokeWidth: 2,
                      strokeColor: colorScheme.surface,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colorScheme.primary.withOpacity(0.25),
                        colorScheme.primary.withOpacity(0.02),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _bottomLabelInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 14) return 2;
    if (count <= 31) return 5;
    return (count / 6).ceilToDouble();
  }

  // ---------- Payment Method Breakdown ----------

  Widget _buildPaymentMethodSection(ThemeData theme, ColorScheme colorScheme,
      List<PaymentMethod> paymentMethods) {
    if (_pmTotals.isEmpty) {
      return _buildEmptySection(theme, colorScheme, 'Payment Methods',
          Icons.account_balance_wallet_outlined, 'No payment data');
    }

    final pmMap = {for (final pm in paymentMethods) pm.id: pm};
    final maxTotal =
        _pmTotals.fold<double>(0, (p, t) => t.total > p ? t.total : p);

    return _buildSectionCard(
      theme,
      colorScheme,
      title: 'Payment Methods',
      icon: Icons.account_balance_wallet_outlined,
      child: Column(
        children: List.generate(_pmTotals.length, (i) {
          final pmt = _pmTotals[i];
          final pm = pmMap[pmt.paymentMethodId];
          final fraction = maxTotal > 0 ? pmt.total / maxTotal : 0.0;
          final pct =
              _totalSpending > 0 ? (pmt.total / _totalSpending * 100) : 0.0;
          final barColor =
              AppColors.chartColors[i % AppColors.chartColors.length];

          return Padding(
            padding: EdgeInsets.only(bottom: i < _pmTotals.length - 1 ? 14 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _paymentMethodIcon(pm?.type),
                          size: 18,
                          color: barColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          pm?.name ?? 'Unknown',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${CurrencyFormatter.format(pmt.total)}  (${pct.toStringAsFixed(1)}%)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 8,
                    backgroundColor:
                        colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    valueColor: AlwaysStoppedAnimation(barColor),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  IconData _paymentMethodIcon(String? type) {
    switch (type) {
      case 'cash':
        return Icons.money;
      case 'credit_card':
        return Icons.credit_card;
      case 'debit_card':
        return Icons.payment;
      case 'upi':
        return Icons.phone_android;
      case 'bank_transfer':
        return Icons.account_balance;
      case 'wallet':
        return Icons.account_balance_wallet;
      default:
        return Icons.payment;
    }
  }

  // ---------- Top Categories Ranked ----------

  Widget _buildTopCategoriesSection(
      ThemeData theme, ColorScheme colorScheme, List<Category> categories) {
    if (_categoryTotals.isEmpty) {
      return const SizedBox.shrink();
    }

    final categoryMap = {for (final c in categories) c.id: c};
    final maxTotal =
        _categoryTotals.fold<double>(0, (p, t) => t.total > p ? t.total : p);

    return _buildSectionCard(
      theme,
      colorScheme,
      title: 'Top Categories',
      icon: Icons.leaderboard_outlined,
      child: Column(
        children: List.generate(_categoryTotals.length, (i) {
          final ct = _categoryTotals[i];
          final cat = categoryMap[ct.categoryId];
          final fraction = maxTotal > 0 ? ct.total / maxTotal : 0.0;
          final pct =
              _totalSpending > 0 ? (ct.total / _totalSpending * 100) : 0.0;
          final color = Color(cat?.color ?? 0xFF6B6B6B);

          return Padding(
            padding: EdgeInsets.only(
                bottom: i < _categoryTotals.length - 1 ? 16 : 0),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${i + 1}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: i < 3
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: i < 3 ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    getIconData(cat?.icon ?? ''),
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            cat?.name ?? 'Unknown',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(ct.total),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: fraction,
                                minHeight: 6,
                                backgroundColor: colorScheme
                                    .surfaceContainerHighest
                                    .withOpacity(0.5),
                                valueColor: AlwaysStoppedAnimation(color),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 42,
                            child: Text(
                              '${pct.toStringAsFixed(1)}%',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ---------- Shared Card Wrapper ----------

  Widget _buildSectionCard(
    ThemeData theme,
    ColorScheme colorScheme, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w400,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildEmptySection(ThemeData theme, ColorScheme colorScheme,
      String title, IconData icon, String message) {
    return _buildSectionCard(
      theme,
      colorScheme,
      title: title,
      icon: icon,
      child: SizedBox(
        height: 100,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined,
                  size: 32, color: colorScheme.onSurfaceVariant.withOpacity(0.4)),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Monthly Comparison Section ----------

  Widget _buildMonthlyComparisonSection(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '6-Month Spending Trend',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<DailyTotal>>(
              future: _monthlyTotalsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
                }
                final monthData = snapshot.data!;
                final maxTotal = monthData.fold(0.0, (max, d) => d.total > max ? d.total : max);
                final effectiveMax = maxTotal == 0 ? 100.0 : maxTotal * 1.2;

                return SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: effectiveMax,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final idx = group.x.toInt();
                            if (idx < 0 || idx >= monthData.length) return null;
                            final month = monthData[idx];
                            return BarTooltipItem(
                              '${DateFormat('MMM yyyy').format(month.date)}\n${CurrencyFormatter.format(rod.toY)}',
                              TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx >= 0 && idx < monthData.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    DateFormat('MMM').format(monthData[idx].date),
                                    style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      barGroups: List.generate(monthData.length, (index) {
                        final m = monthData[index];
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: m.total,
                              color: colorScheme.primary,
                              width: 16,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<List<DailyTotal>> _getMonthlyTotalsForPast6Months() async {
    final now = DateTime.now();
    final List<DailyTotal> list = [];
    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final start = DateTime(monthDate.year, monthDate.month, 1);
      final end = DateTime(monthDate.year, monthDate.month + 1, 0, 23, 59, 59);
      final total = await ref.read(expenseRepoProvider).getTotalExpenseByDateRange(start, end);
      list.add(DailyTotal(date: monthDate, total: total));
    }
    return list;
  }
}
