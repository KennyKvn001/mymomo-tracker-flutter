import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/transaction.dart';
import '../services/sms_service.dart';
import 'tansactions.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _smsService = SmsService();
  List<Transaction> _transactions = [];
  double? _momoBalance;
  double? _mokashBalance;
  bool _isLoading = true;
  final Set<String> _hiddenCards = {'momo', 'mokash'};
  _OverviewPeriod _period = _OverviewPeriod.month;
  DateTimeRange? _customRange;

  String _cardKey(bool isMokash) => isMokash ? 'mokash' : 'momo';

  bool _isCardHidden(bool isMokash) => _hiddenCards.contains(_cardKey(isMokash));

  void _toggleCardHidden(bool isMokash) {
    final key = _cardKey(isMokash);
    setState(() {
      if (_hiddenCards.contains(key)) {
        _hiddenCards.remove(key);
      } else {
        _hiddenCards.add(key);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final snapshot = await _smsService.getCategorizedTransactions();

      // Log exactly what the cards will display, so the values seen on
      // screen can be cross-checked against the parser output in the
      // terminal.
      developer.log(
        '[HomeView] cards will show -> '
        'MoMo: ${_displayString(snapshot.momoBalance, isMokash: false)}  |  '
        'MoKash: ${_displayString(snapshot.mokashBalance, isMokash: true)}  '
        '(tx total=${snapshot.all.length}, '
        'momo=${snapshot.momo.length}, mokash=${snapshot.mokash.length})',
        name: 'HomeView',
      );

      setState(() {
        _transactions = snapshot.all;
        _momoBalance = snapshot.momoBalance;
        _mokashBalance = snapshot.mokashBalance;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load transactions: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          _buildActionsRow(),
          const SizedBox(height: 14),
          _buildOverview(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good ${_getGreeting()}!',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'My Finances',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
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
                  icon: const Icon(LucideIcons.bell),
                  color: Colors.black87,
                  onPressed: () {},
                ),
              ),
            ],
          ).animate().fade().slideY(begin: -0.2),
          const SizedBox(height: 30),
          _buildAccountCards().animate().fade(delay: 100.ms).slideX(begin: 0.1),
        ],
      ),
    );
  }

  Widget _buildAccountCards() {
    return SizedBox(
      height: 220,
      child: PageView(
        controller: PageController(viewportFraction: 0.9),
        padEnds: false,
        clipBehavior: Clip.none,
        children: [
          _buildCreditCard(
            title: 'MTN MoMo',
            subtitle: 'PRIMARY WALLET',
            balance: _momoBalance,
            themeColors: const [Color(0xFF1A1A2E), Color(0xFF3D2C8D)],
            accentColor: const Color(0xFFFFC107),
            icon: LucideIcons.smartphone,
            isMokash: false,
          ),
          _buildCreditCard(
            title: 'MoKash',
            subtitle: 'SAVINGS ACCOUNT',
            balance: _mokashBalance,
            themeColors: const [Color(0xFF0F766E), Color(0xFF10B981)],
            accentColor: const Color(0xFFFDE68A),
            icon: LucideIcons.piggyBank,
            isMokash: true,
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  /// Returns the string the card actually renders for a balance value:
  /// `---` when null, `••• •••` when hidden, otherwise the formatted amount
  /// with the `RWF` suffix (matching the credit-card layout).
  String _displayString(double? balance, {required bool isMokash}) {
    if (balance == null) return '---';
    if (_isCardHidden(isMokash)) return '••• ••• RWF';
    return '${_formatAmount(balance)} RWF';
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  ({double percent, bool isUp})? _computeTrend({required bool mokash}) {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    final relevant = _transactions
        .where((t) => t.isMokash == mokash && t.date.isAfter(start));
    if (relevant.isEmpty) return null;
    double inflow = 0;
    double outflow = 0;
    for (final t in relevant) {
      if (t.isIncoming) {
        inflow += t.amount;
      } else {
        outflow += t.amount;
      }
    }
    final total = inflow + outflow;
    if (total == 0) return null;
    final net = inflow - outflow;
    return (percent: (net / total).abs() * 100, isUp: net >= 0);
  }

  Transaction? _latestFor({required bool mokash}) {
    for (final t in _transactions) {
      if (t.isMokash == mokash) return t;
    }
    return null;
  }

  Widget _buildCreditCard({
    required String title,
    required String subtitle,
    required double? balance,
    required List<Color> themeColors,
    required Color accentColor,
    required IconData icon,
    required bool isMokash,
  }) {
    final trend = _computeTrend(mokash: isMokash);
    final lastTx = _latestFor(mokash: isMokash);
    final hideBalance = _isCardHidden(isMokash);

    return Container(
      margin: const EdgeInsets.only(right: 16, bottom: 24, top: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: themeColors.last.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: themeColors,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -40,
              right: -30,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.15),
                ),
              ),
            ),
            Positioned(
              top: 60,
              right: -70,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: Icon(icon, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _toggleCardHidden(isMokash),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            hideBalance ? LucideIcons.eyeOff : LucideIcons.eye,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available balance',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (_isLoading)
                        const SizedBox(
                          height: 28,
                          width: 28,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                balance != null
                                    ? (hideBalance
                                        ? '••• •••'
                                        : _formatAmount(balance))
                                    : '---',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
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
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      if (trend != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: (trend.isUp
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFFF87171))
                                .withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                trend.isUp
                                    ? LucideIcons.trendingUp
                                    : LucideIcons.trendingDown,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${trend.isUp ? '+' : '-'}${trend.percent.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 10),
                      if (lastTx != null)
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                lastTx.isIncoming
                                    ? LucideIcons.arrowDownLeft
                                    : LucideIcons.arrowUpRight,
                                color: Colors.white.withValues(alpha: 0.7),
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${_formatAmount(lastTx.amount)} RWF · ${_timeAgo(lastTx.date)}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          'No recent activity',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<
      ({
        String label,
        String tag,
        String primary,
        String secondary,
        IconData icon,
        String detail,
      })> _insights() {
    final now = DateTime.now();
    final start = _periodStart(now);
    final periodTag = _periodTag();
    final endExclusive = _periodEndExclusive();
    final filtered = _period == _OverviewPeriod.all
        ? _transactions
        : _transactions.where((t) {
            if (t.date.isBefore(start)) return false;
            if (endExclusive != null && !t.date.isBefore(endExclusive)) {
              return false;
            }
            return true;
          }).toList();

    double income = 0;
    double expense = 0;
    for (final t in filtered) {
      if (t.isIncoming) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    final net = income - expense;
    final netInsight = (
      label: net >= 0 ? 'Net savings' : 'Net spend',
      tag: '${net >= 0 ? 'NET SAVINGS' : 'NET SPEND'} · $periodTag',
      primary: filtered.isEmpty
          ? '—'
          : '${net >= 0 ? '+' : '-'}${_formatAmount(net.abs())}',
      secondary: filtered.isEmpty
          ? 'No activity in this window'
          : _inflowOutflowLine(income, expense),
      icon: LucideIcons.wallet,
      detail: filtered.isEmpty
          ? 'Once transactions come in, your net flow will appear here.'
          : 'Across ${filtered.length} transactions. Income ${_formatAmount(income)} RWF, expenses ${_formatAmount(expense)} RWF.',
    );

    final sortedByAmount = [...filtered]
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final top = sortedByAmount.isNotEmpty ? sortedByAmount.first : null;
    final biggestInsight = (
      label: 'Largest move',
      tag: 'LARGEST · $periodTag',
      primary: top != null ? _formatAmount(top.amount) : '—',
      secondary: top != null
          ? '${_truncate(top.description, 28)} · ${_shortDate(top.date)}'
          : 'No transactions yet',
      icon: top != null && top.isIncoming
          ? LucideIcons.arrowDownLeft
          : LucideIcons.arrowUpRight,
      detail: top != null
          ? '${top.isIncoming ? 'Received' : 'Sent'} on ${_shortDate(top.date)}. ${top.description}.'
          : 'Your biggest move will show up here.',
    );

    final dayTotals = <int, double>{};
    for (final t in filtered) {
      dayTotals[t.date.weekday] = (dayTotals[t.date.weekday] ?? 0) + t.amount;
    }
    int? topDay;
    double topDayValue = 0;
    dayTotals.forEach((k, v) {
      if (v > topDayValue) {
        topDayValue = v;
        topDay = k;
      }
    });
    const dayNames = [
      'Mondays',
      'Tuesdays',
      'Wednesdays',
      'Thursdays',
      'Fridays',
      'Saturdays',
      'Sundays',
    ];
    final activeInsight = (
      label: 'Most active',
      tag: 'MOST ACTIVE · $periodTag',
      primary: topDay != null ? dayNames[topDay! - 1] : '—',
      secondary: topDay != null
          ? '${_formatAmount(topDayValue)} RWF moved'
          : 'No rhythm yet',
      icon: LucideIcons.calendarDays,
      detail: topDay != null
          ? 'You tend to transact most on ${dayNames[topDay! - 1].toLowerCase()}.'
          : 'Track a few transactions to reveal your rhythm.',
    );

    final momo = _momoBalance ?? 0;
    final mokash = _mokashBalance ?? 0;
    final total = momo + mokash;
    final hideCombined = _isCardHidden(false) || _isCardHidden(true);
    final splitInsight = (
      label: 'Combined balance',
      tag: 'NET WORTH · COMBINED',
      primary: hideCombined ? '••• •••' : _formatAmount(total),
      secondary: total == 0
          ? 'Waiting for balance data'
          : 'MoMo ${(momo / total * 100).toStringAsFixed(0)}%  ·  MoKash ${(mokash / total * 100).toStringAsFixed(0)}%',
      icon: LucideIcons.layers,
      detail: total == 0
          ? 'Once we parse a balance SMS from MTN, this fills in automatically.'
          : 'MoMo: ${_formatAmount(momo)} RWF\nMoKash: ${_formatAmount(mokash)} RWF',
    );

    return [netInsight, biggestInsight, activeInsight, splitInsight];
  }

  DateTime _periodStart(DateTime now) {
    switch (_period) {
      case _OverviewPeriod.week:
        return now.subtract(const Duration(days: 7));
      case _OverviewPeriod.month:
        return DateTime(now.year, now.month);
      case _OverviewPeriod.all:
        return DateTime(2000);
      case _OverviewPeriod.custom:
        return _customRange?.start ?? DateTime(2000);
    }
  }

  /// Inclusive end of the active overview window (start of the day after).
  /// Returns null for non-custom periods, which are treated as open-ended
  /// up to "now".
  DateTime? _periodEndExclusive() {
    if (_period != _OverviewPeriod.custom || _customRange == null) {
      return null;
    }
    final end = _customRange!.end;
    return DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
  }

  String _periodTag() {
    switch (_period) {
      case _OverviewPeriod.week:
        return 'THIS WEEK';
      case _OverviewPeriod.month:
        return 'THIS MONTH';
      case _OverviewPeriod.all:
        return 'ALL TIME';
      case _OverviewPeriod.custom:
        if (_customRange == null) return 'CUSTOM';
        return '${_shortDate(_customRange!.start)} – ${_shortDate(_customRange!.end)}'
            .toUpperCase();
    }
  }

  String _periodLabel() {
    switch (_period) {
      case _OverviewPeriod.week:
        return 'This week';
      case _OverviewPeriod.month:
        return 'This month';
      case _OverviewPeriod.all:
        return 'All time';
      case _OverviewPeriod.custom:
        if (_customRange == null) return 'Custom';
        return '${_shortDate(_customRange!.start)} – ${_shortDate(_customRange!.end)}';
    }
  }

  Future<void> _choosePeriod() async {
    HapticFeedback.selectionClick();
    final picked = await showModalBottomSheet<_OverviewPeriod>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _OverviewPeriodSheet(current: _period),
    );
    if (picked == null || !mounted) return;

    if (picked == _OverviewPeriod.custom) {
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
                  primary: const Color(0xFF3D2C8D),
                  onPrimary: Colors.white,
                ),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
      );
      if (range == null || !mounted) return;
      setState(() {
        _period = _OverviewPeriod.custom;
        _customRange = range;
      });
    } else {
      setState(() => _period = picked);
    }
  }

  String _inflowOutflowLine(double income, double expense) {
    return 'in ${_formatAmount(income)} · out ${_formatAmount(expense)}';
  }

  String _truncate(String s, int n) =>
      s.length <= n ? s : '${s.substring(0, n).trimRight()}…';

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

  void _openInsightDetail(
    ({
      String label,
      String tag,
      String primary,
      String secondary,
      IconData icon,
      String detail,
    }) insight,
  ) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
            const SizedBox(height: 22),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(insight.icon, color: Colors.black87, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  insight.tag,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              insight.primary,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              insight.secondary,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              insight.detail,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildOverviewAction(
              label: 'Transactions',
              icon: LucideIcons.arrowRightLeft,
              isPrimary: true,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const Transactions()),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildOverviewAction(
              label: 'Report',
              icon: LucideIcons.fileChartColumn,
              isPrimary: false,
              onTap: () {
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reports coming soon!')),
                );
              },
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.1);
  }

  Widget _buildOverview() {
    final insights = _insights();

    return Expanded(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: -0.4,
                    ),
                  ),
                  GestureDetector(
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
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F3F5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _periodLabel(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: Colors.black.withValues(alpha: 0.7),
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
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: ListView.separated(
                  key: ValueKey(_period),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  physics: const BouncingScrollPhysics(),
                  itemCount: insights.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.black.withValues(alpha: 0.04),
                  ),
                  itemBuilder: (_, i) => _buildInsightRow(insights[i]),
                ),
              ),
            ),
          ],
        ),
      ).animate().fade().slideY(begin: 0.08),
    );
  }

  Widget _buildInsightRow(
    ({
      String label,
      String tag,
      String primary,
      String secondary,
      IconData icon,
      String detail,
    }) insight,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openInsightDetail(insight),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F1FB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  insight.icon,
                  size: 18,
                  color: const Color(0xFF3D2C8D),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      insight.label,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      insight.secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    insight.primary,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewAction({
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    final accent = isPrimary
        ? const Color(0xFF3D2C8D)
        : Colors.black.withValues(alpha: 0.8);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

enum _OverviewPeriod { week, month, all, custom }

/// Bottom-sheet picker for the Overview window. Pops the chosen period
/// back to the caller; for [_OverviewPeriod.custom] the caller follows
/// up with `showDateRangePicker` to get the actual range.
class _OverviewPeriodSheet extends StatelessWidget {
  final _OverviewPeriod current;

  const _OverviewPeriodSheet({required this.current});

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
              'Show overview for',
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
              value: _OverviewPeriod.week,
            ),
            _option(
              context,
              icon: LucideIcons.calendar,
              label: 'This month',
              value: _OverviewPeriod.month,
            ),
            _option(
              context,
              icon: LucideIcons.infinity,
              label: 'All time',
              value: _OverviewPeriod.all,
            ),
            const Divider(height: 22, thickness: 1),
            _option(
              context,
              icon: LucideIcons.calendarClock,
              label: 'Custom range…',
              value: _OverviewPeriod.custom,
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
    required _OverviewPeriod value,
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
