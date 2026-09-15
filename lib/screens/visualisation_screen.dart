import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/db_helper.dart';
import '../utils/color_helper.dart';
import '../utils/excel_handler.dart';

class VisualisationScreen extends StatefulWidget {
  final bool isActive;
  const VisualisationScreen({super.key, required this.isActive});

  @override
  State<VisualisationScreen> createState() => _VisualisationScreenState();
}

class _VisualisationScreenState extends State<VisualisationScreen> {
  bool _isLoading = true;
  int _uniqueDatesCount = 0;

  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _dbMinDate;
  DateTime? _dbMaxDate;

  String _groupingMode = 'day'; // 'day', 'week', 'month'
  String _chartType = 'line'; // 'line', 'bar'

  List<Map<String, dynamic>> _filteredExpenses = [];
  Map<String, double> _categoryTotals = {};
  double _totalAmount = 0.0;

  // Chart data properties
  List<String> _xLabels = [];
  Map<String, List<double>> _categoryDataPoints = {};
  Map<String, Color> _categoryColors = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant VisualisationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadData();
    }
  }

  void _setTodayDate() {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    setState(() {
      _startDate = today;
      _endDate = today;
    });
    _loadData();
  }

  void _setThisWeekDate() {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final monday = today.subtract(Duration(days: now.weekday - 1));
    setState(() {
      _startDate = monday;
      _endDate = today;
    });
    _loadData();
  }

  void _setThisMonthDate() {
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final today = DateUtils.dateOnly(now);
    setState(() {
      _startDate = firstOfMonth;
      _endDate = today;
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final all = await DbHelper.instance.getExpenses();
      _uniqueDatesCount = await DbHelper.instance.getUniqueDatesCount();

      if (all.isNotEmpty) {
        _dbMinDate = DateTime.parse(all.first['date'] as String);
        _dbMaxDate = DateTime.parse(all.last['date'] as String);

        // Set default filter range if not already set by user
        _startDate ??= _dbMinDate;
        _endDate ??= _dbMaxDate;

        // Apply filters
        _filteredExpenses = all.where((exp) {
          final date = DateTime.parse(exp['date'] as String);
          return !date.isBefore(_startDate!) && !date.isAfter(_endDate!);
        }).toList();

        _processData();
      } else {
        _dbMinDate = null;
        _dbMaxDate = null;
        _filteredExpenses = [];
        _categoryTotals = {};
        _totalAmount = 0.0;
        _xLabels = [];
        _categoryDataPoints = {};
        _categoryColors = {};
      }
    } catch (e) {
      debugPrint('Error loading visualization data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _processData() {
    // 1. Calculate overall totals per category
    _categoryTotals = {};
    _totalAmount = 0.0;
    for (final exp in _filteredExpenses) {
      final category = exp['category'] as String;
      final amount = exp['amount'] as double;
      _categoryTotals[category] = (_categoryTotals[category] ?? 0.0) + amount;
      _totalAmount += amount;
    }

    // 2. Generate Color Map based on spending ranks
    final primaryColor = Theme.of(context).colorScheme.primary;
    _categoryColors = ColorHelper.getCategoryColorMap(primaryColor, _categoryTotals);

    // 3. Process Line Graph coordinates based on grouping mode
    if (_startDate == null || _endDate == null || _filteredExpenses.isEmpty) return;

    _xLabels = [];
    _categoryDataPoints = {};

    if (_groupingMode == 'day') {
      final days = _getDaysInRange(_startDate!, _endDate!);
      _xLabels = days.map((d) => DateFormat('MM/dd').format(d)).toList();

      for (final cat in _categoryTotals.keys) {
        _categoryDataPoints[cat] = List.filled(days.length, 0.0);
      }

      for (final exp in _filteredExpenses) {
        final date = DateTime.parse(exp['date'] as String);
        final cat = exp['category'] as String;
        final amt = exp['amount'] as double;

        final idx = days.indexWhere((d) => DateUtils.isSameDay(d, date));
        if (idx != -1) {
          _categoryDataPoints[cat]![idx] = amt;
        }
      }
    } else if (_groupingMode == 'week') {
      final weeks = _getWeeksInRange(_startDate!, _endDate!);
      _xLabels = weeks.map((w) => DateFormat('MM/dd').format(w)).toList();

      for (final cat in _categoryTotals.keys) {
        _categoryDataPoints[cat] = List.filled(weeks.length, 0.0);
      }

      for (final exp in _filteredExpenses) {
        final date = DateTime.parse(exp['date'] as String);
        final cat = exp['category'] as String;
        final amt = exp['amount'] as double;

        final weekStart = _startOfWeek(date);
        final idx = weeks.indexWhere((w) => DateUtils.isSameDay(w, weekStart));
        if (idx != -1) {
          _categoryDataPoints[cat]![idx] += amt;
        }
      }
    } else if (_groupingMode == 'month') {
      final months = _getMonthsInRange(_startDate!, _endDate!);
      _xLabels = months.map((m) => DateFormat('MMM yy').format(m)).toList();

      for (final cat in _categoryTotals.keys) {
        _categoryDataPoints[cat] = List.filled(months.length, 0.0);
      }

      for (final exp in _filteredExpenses) {
        final date = DateTime.parse(exp['date'] as String);
        final cat = exp['category'] as String;
        final amt = exp['amount'] as double;

        final monthStart = DateTime(date.year, date.month, 1);
        final idx = months.indexWhere((m) => m.year == monthStart.year && m.month == monthStart.month);
        if (idx != -1) {
          _categoryDataPoints[cat]![idx] += amt;
        }
      }
    }
  }

  // Helper date generators
  List<DateTime> _getDaysInRange(DateTime start, DateTime end) {
    final List<DateTime> days = [];
    DateTime current = DateUtils.dateOnly(start);
    final dateOnlyEnd = DateUtils.dateOnly(end);
    while (!current.isAfter(dateOnlyEnd)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  DateTime _startOfWeek(DateTime date) {
    return DateUtils.dateOnly(date.subtract(Duration(days: date.weekday - 1)));
  }

  List<DateTime> _getWeeksInRange(DateTime start, DateTime end) {
    final List<DateTime> weeks = [];
    DateTime current = _startOfWeek(start);
    final endWeek = _startOfWeek(end);
    while (!current.isAfter(endWeek)) {
      weeks.add(current);
      current = current.add(const Duration(days: 7));
    }
    return weeks;
  }

  List<DateTime> _getMonthsInRange(DateTime start, DateTime end) {
    final List<DateTime> months = [];
    DateTime current = DateTime(start.year, start.month, 1);
    final endMonth = DateTime(end.year, end.month, 1);
    while (!current.isAfter(endMonth)) {
      months.add(current);
      int nextMonth = current.month + 1;
      int nextYear = current.year;
      if (nextMonth > 12) {
        nextMonth = 1;
        nextYear += 1;
      }
      current = DateTime(nextYear, nextMonth, 1);
    }
    return months;
  }

  Future<void> _selectStartDate() async {
    if (_dbMinDate == null) return;
    final initial = _startDate ?? _dbMinDate!;
    final last = _endDate ?? _dbMaxDate!;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _dbMinDate!,
      lastDate: last,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
      _loadData();
    }
  }

  Future<void> _selectEndDate() async {
    if (_dbMaxDate == null) return;
    final initial = _endDate ?? _dbMaxDate!;
    final first = _startDate ?? _dbMinDate!;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: _dbMaxDate!,
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
      _loadData();
    }
  }

  Future<void> _exportData() async {
    try {
      final all = await DbHelper.instance.getExpenses();
      if (all.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data available to export')),
          );
        }
        return;
      }
      final path = await ExcelHandler.exportExpenses(all);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(
              Icons.upload_file_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 48,
            ),
            title: const Text('Data Exported'),
            content: Text('All data successfully exported to your Downloads folder:\n\n$path'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export data: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _importData() async {
    try {
      final rows = await ExcelHandler.importExpenses();
      await DbHelper.instance.importExpenses(rows);
      await _loadData();

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(
              Icons.file_download_done_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 48,
            ),
            title: const Text('Data Imported'),
            content: Text('Successfully imported ${rows.length} transactions.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      String errorMessage = 'Failed to import file';
      if (e.toString().contains('structure_mismatch')) {
        errorMessage = 'Data structure does not match';
      } else if (e.toString().contains('invalid_dates')) {
        errorMessage = 'Invalid dates';
      } else if (e.toString().contains('no_file_selected')) {
        return; // Picker cancelled
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 48,
            ),
            title: const Text('Import Failed'),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Row(
        children: [
          const SizedBox(width: 48),
          Expanded(
            child: Text(
              'Analytics',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'export') {
                _exportData();
              } else if (value == 'import') {
                _importData();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_upload_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Export Data'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_download_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Import Data'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _filteredExpenses.isEmpty
                ? _buildEmptyState()
                : _buildAnalyticsView(),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 40),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.insert_chart_outlined_rounded,
                      size: 80,
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No transactions yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Start recording your transactions to see charts and analytics here.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _importData,
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('Import Mock Data'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Swipe right to go back to entry screen',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsView() {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scrollable Screen Header
            _buildHeader(),
            const SizedBox(height: 8),

            // Date Filter Section
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectStartDate,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'START DATE',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _startDate != null
                                  ? DateFormat('dd MMM yyyy').format(_startDate!)
                                  : 'Select',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: primaryColor.withValues(alpha: 0.5)),
                    Expanded(
                      child: InkWell(
                        onTap: _selectEndDate,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'END DATE',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _endDate != null
                                  ? DateFormat('dd MMM yyyy').format(_endDate!)
                                  : 'Select',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Shortcut Buttons (Today, This week, This month)
            _buildDateShortcuts(),
            const SizedBox(height: 16),

            // Expense Trends Section (Line & Bar charts)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expense Trends',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // Grouping Toggles (Day, Week, Month)
                Row(
                  children: [
                    _buildToggleOption('Day', 'day'),
                    _buildToggleOption('Week', 'week'),
                    _buildToggleOption('Month', 'month'),
                  ],
                ),
                const SizedBox(height: 8),
                // Chart Type Toggles (Line, Bar)
                Row(
                  children: [
                    _buildChartTypeOption('Line', 'line', Icons.show_chart_rounded),
                    _buildChartTypeOption('Bar', 'bar', Icons.bar_chart_rounded),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: _filteredExpenses.isEmpty
                      ? const Center(child: Text('No data in selected range'))
                      : _chartType == 'line'
                          ? LineChart(_buildLineChartData())
                          : BarChart(_buildStackedBarChartData()),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Pie Chart Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Category Distribution',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: _filteredExpenses.isEmpty
                      ? const Center(child: Text('No data in selected range'))
                      : PieChart(_buildPieChartData()),
                ),
                const SizedBox(height: 24),
                const Divider(),
                // Legend / Category Breakdown List
                _buildCategoryLegendList(),
                const Divider(),
                // Total Amount Spent
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Expense',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${_totalAmount.toStringAsFixed(2)}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateShortcuts() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildShortcutButton('Today', _setTodayDate),
          const SizedBox(width: 8),
          _buildShortcutButton('This week', _setThisWeekDate),
          const SizedBox(width: 8),
          _buildShortcutButton('This month', _setThisMonthDate),
        ],
      ),
    );
  }

  Widget _buildShortcutButton(String label, VoidCallback onPressed) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildToggleOption(String label, String mode) {
    final isSelected = _groupingMode == mode;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: ChoiceChip(
        showCheckmark: false,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
          ),
        ),
        selected: isSelected,
        selectedColor: theme.colorScheme.primary,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _groupingMode = mode;
              _processData();
            });
          }
        },
      ),
    );
  }

  Widget _buildChartTypeOption(String label, String type, IconData icon) {
    final isSelected = _chartType == type;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: ChoiceChip(
        showCheckmark: false,
        avatar: Icon(
          icon,
          size: 14,
          color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
        ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
          ),
        ),
        selected: isSelected,
        selectedColor: theme.colorScheme.primary,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _chartType = type;
            });
          }
        },
      ),
    );
  }

  LineChartData _buildLineChartData() {
    final theme = Theme.of(context);
    final List<LineChartBarData> barLines = [];

    _categoryDataPoints.forEach((category, points) {
      final color = _categoryColors[category] ?? Colors.blue;
      final spots = <FlSpot>[];
      for (int i = 0; i < points.length; i++) {
        spots.add(FlSpot(i.toDouble(), points[i]));
      }

      barLines.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: color.withValues(alpha: 0.08),
          ),
        ),
      );
    });

    return LineChartData(
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (touchedSpot) => theme.colorScheme.surfaceContainerHighest,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final catList = _categoryDataPoints.keys.toList();
              final category = catList[spot.barIndex];
              return LineTooltipItem(
                '$category: ₹${spot.y.toStringAsFixed(2)}',
                TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
              );
            }).toList();
          },
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= _xLabels.length) {
                return const SizedBox.shrink();
              }

              // Filter intervals to avoid overlaps
              int labelInterval = 1;
              if (_xLabels.length > 20) {
                labelInterval = (_xLabels.length / 5).ceil();
              } else if (_xLabels.length > 10) {
                labelInterval = 2;
              }

              if (index % labelInterval != 0 && index != _xLabels.length - 1) {
                return const SizedBox.shrink();
              }

              return SideTitleWidget(
                meta: meta,
                child: Text(
                  _xLabels[index],
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 45,
            getTitlesWidget: (value, meta) {
              return SideTitleWidget(
                meta: meta,
                child: Text(
                  '₹${value.toInt()}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
          left: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        ),
      ),
      minX: 0,
      maxX: _xLabels.isEmpty ? 0 : (_xLabels.length - 1).toDouble(),
      lineBarsData: barLines.isEmpty
          ? [
              LineChartBarData(
                spots: [const FlSpot(0, 0)],
                color: Colors.transparent,
              )
            ]
          : barLines,
    );
  }

  BarChartData _buildStackedBarChartData() {
    final theme = Theme.of(context);
    final List<BarChartGroupData> groups = [];

    for (int i = 0; i < _xLabels.length; i++) {
      double currentY = 0;
      final List<BarChartRodStackItem> stackItems = [];

      _categoryDataPoints.forEach((category, points) {
        if (i < points.length) {
          final amount = points[i];
          if (amount > 0) {
            final color = _categoryColors[category] ?? Colors.blue;
            stackItems.add(BarChartRodStackItem(currentY, currentY + amount, color));
            currentY += amount;
          }
        }
      });

      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: currentY == 0 ? 0 : currentY,
              rodStackItems: stackItems,
              width: _xLabels.length > 15 ? 10 : 16,
              borderRadius: BorderRadius.circular(4),
              color: theme.colorScheme.surfaceContainerHighest,
            ),
          ],
        ),
      );
    }

    return BarChartData(
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (group) => theme.colorScheme.surfaceContainerHighest,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final label = groupIndex >= 0 && groupIndex < _xLabels.length ? _xLabels[groupIndex] : '';
            return BarTooltipItem(
              '$label\nTotal: ₹${rod.toY.toStringAsFixed(2)}',
              TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
            );
          },
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= _xLabels.length) {
                return const SizedBox.shrink();
              }

              int labelInterval = 1;
              if (_xLabels.length > 20) {
                labelInterval = (_xLabels.length / 5).ceil();
              } else if (_xLabels.length > 10) {
                labelInterval = 2;
              }

              if (index % labelInterval != 0 && index != _xLabels.length - 1) {
                return const SizedBox.shrink();
              }

              return SideTitleWidget(
                meta: meta,
                child: Text(
                  _xLabels[index],
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 45,
            getTitlesWidget: (value, meta) {
              return SideTitleWidget(
                meta: meta,
                child: Text(
                  '₹${value.toInt()}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
          left: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        ),
      ),
      barGroups: groups.isEmpty
          ? [
              BarChartGroupData(
                x: 0,
                barRods: [BarChartRodData(toY: 0)],
              )
            ]
          : groups,
    );
  }

  PieChartData _buildPieChartData() {
    final List<PieChartSectionData> sections = [];

    _categoryTotals.forEach((category, amount) {
      final color = _categoryColors[category] ?? Colors.blue;
      final double pct = _totalAmount > 0 ? (amount / _totalAmount) * 100 : 0.0;

      sections.add(
        PieChartSectionData(
          color: color,
          value: amount,
          title: '${pct.toStringAsFixed(0)}%',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
          ),
        ),
      );
    });

    return PieChartData(
      sectionsSpace: 2,
      centerSpaceRadius: 40,
      sections: sections.isEmpty
          ? [
              PieChartSectionData(
                color: Colors.grey.shade300,
                value: 1,
                title: '0%',
                radius: 50,
              )
            ]
          : sections,
    );
  }

  Widget _buildCategoryLegendList() {
    final theme = Theme.of(context);
    final sortedCategories = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedCategories.length,
      itemBuilder: (context, index) {
        final entry = sortedCategories[index];
        final category = entry.key;
        final amount = entry.value;
        final color = _categoryColors[category] ?? Colors.blue;
        final pct = _totalAmount > 0 ? (amount / _totalAmount) * 100 : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text(
                '(${pct.toStringAsFixed(1)}%)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
