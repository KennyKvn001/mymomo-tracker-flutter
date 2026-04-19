import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../models/transaction.dart';
import '../services/sms_service.dart';

class AnalyticsView extends StatefulWidget {
  /// Kept for backwards compatibility with callers that push this view
  /// onto the navigation stack instead of embedding it in the tab shell.
  final bool showBackButton;

  const AnalyticsView({super.key, this.showBackButton = false});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

enum _AnalyticsPeriod { week, month, all, custom }

enum _AnalyticsAccount { momo, mokash }

class _AnalyticsViewState extends State<AnalyticsView> {
  final _smsService = SmsService();
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  String? _error;
  _AnalyticsPeriod _period = _AnalyticsPeriod.month;
  _AnalyticsAccount _account = _AnalyticsAccount.momo;
  DateTimeRange? _customRange;

  static const _bg = Color(0xFFF8F9FA);
  static const _accent = Color(0xFF3D2C8D);
  static const _income = Color(0xFF10B981);
  static const _expense = Color(0xFFF87171);
  static const _payment = Color(0xFFFBBF24);

  // MoMo wallet visual identity (matches the MoMo credit card on Home).
  static const _momoStart = Color(0xFF1A1A2E);
  static const _momoEnd = Color(0xFF3D2C8D);

  // MoKash savings visual identity (matches the MoKash credit card on Home).
  static const _mokashStart = Color(0xFF0F766E);
  static const _mokashEnd = Color(0xFF10B981);

  bool get _isMokash => _account == _AnalyticsAccount.mokash;

  String get _accountLabel => _isMokash ? 'MoKash' : 'MTN MoMo';

  IconData get _accountIcon =>
      _isMokash ? LucideIcons.piggyBank : LucideIcons.smartphone;

  List<Color> get _accountGradient => _isMokash
      ? const [_mokashStart, _mokashEnd]
      : const [_momoStart, _momoEnd];

