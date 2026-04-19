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
  bool _hideBalance = true;
  final PageController _insightsController = PageController();
  int _currentInsight = 0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void dispose() {
    _insightsController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final transactions = await _smsService.getTransactions();

      final momoTxs =
          transactions.where((t) => !t.isMokash && t.balance != null);
      final momoBalance =
          momoTxs.isNotEmpty ? momoTxs.first.balance : null;

      final mokashTxs =
          transactions.where((t) => t.isMokash && t.balance != null);
      final mokashBalance =
          mokashTxs.isNotEmpty ? mokashTxs.first.balance : null;

      setState(() {
        _transactions = transactions;
        _momoBalance = momoBalance;
        _mokashBalance = mokashBalance;
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
                                  color:
                                      Colors.white.withValues(alpha: 0.65),
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
                        onTap: () => setState(
                            () => _hideBalance = !_hideBalance),
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
                            _hideBalance
                                ? LucideIcons.eyeOff
                                : LucideIcons.eye,
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
                                    ? (_hideBalance
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
                                  color:
                                      Colors.white.withValues(alpha: 0.75),
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
                                    color:
                                        Colors.white.withValues(alpha: 0.7),
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

  List<({
    String tag,
    String primary,
    String secondary,
    IconData icon,
    String detail,
  })> _insights() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month);
    final monthly = _transactions
        .where((t) => !t.date.isBefore(startOfMonth))
        .toList();

    double income = 0;
    double expense = 0;
    for (final t in monthly) {
      if (t.isIncoming) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    final net = income - expense;
    final netInsight = (
      tag: net >= 0 ? 'NET SAVINGS · THIS MONTH' : 'NET SPEND · THIS MONTH',
      primary: monthly.isEmpty
          ? '—'
          : '${net >= 0 ? '+' : '-'}${_formatAmount(net.abs())}',
      secondary: monthly.isEmpty
          ? 'No activity yet this month'
          : _inflowOutflowLine(income, expense),
      icon: LucideIcons.wallet,
      detail: monthly.isEmpty
          ? 'Once transactions come in, your net flow will appear here.'
          : 'Across ${monthly.length} transactions. Income ${_formatAmount(income)} RWF, expenses ${_formatAmount(expense)} RWF.',
    );

    final sortedByAmount = [...monthly]
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final top = sortedByAmount.isNotEmpty ? sortedByAmount.first : null;
    final biggestInsight = (
      tag: 'LARGEST · THIS MONTH',
      primary: top != null ? _formatAmount(top.amount) : '—',
      secondary: top != null
          ? '${_truncate(top.description, 34)} · ${_shortDate(top.date)}'
          : 'No transactions yet',
      icon: top != null && top.isIncoming
          ? LucideIcons.arrowDownLeft
          : LucideIcons.arrowUpRight,
      detail: top != null
          ? '${top.isIncoming ? 'Received' : 'Sent'} on ${_shortDate(top.date)}. ${top.description}.'
          : 'Your biggest move will show up here.',
    );

    final dayTotals = <int, double>{};
    for (final t in _transactions) {
      dayTotals[t.date.weekday] =
          (dayTotals[t.date.weekday] ?? 0) + t.amount;
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
      tag: 'MOST ACTIVE · ALL TIME',
      primary: topDay != null ? dayNames[topDay! - 1] : '—',
      secondary: topDay != null
          ? '${_formatAmount(topDayValue)} RWF moved total'
          : 'No rhythm yet',
      icon: LucideIcons.calendarDays,
      detail: topDay != null
          ? 'You tend to transact most on ${dayNames[topDay! - 1].toLowerCase()}.'
          : 'Track a few transactions to reveal your rhythm.',
    );

    final momo = _momoBalance ?? 0;
    final mokash = _mokashBalance ?? 0;
    final total = momo + mokash;
    final splitInsight = (
      tag: 'NET WORTH · COMBINED',
      primary: _hideBalance ? '••• •••' : _formatAmount(total),
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

  String _inflowOutflowLine(double income, double expense) {
    return 'in ${_formatAmount(income)} · out ${_formatAmount(expense)}';
  }

  String _truncate(String s, int n) =>
      s.length <= n ? s : '${s.substring(0, n).trimRight()}…';

  String _shortDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  void _openInsightDetail(
    ({
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
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(28)),
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
                  child: Icon(insight.icon,
                      color: Colors.black87, size: 18),
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

  Widget _buildOverview() {
    final insights = _insights();

    return Expanded(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
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
            Row(
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
                Row(
                  children: List.generate(insights.length, (i) {
                    final active = i == _currentInsight;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.only(left: 4),
                      width: active ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.black
                            : Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: PageView.builder(
                controller: _insightsController,
                itemCount: insights.length,
                onPageChanged: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _currentInsight = i);
                },
                itemBuilder: (_, i) => _buildInsightCard(insights[i]),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewAction(
                    label: 'Transact',
                    icon: LucideIcons.arrowRightLeft,
                    isPrimary: true,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const Transactions()),
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
                        const SnackBar(
                            content: Text('Reports coming soon!')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ).animate().fade().slideY(begin: 0.08),
    );
  }

  Widget _buildInsightCard(
    ({
      String tag,
      String primary,
      String secondary,
      IconData icon,
      String detail,
    }) insight,
  ) {
    return GestureDetector(
      onTap: () => _openInsightDetail(insight),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(20),
        ),
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
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(insight.icon,
                          size: 14, color: Colors.black87),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        insight.tag,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    insight.primary,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.secondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ],
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
    final bg = isPrimary ? Colors.black : const Color(0xFFF1F3F5);
    final fg = isPrimary ? Colors.white : Colors.black87;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: fg,
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
