import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../models/transaction.dart';
import '../services/sms_service.dart';

/// Visual identity for each account tab. Keeps colors/labels in one place
/// so the rest of the screen can swap palettes by index alone.
class _AccountTheme {
  const _AccountTheme({
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.softBg,
    required this.icon,
    required this.isMokash,
  });

  final String label;
  final String subtitle;
  final Color accent;
  final Color softBg;
  final IconData icon;
  final bool isMokash;
}

const _momoTheme = _AccountTheme(
  label: 'MoMo',
  subtitle: 'Primary wallet',
  accent: Color(0xFF3D2C8D),
  softBg: Color(0xFFF4F1FB),
  icon: LucideIcons.smartphone,
  isMokash: false,
);

const _mokashTheme = _AccountTheme(
  label: 'MoKash',
  subtitle: 'Savings account',
  accent: Color(0xFF0F766E),
  softBg: Color(0xFFE6F7F4),
  icon: LucideIcons.piggyBank,
  isMokash: true,
);

class Transactions extends StatefulWidget {
  const Transactions({super.key});

  @override
  State<Transactions> createState() => _TransactionsState();
}

class _TransactionsState extends State<Transactions>
    with SingleTickerProviderStateMixin {
  final _smsService = SmsService();
  final _searchController = TextEditingController();
  late final TabController _tabController;

  List<Transaction> _transactions = [];
  List<Transaction> _filteredTransactions = [];
  bool _isLoading = true;
  String? _error;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final transactions = await _smsService.getTransactions();
      setState(() {
        _transactions = transactions;
        _filterTransactions();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterTransactions() {
    final query = _searchController.text.toLowerCase();
    _filteredTransactions = _transactions.where((t) {
      final matchesSearch = query.isEmpty ||
          t.description.toLowerCase().contains(query) ||
          (t.reference?.toLowerCase().contains(query) ?? false);
      final matchesDate = _selectedDateRange == null ||
          (t.date.isAfter(_selectedDateRange!.start) &&
              t.date.isBefore(
                  _selectedDateRange!.end.add(const Duration(days: 1))));
      return matchesSearch && matchesDate;
    }).toList();
  }

  Future<void> _selectDateRange() async {
    HapticFeedback.lightImpact();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
      builder: (context, child) => _DatePickerTheme(child: child!),
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _filterTransactions();
      });
    }
  }

  List<Transaction> _txForTheme(_AccountTheme theme) =>
      _filteredTransactions.where((t) => t.isMokash == theme.isMokash).toList();

  _AccountTheme get _activeTheme =>
      _tabController.index == 0 ? _momoTheme : _mokashTheme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadTransactions,
          color: _activeTheme.accent,
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildAccountTabs(),
              const SizedBox(height: 14),
              _buildSearchBar(),
              if (_selectedDateRange != null) _buildDateChip(),
              const SizedBox(height: 14),
              _buildSummary(),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTransactionsList(_momoTheme),
                    _buildTransactionsList(_mokashTheme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          _CircleIconButton(
            icon: LucideIcons.arrowLeft,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transactions',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_transactions.length} total · ${_filteredTransactions.length} shown',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          _CircleIconButton(
            icon: LucideIcons.calendarDays,
            onTap: _selectDateRange,
            highlight: _selectedDateRange != null,
          ),
        ],
      ).animate().fade().slideY(begin: -0.1),
    );
  }

  Widget _buildAccountTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          indicatorPadding: const EdgeInsets.all(4),
          dividerColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            _accountTab(_momoTheme),
            _accountTab(_mokashTheme),
          ],
        ),
      ),
    ).animate().fade(delay: 60.ms).slideY(begin: 0.1);
  }

  Widget _accountTab(_AccountTheme theme) {
    final isSelected = _activeTheme.isMokash == theme.isMokash;
    final count = _txForTheme(theme).length;
    return Tab(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            theme.icon,
            size: 14,
            color: isSelected ? theme.accent : Colors.black54,
          ),
          const SizedBox(width: 8),
          Text(theme.label),
          const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.accent.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isSelected ? theme.accent : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (_) => setState(_filterTransactions),
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search description or reference…',
            hintStyle: TextStyle(
              color: Colors.black.withValues(alpha: 0.4),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 8),
              child: Icon(
                LucideIcons.search,
                size: 16,
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(_filterTransactions);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Icon(
                        LucideIcons.x,
                        size: 16,
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
            suffixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          ),
        ),
      ),
    ).animate().fade(delay: 120.ms).slideY(begin: 0.1);
  }

  Widget _buildDateChip() {
    final start = DateFormat('MMM d').format(_selectedDateRange!.start);
    final end = DateFormat('MMM d, y').format(_selectedDateRange!.end);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedDateRange = null;
              _filterTransactions();
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _activeTheme.softBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.calendar,
                    size: 12, color: _activeTheme.accent),
                const SizedBox(width: 6),
                Text(
                  '$start — $end',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _activeTheme.accent,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(LucideIcons.x, size: 12, color: _activeTheme.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    if (_isLoading || _error != null) return const SizedBox.shrink();

    final theme = _activeTheme;
    final items = _txForTheme(theme);

    double income = 0;
    double expenses = 0;
    double payments = 0;
    for (final t in items) {
      if (t.isIncoming) {
        income += t.amount;
      } else if (t.isPayment) {
        payments += t.amount;
      } else {
        expenses += t.amount;
      }
    }

    final cards = <Widget>[
      _StatCard(
        label: theme.isMokash ? 'Deposits' : 'Income',
        amount: income,
        icon: LucideIcons.arrowDownLeft,
        color: const Color(0xFF10B981),
      ),
      _StatCard(
        label: theme.isMokash ? 'Withdrawals' : 'Expenses',
        amount: expenses,
        icon: LucideIcons.arrowUpRight,
        color: const Color(0xFFEF4444),
      ),
      // Payments tracking is MoMo-only — MoKash never makes merchant payments.
      if (!theme.isMokash)
        _StatCard(
          label: 'Payments',
          amount: payments,
          icon: LucideIcons.creditCard,
          color: const Color(0xFFF59E0B),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    ).animate(key: ValueKey(theme.isMokash)).fade(duration: 220.ms);
  }

  Widget _buildTransactionsList(_AccountTheme theme) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(theme.accent),
        ),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    final items = _txForTheme(theme);
    if (items.isEmpty) {
      return _buildEmptyState(theme);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildTransactionCard(items[i], theme),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFDECEC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                LucideIcons.triangleAlert,
                color: Color(0xFFEF4444),
                size: 22,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              "Couldn't load transactions",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loadTransactions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D2C8D),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Try again',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(_AccountTheme theme) {
    final hasFilters =
        _searchController.text.isNotEmpty || _selectedDateRange != null;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.softBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(theme.icon, color: theme.accent, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'Nothing matches' : 'No ${theme.label} activity yet',
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Try clearing the search or date range.'
                  : 'New transactions from this account will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Colors.black.withValues(alpha: 0.55),
                height: 1.4,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _searchController.clear();
                    _selectedDateRange = null;
                    _filterTransactions();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.softBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Clear filters',
                    style: TextStyle(
                      color: theme.accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Transaction tx, _AccountTheme theme) {
    final formatter = NumberFormat('#,##0', 'en_US');
    final amountColor = tx.isIncoming
        ? const Color(0xFF10B981)
        : tx.isPayment
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);
    final iconBg = tx.isIncoming
        ? const Color(0xFFE6F8F1)
        : tx.isPayment
            ? const Color(0xFFFFF4E0)
            : const Color(0xFFFDECEC);
    final iconData = tx.isPayment
        ? LucideIcons.creditCard
        : tx.isIncoming
            ? LucideIcons.arrowDownLeft
            : LucideIcons.arrowUpRight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openTransactionDetail(tx, theme),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(iconData, color: amountColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tx.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.clock,
                          size: 11,
                          color: Colors.black.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            DateFormat('MMM d, y · HH:mm').format(tx.date),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.black.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${tx.amountPrefix}${formatter.format(tx.amount)}',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: amountColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'RWF',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openTransactionDetail(Transaction tx, _AccountTheme theme) {
    HapticFeedback.lightImpact();
    final formatter = NumberFormat('#,##0', 'en_US');
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
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
                    color: theme.softBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(theme.icon, color: theme.accent, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  '${theme.label} · ${tx.isIncoming ? "Incoming" : tx.isPayment ? "Payment" : "Outgoing"}',
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
              '${tx.amountPrefix}${formatter.format(tx.amount)} RWF',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: tx.displayColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('EEEE, MMM d, y · HH:mm').format(tx.date),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 20),
            _DetailRow(label: 'Description', value: tx.description),
            if (tx.balance != null)
              _DetailRow(
                label: '${theme.label} balance after',
                value: '${formatter.format(tx.balance!)} RWF',
              ),
            if (tx.reference != null && tx.reference!.isNotEmpty)
              _DetailRow(label: 'Reference', value: tx.reference!),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFFF4F1FB) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: highlight
                ? const Color(0xFF3D2C8D).withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 16,
          color: highlight ? const Color(0xFF3D2C8D) : Colors.black87,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black.withValues(alpha: 0.55),
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${formatter.format(amount)} RWF',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps the Material date-range picker so its surface, header, buttons,
/// and selection chips match the rest of the app (light background,
/// deep-purple accent, rounded corners) instead of Material's default
/// dark filled header.
class _DatePickerTheme extends StatelessWidget {
  const _DatePickerTheme({required this.child});

  final Widget child;

  static const _accent = Color(0xFF3D2C8D);
  static const _accentSoft = Color(0xFFEDE9FB);
  static const _ink = Color(0xFF1A1A2E);
  static const _inkMuted = Color(0xFF6B6B80);
  static const _surface = Color(0xFFF6F4FB);

  @override
  Widget build(BuildContext context) {
    final lightBase = ThemeData.light(useMaterial3: true);
    final colorScheme = const ColorScheme.light(
      brightness: Brightness.light,
      primary: _accent,
      onPrimary: Colors.white,
      primaryContainer: _accentSoft,
      onPrimaryContainer: _ink,
      secondary: _accent,
      onSecondary: Colors.white,
      secondaryContainer: _accentSoft,
      onSecondaryContainer: _ink,
      tertiary: _accent,
      onTertiary: Colors.white,
      tertiaryContainer: _accentSoft,
      onTertiaryContainer: _ink,
      error: Color(0xFFB3261E),
      onError: Colors.white,
      errorContainer: Color(0xFFFADBD7),
      onErrorContainer: Color(0xFF410E0B),
      surface: Colors.white,
      onSurface: _ink,
      surfaceContainerHighest: _surface,
      surfaceContainerHigh: _surface,
      surfaceContainer: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainerLowest: Colors.white,
      onSurfaceVariant: _inkMuted,
      outline: Color(0xFFE2E0EC),
      outlineVariant: Color(0xFFE2E0EC),
      inverseSurface: _ink,
      onInverseSurface: Colors.white,
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: _accent,
    );

    final textTheme = lightBase.textTheme.apply(
      bodyColor: _ink,
      displayColor: _ink,
    );

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: colorScheme,
        textTheme: textTheme,
        primaryTextTheme: textTheme,
        scaffoldBackgroundColor: Colors.white,
        canvasColor: Colors.white,
        dividerColor: const Color(0xFFE2E0EC),
        iconTheme: const IconThemeData(color: _ink),
        primaryIconTheme: const IconThemeData(color: _ink),
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: _ink,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: _ink),
          titleTextStyle: TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: _accent,
            textStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            elevation: 0,
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: _ink),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _surface,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          hintStyle: const TextStyle(
            color: _inkMuted,
            fontWeight: FontWeight.w500,
          ),
          labelStyle: const TextStyle(
            color: _inkMuted,
            fontWeight: FontWeight.w600,
          ),
          floatingLabelStyle: const TextStyle(
            color: _accent,
            fontWeight: FontWeight.w700,
          ),
          // Force the actual typed-in characters to be dark, otherwise the
          // input-mode date fields render as white on white.
          prefixStyle: const TextStyle(color: _ink),
          suffixStyle: const TextStyle(color: _ink),
          counterStyle: const TextStyle(color: _inkMuted),
          helperStyle: const TextStyle(color: _inkMuted),
          errorStyle: const TextStyle(color: Color(0xFFB3261E)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _accent, width: 1.5),
          ),
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          headerBackgroundColor: Colors.white,
          headerForegroundColor: _ink,
          headerHeadlineStyle: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: _ink,
          ),
          headerHelpStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: _inkMuted,
          ),
          weekdayStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: _inkMuted,
          ),
          dayStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
          yearStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
          dayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return _ink.withValues(alpha: 0.32);
            }
            // Range endpoints (filled purple bg) → white text.
            if (states.contains(WidgetState.selected)) return Colors.white;
            // Everything else (normal days + in-range middle days) → dark.
            return _ink;
          }),
          dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return _accent;
            return Colors.transparent;
          }),
          dayOverlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return _accent.withValues(alpha: 0.16);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return _accent.withValues(alpha: 0.10);
            }
            return null;
          }),
          dayShape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          todayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return _ink.withValues(alpha: 0.32);
            }
            if (states.contains(WidgetState.selected)) return Colors.white;
            return _accent;
          }),
          todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return _accent;
            return Colors.transparent;
          }),
          todayBorder: const BorderSide(color: _accent, width: 1.4),
          yearForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return _ink.withValues(alpha: 0.32);
            }
            if (states.contains(WidgetState.selected)) return Colors.white;
            return _ink;
          }),
          yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return _accent;
            return Colors.transparent;
          }),
          yearOverlayColor: WidgetStateProperty.all(
            _accent.withValues(alpha: 0.10),
          ),
          rangePickerBackgroundColor: Colors.white,
          rangePickerSurfaceTintColor: Colors.white,
          rangePickerHeaderBackgroundColor: Colors.white,
          rangePickerHeaderForegroundColor: _ink,
          rangePickerHeaderHeadlineStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: _ink,
          ),
          rangePickerHeaderHelpStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: _inkMuted,
          ),
          rangePickerShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          // The pale band MTN sits between the two endpoints.
          rangeSelectionBackgroundColor: _accentSoft,
          rangeSelectionOverlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return _accent.withValues(alpha: 0.14);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return _accent.withValues(alpha: 0.08);
            }
            return null;
          }),
          rangePickerElevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          confirmButtonStyle: TextButton.styleFrom(
            foregroundColor: _accent,
            textStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          cancelButtonStyle: TextButton.styleFrom(
            foregroundColor: _inkMuted,
            textStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          dividerColor: const Color(0xFFE2E0EC),
        ),
      ),
      child: child,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