  Color get _accountTint => _isMokash ? _mokashEnd : _momoEnd;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final txs = await _smsService.getTransactions();
      if (!mounted) return;
      setState(() {
        _transactions = txs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Period helpers
  // ---------------------------------------------------------------------------

  DateTime _periodStart(DateTime now) {
    switch (_period) {
      case _AnalyticsPeriod.week:
        return now.subtract(const Duration(days: 7));
      case _AnalyticsPeriod.month:
        return DateTime(now.year, now.month);
      case _AnalyticsPeriod.all:
        return DateTime(2000);
      case _AnalyticsPeriod.custom:
        return _customRange?.start ?? DateTime(2000);
    }
  }

  /// Inclusive end of the active period (start of the day after) — used
  /// when filtering so transactions on the last day are kept.
  DateTime? _periodEndExclusive() {
    if (_period != _AnalyticsPeriod.custom || _customRange == null) {
      return null;
    }
    final end = _customRange!.end;
    return DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
  }

  String _periodLabel() {
    switch (_period) {
      case _AnalyticsPeriod.week:
        return 'This week';
      case _AnalyticsPeriod.month:
        return 'This month';
      case _AnalyticsPeriod.all:
        return 'All time';
      case _AnalyticsPeriod.custom:
        if (_customRange == null) return 'Custom';
        return '${_shortDate(_customRange!.start)} – ${_shortDate(_customRange!.end)}';
    }
  }

  Future<void> _choosePeriod() async {
    HapticFeedback.selectionClick();
    final picked = await showModalBottomSheet<_AnalyticsPeriod>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _PeriodPickerSheet(current: _period),
    );
    if (picked == null || !mounted) return;

    if (picked == _AnalyticsPeriod.custom) {
      final now = DateTime.now();
      final initial = _customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          );
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2018),
        lastDate: now,
        initialDateRange: initial,
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _accent,
                  onPrimary: Colors.white,
                ),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
      );
      if (range == null || !mounted) return;
      setState(() {
        _period = _AnalyticsPeriod.custom;
        _customRange = range;
      });
    } else {
      setState(() => _period = picked);
    }
  }

  /// Transactions for the currently selected account.
  List<Transaction> get _accountTransactions =>
      _transactions.where((t) => t.isMokash == _isMokash).toList();

  /// Account-scoped transactions further filtered by the active period.
  List<Transaction> get _filtered {
    final scoped = _accountTransactions;
    if (_period == _AnalyticsPeriod.all) return scoped;
    final start = _periodStart(DateTime.now());
    final endExclusive = _periodEndExclusive();
    return scoped.where((t) {
      if (t.date.isBefore(start)) return false;
      if (endExclusive != null && !t.date.isBefore(endExclusive)) return false;
      return true;
    }).toList();
  }

  void _selectAccount(_AnalyticsAccount account) {
    if (_account == account) return;
    HapticFeedback.selectionClick();
    setState(() => _account = account);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: _accent,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: _accent),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildError(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                  // Keying on the account (not the period) makes the
                  // cards re-mount and replay their entry animations
                  // each time the user switches between MoMo and MoKash,
                  // so the change feels deliberate instead of silent.
                  sliver: SliverToBoxAdapter(
                    key: ValueKey(_account),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildNetFlowCard()
                            .animate()
                            .fade(duration: 320.ms)
                            .slideY(begin: 0.06),
                        const SizedBox(height: 16),
                        _buildBreakdownCard()
                            .animate(delay: 80.ms)
                            .fade(duration: 320.ms)
                            .slideY(begin: 0.06),
                        const SizedBox(height: 16),
                        _buildTopExpensesCard()
                            .animate(delay: 160.ms)
                            .fade(duration: 320.ms)
                            .slideY(begin: 0.06),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (widget.showBackButton) ...[
                    _circleIconButton(
                      icon: LucideIcons.chevronLeft,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Insights',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Analytics',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _circleIconButton(
                icon: LucideIcons.refreshCw,
                onTap: _load,
              ),
            ],
          ).animate().fade().slideY(begin: -0.2),
          const SizedBox(height: 18),
          _buildAccountSwitch()
              .animate(delay: 60.ms)
              .fade(duration: 280.ms)
              .slideY(begin: 0.08),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: _buildPeriodChip(),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip() {
    return GestureDetector(
      onTap: _choosePeriod,
      behavior: HitTestBehavior.opaque,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SizeTransition(
            axis: Axis.horizontal,
            sizeFactor: anim,
            child: child,
          ),
        ),
        child: Container(
          key: ValueKey(_period),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.calendarDays,
                size: 13,
                color: Colors.black.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 6),
              Text(
                _periodLabel(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: Colors.black.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                LucideIcons.chevronsUpDown,
                size: 12,
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSwitch() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _accountSegment(
              account: _AnalyticsAccount.momo,
              label: 'MTN MoMo',
              icon: LucideIcons.smartphone,
              gradient: const [_momoStart, _momoEnd],
            ),
          ),
          Expanded(
            child: _accountSegment(
              account: _AnalyticsAccount.mokash,
              label: 'MoKash',
              icon: LucideIcons.piggyBank,
              gradient: const [_mokashStart, _mokashEnd],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountSegment({
    required _AnalyticsAccount account,
    required String label,
    required IconData icon,
    required List<Color> gradient,
  }) {
    final isSelected = _account == account;
    return GestureDetector(
      onTap: () => _selectAccount(account),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                )
              : null,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? Colors.white
                  : Colors.black.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                  color: isSelected
                      ? Colors.white
                      : Colors.black.withValues(alpha: 0.65),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 18),
        color: Colors.black87,
        onPressed: onTap,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Net flow hero card
  // ---------------------------------------------------------------------------

  Widget _buildNetFlowCard() {
    final txs = _filtered;
    double income = 0;
    double expense = 0;
    for (final t in txs) {
      if (t.isIncoming) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    final net = income - expense;
    final isUp = net >= 0;
    final spots = _dailyNetSpots(txs);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _accountGradient,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _accountTint.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Icon(
                              _accountIcon,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${_accountLabel.toUpperCase()} · ${_periodLabel().toUpperCase()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isUp ? _income : _expense)
                            .withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isUp
                                ? LucideIcons.trendingUp
                                : LucideIcons.trendingDown,
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isMokash
                                ? (isUp ? 'Growing' : 'Drawing')
                                : (isUp ? 'Saving' : 'Spending'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        txs.isEmpty
                            ? '—'
                            : '${isUp ? '+' : '-'}${_formatAmount(net.abs())}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        'RWF',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  txs.isEmpty
                      ? 'No transactions in this window'
                      : 'Across ${txs.length} transactions',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 70,
                  child: spots.length < 2
                      ? Center(
                          child: Text(
                            'Not enough activity to chart',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            borderData: FlBorderData(show: false),
                            lineTouchData:
                                const LineTouchData(enabled: false),
                            minY: spots
                                    .map((e) => e.y)
                                    .reduce((a, b) => a < b ? a : b) -
                                1,
                            maxY: spots
                                    .map((e) => e.y)
                                    .reduce((a, b) => a > b ? a : b) +
                                1,
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                curveSmoothness: 0.32,
                                preventCurveOverShooting: true,
                                barWidth: 2.4,
                                color: Colors.white,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.30),
                                      Colors.white.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _isMokash
                        ? 'Deposits in − withdrawals out'
                        : 'Money in − money out',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _miniStat(
                        label: _isMokash ? 'Deposits' : 'Money in',
                        value: income,
                        icon: LucideIcons.arrowDownLeft,
                        tint: _income,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _miniStat(
                        label: _isMokash ? 'Withdrawals' : 'Money out',
                        value: expense,
                        icon: LucideIcons.arrowUpRight,
                        tint: _expense,
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
  }

  Widget _miniStat({
    required String label,
    required double value,
    required IconData icon,
    required Color tint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 13),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _formatAmount(value),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // In/Out breakdown donut
  // ---------------------------------------------------------------------------

  Widget _buildBreakdownCard() {
    final txs = _filtered;
    double income = 0;
    double expense = 0;
    double payment = 0;
    for (final t in txs) {
      if (t.isIncoming) {
        income += t.amount;
      } else if (t.isPayment) {
        payment += t.amount;
      } else {
        expense += t.amount;
      }
    }
    final total = income + expense + payment;

    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Where money moved',
            '$_accountLabel composition',
          ),
          const SizedBox(height: 18),
          if (total == 0)
            _emptyHint('No $_accountLabel activity in this window.')
          else
            Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 42,
                          startDegreeOffset: -90,
                          sections: [
                            if (income > 0)
                              PieChartSectionData(
                                value: income,
                                color: _income,
                                radius: 16,
                                showTitle: false,
                              ),
                            if (expense > 0)
                              PieChartSectionData(
                                value: expense,
                                color: _expense,
                                radius: 16,
                                showTitle: false,
                              ),
                            if (payment > 0)
                              PieChartSectionData(
                                value: payment,
                                color: _payment,
                                radius: 16,
                                showTitle: false,
                              ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${txs.length}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'tx',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.black.withValues(alpha: 0.45),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _legendRowsForAccount(
                      income: income,
                      expense: expense,
                      payment: payment,
                      total: total,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Builds the legend rows for the breakdown donut, using labels that
  /// match the active account's domain (MoMo speaks of payments &
  /// transfers, MoKash speaks of deposits & withdrawals) and dropping
  /// any segment that is zero so the legend doesn't read as noisy.
  List<Widget> _legendRowsForAccount({
    required double income,
    required double expense,
    required double payment,
    required double total,
  }) {
    final entries = <({Color color, String label, double amount})>[
      (
        color: _income,
        label: _isMokash ? 'Deposits' : 'Income',
        amount: income,
      ),
      (
        color: _expense,
        label: _isMokash ? 'Withdrawals' : 'Transfers',
        amount: expense,
      ),
      if (!_isMokash)
        (
          color: _payment,
          label: 'Payments',
          amount: payment,
        ),
    ].where((e) => e.amount > 0).toList();

    final widgets = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      if (i > 0) widgets.add(const SizedBox(height: 12));
      widgets.add(_legendRow(
        color: entries[i].color,
        label: entries[i].label,
        amount: entries[i].amount,
        total: total,
      ));
    }
    return widgets;
  }

  Widget _legendRow({
    required Color color,
    required String label,
    required double amount,
    required double total,
  }) {
    final pct = total == 0 ? 0 : (amount / total) * 100;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_formatAmount(amount)} RWF · ${pct.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Top expenses
  // ---------------------------------------------------------------------------

  Widget _buildTopExpensesCard() {
    final outgoing = _filtered.where((t) => !t.isIncoming).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final top = outgoing.take(5).toList();
    final maxAmount =
        top.isEmpty ? 0.0 : top.first.amount.clamp(1, double.infinity);

    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            _isMokash ? 'Top withdrawals' : 'Top expenses',
            'Largest $_accountLabel outflows in window',
          ),
          const SizedBox(height: 14),
          if (top.isEmpty)
            _emptyHint(
              _isMokash
                  ? 'No MoKash withdrawals in this window.'
                  : 'No outgoing MoMo transactions in this window.',
            )
          else
            Column(
              children: List.generate(top.length, (i) {
                final t = top[i];
                final ratio = (t.amount / maxAmount).clamp(0.05, 1.0);
                return Padding(
                  padding: EdgeInsets.only(bottom: i == top.length - 1 ? 0 : 14),
                  child: _expenseRow(
                    rank: i + 1,
                    label: _shortDescription(t.description),
                    when: _shortDate(t.date),
                    amount: t.amount,
                    barRatio: ratio.toDouble(),
                    isPayment: t.isPayment,
                    kindLabel: _isMokash
                        ? 'Withdrawal'
                        : (t.isPayment ? 'Payment' : 'Transfer'),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _expenseRow({
    required int rank,
    required String label,
    required String when,
    required double amount,
    required double barRatio,
    required bool isPayment,
    required String kindLabel,
  }) {
    final accent = isPayment ? _payment : _expense;
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$rank',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatAmount(amount)} RWF',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: barRatio,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFF1F3F5),
                  color: accent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$kindLabel · $when',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Shared UI bits
  // ---------------------------------------------------------------------------

  Widget _whiteCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.black,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Colors.black.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.circleAlert,
              size: 36, color: _expense),
          const SizedBox(height: 12),
          const Text(
            'Could not load analytics',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _error ?? '',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withValues(alpha: 0.55),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pure helpers
  // ---------------------------------------------------------------------------

  /// Builds a daily net (income - expense) series across the active window,
  /// using a small number of buckets so the sparkline reads cleanly even
  /// when the underlying data has gaps.
  List<FlSpot> _dailyNetSpots(List<Transaction> txs) {
    if (txs.isEmpty) return const [];
    final now = DateTime.now();
    final start = _period == _AnalyticsPeriod.all
        ? (txs.map((t) => t.date).reduce((a, b) => a.isBefore(b) ? a : b))
        : _periodStart(now);
    final spanDays = math.max(1, now.difference(start).inDays);
    final buckets = math.min(spanDays + 1, 30);
    final bucketSizeMs =
        (now.millisecondsSinceEpoch - start.millisecondsSinceEpoch) / buckets;
    if (bucketSizeMs <= 0) return const [];

    final values = List<double>.filled(buckets, 0);
    for (final t in txs) {
      final offset = t.date.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
      if (offset < 0) continue;
      var idx = (offset / bucketSizeMs).floor();
      if (idx >= buckets) idx = buckets - 1;
      values[idx] += t.isIncoming ? t.amount : -t.amount;
    }

    return List.generate(
      buckets,
      (i) => FlSpot(i.toDouble(), values[i]),
    );
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  String _shortDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  String _shortDescription(String raw) {
    if (raw.isEmpty) return 'Transaction';
    var s = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Strip common SMS prefixes that don't help identify the merchant.
    final prefixes = [
      RegExp(r'^\*\d+\*\d+#\s*', caseSensitive: false),
      RegExp(r"^Y'ello[\.,]?\s*", caseSensitive: false),
      RegExp(r'^MTN[ -]?Rwandacell\s*', caseSensitive: false),
    ];
    for (final p in prefixes) {
      s = s.replaceFirst(p, '');
    }
    if (s.length > 40) s = '${s.substring(0, 40).trimRight()}…';
    return s;
  }
}

/// Bottom-sheet picker for the active analytics window. Pops the
/// chosen [_AnalyticsPeriod] back to the caller; when the user picks
/// `custom`, the caller is responsible for then opening the date
/// range picker.
class _PeriodPickerSheet extends StatelessWidget {
  final _AnalyticsPeriod current;

  const _PeriodPickerSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Show data for',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 14),
            _option(
              context,
              icon: LucideIcons.calendarRange,
              label: 'This week',
              value: _AnalyticsPeriod.week,
            ),
            _option(
              context,
              icon: LucideIcons.calendar,
              label: 'This month',
              value: _AnalyticsPeriod.month,
            ),
            _option(
              context,
              icon: LucideIcons.infinity,
              label: 'All time',
              value: _AnalyticsPeriod.all,
            ),
            const Divider(height: 22, thickness: 1),
            _option(
              context,
              icon: LucideIcons.calendarClock,
              label: 'Custom range…',
              value: _AnalyticsPeriod.custom,
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required IconData icon,
    required String label,
    required _AnalyticsPeriod value,
  }) {
    final isSelected = current == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).pop(value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFF4F1FB)
                      : const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? const Color(0xFF3D2C8D)
                      : Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  LucideIcons.check,
                  size: 16,
                  color: Color(0xFF3D2C8D),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
