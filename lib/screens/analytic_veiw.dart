import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/sms_service.dart';
import 'package:intl/intl.dart';
import 'charts_screen.dart';

class AnalyticsView extends StatefulWidget {
  final bool showBackButton;

  const AnalyticsView({super.key, this.showBackButton = false});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  final _smsService = SmsService();
  List<Transaction> _transactions = [];
  List<Transaction> _filteredTransactions = [];
  bool _isLoading = true;
  String? _error;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
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
    if (_selectedDateRange == null) {
      _filteredTransactions = List.from(_transactions);
      return;
    }

    _filteredTransactions = _transactions.where((transaction) {
      return transaction.date.isAfter(_selectedDateRange!.start) &&
          transaction.date
              .isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
    }).toList();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _filterTransactions();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTransactions,
              color: Colors.green,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildDateFilter(),
                    _buildOverviewCards(),
                    _buildChartsSection(),
                    _buildInsights(),
                    SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isSmallScreen = screenHeight < 700 || screenWidth < 400;

    return Container(
      padding: EdgeInsets.fromLTRB(
          screenWidth * 0.05,
          statusBarHeight + (isSmallScreen ? 20 : 30),
          screenWidth * 0.05,
          isSmallScreen ? 20 : 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade600,
            Colors.purple.shade400,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.showBackButton) ...[
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: isSmallScreen ? 16 : 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Analytics',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 20 : 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Financial insights & trends',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: GestureDetector(
                        onTap: _selectDateRange,
                        child: Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                          size: isSmallScreen ? 18 : 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: GestureDetector(
                        onTap: _loadTransactions,
                        child: Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: isSmallScreen ? 18 : 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    if (_selectedDateRange == null) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Container(
      margin:
          EdgeInsets.fromLTRB(screenWidth * 0.05, 0, screenWidth * 0.05, 20),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.date_range,
              color: Colors.purple,
              size: isSmallScreen ? 16 : 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Date Range',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.start)} - '
                    '${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedDateRange = null;
                _filterTransactions();
              });
            },
            child: Container(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.all(isSmallScreen ? 4 : 6),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Icon(
                  Icons.close,
                  color: Colors.grey,
                  size: isSmallScreen ? 14 : 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    if (_isLoading) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline,
                color: Colors.red, size: isSmallScreen ? 40 : 48),
            const SizedBox(height: 16),
            Text(
              'Error loading analytics data',
              style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loadTransactions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      );
    }

    double totalIncoming = 0;
    double totalOutgoing = 0;
    double totalPayments = 0;
    double totalBalance = 0;

    for (var transaction in _filteredTransactions) {
      if (transaction.isIncoming) {
        totalIncoming += transaction.amount;
        totalBalance += transaction.amount;
      } else {
        if (transaction.description.toLowerCase().contains('payment of')) {
          totalPayments += transaction.amount;
        } else {
          totalOutgoing += transaction.amount;
        }
        totalBalance -= transaction.amount;
      }
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Financial Overview',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final shouldStackPairs = availableWidth < 300;

              if (shouldStackPairs) {
                return Column(
                  children: [
                    _buildOverviewCard(
                      'Total Balance',
                      totalBalance,
                      totalBalance >= 0 ? Colors.green : Colors.red,
                      Icons.account_balance_wallet,
                      isSmallScreen: isSmallScreen,
                      isFullWidth: true,
                    ),
                    const SizedBox(height: 12),
                    _buildOverviewCard(
                      'Transactions',
                      _filteredTransactions.length.toDouble(),
                      Colors.blue,
                      Icons.receipt_long,
                      isCount: true,
                      isSmallScreen: isSmallScreen,
                      isFullWidth: true,
                    ),
                    const SizedBox(height: 12),
                    _buildOverviewCard(
                      'Income',
                      totalIncoming,
                      Colors.green,
                      Icons.arrow_downward,
                      isSmallScreen: isSmallScreen,
                      isFullWidth: true,
                    ),
                    const SizedBox(height: 12),
                    _buildOverviewCard(
                      'Expenses',
                      totalOutgoing,
                      Colors.red,
                      Icons.arrow_upward,
                      isSmallScreen: isSmallScreen,
                      isFullWidth: true,
                    ),
                    const SizedBox(height: 12),
                    _buildOverviewCard(
                      'Payments',
                      totalPayments,
                      Colors.orange,
                      Icons.payment,
                      isSmallScreen: isSmallScreen,
                      isFullWidth: true,
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildOverviewCard(
                          'Total Balance',
                          totalBalance,
                          totalBalance >= 0 ? Colors.green : Colors.red,
                          Icons.account_balance_wallet,
                          isSmallScreen: isSmallScreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildOverviewCard(
                          'Transactions',
                          _filteredTransactions.length.toDouble(),
                          Colors.blue,
                          Icons.receipt_long,
                          isCount: true,
                          isSmallScreen: isSmallScreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildOverviewCard(
                          'Income',
                          totalIncoming,
                          Colors.green,
                          Icons.arrow_downward,
                          isSmallScreen: isSmallScreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildOverviewCard(
                          'Expenses',
                          totalOutgoing,
                          Colors.red,
                          Icons.arrow_upward,
                          isSmallScreen: isSmallScreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildOverviewCard(
                    'Payments',
                    totalPayments,
                    Colors.orange,
                    Icons.payment,
                    isSmallScreen: isSmallScreen,
                    isFullWidth: true,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
    String title,
    double value,
    Color color,
    IconData icon, {
    bool isCount = false,
    bool isFullWidth = false,
    required bool isSmallScreen,
  }) {
    final formatter = NumberFormat("#,##0", "en_US");

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: isSmallScreen ? 16 : 20,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isCount
                  ? value.toInt().toString()
                  : '${formatter.format(value)} RWF',
              style: TextStyle(
                fontSize: isFullWidth
                    ? (isSmallScreen ? 18 : 20)
                    : (isSmallScreen ? 14 : 16),
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    if (_isLoading || _error != null || _filteredTransactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 400 || screenHeight < 700;

    return Container(
      margin:
          EdgeInsets.fromLTRB(screenWidth * 0.05, 24, screenWidth * 0.05, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Charts & Trends',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: isSmallScreen ? 250 : 300,
                child: ChartScreen(transactions: _filteredTransactions),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsights() {
    if (_isLoading || _error != null || _filteredTransactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    // Calculate insights
    final totalTransactions = _filteredTransactions.length;
    final incomeTransactions =
        _filteredTransactions.where((t) => t.isIncoming).length;
    final expenseTransactions = totalTransactions - incomeTransactions;

    double totalIncome = 0;
    double totalExpenses = 0;

    for (var transaction in _filteredTransactions) {
      if (transaction.isIncoming) {
        totalIncome += transaction.amount;
      } else {
        totalExpenses += transaction.amount;
      }
    }

    final avgIncome =
        incomeTransactions > 0 ? totalIncome / incomeTransactions : 0;
    final avgExpense =
        expenseTransactions > 0 ? totalExpenses / expenseTransactions : 0;

    return Container(
      margin:
          EdgeInsets.fromLTRB(screenWidth * 0.05, 24, screenWidth * 0.05, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insights',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildInsightCard(
            'Transaction Pattern',
            'You have $incomeTransactions income and $expenseTransactions expense transactions',
            Icons.trending_up,
            Colors.blue,
            isSmallScreen,
          ),
          const SizedBox(height: 12),
          _buildInsightCard(
            'Average Income',
            '${NumberFormat("#,##0", "en_US").format(avgIncome)} RWF per transaction',
            Icons.arrow_downward,
            Colors.green,
            isSmallScreen,
          ),
          const SizedBox(height: 12),
          _buildInsightCard(
            'Average Expense',
            '${NumberFormat("#,##0", "en_US").format(avgExpense)} RWF per transaction',
            Icons.arrow_upward,
            Colors.red,
            isSmallScreen,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String title, String description, IconData icon,
      Color color, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: isSmallScreen ? 16 : 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
