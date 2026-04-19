import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/sms_service.dart';
import 'package:intl/intl.dart';

class Transactions extends StatefulWidget {
  const Transactions({super.key});

  @override
  State<Transactions> createState() => _TransactionsState();
}

class _TransactionsState extends State<Transactions> {
  final _smsService = SmsService();
  final _searchController = TextEditingController();
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

  @override
  void dispose() {
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
    String query = _searchController.text.toLowerCase();

    _filteredTransactions = _transactions.where((transaction) {
      bool matchesSearch = query.isEmpty ||
          transaction.description.toLowerCase().contains(query) ||
          (transaction.reference?.toLowerCase().contains(query) ?? false);

      bool matchesDate = _selectedDateRange == null ||
          (transaction.date.isAfter(_selectedDateRange!.start) &&
              transaction.date.isBefore(
                  _selectedDateRange!.end.add(const Duration(days: 1))));

      return matchesSearch && matchesDate;
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
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        color: Colors.green,
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchAndFilter(),
            _buildSummaryCards(),
            Expanded(
              child: _buildTransactionsList(),
            ),
          ],
        ),
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
          statusBarHeight + (isSmallScreen ? 10 : 20),
          screenWidth * 0.05,
          isSmallScreen ? 15 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade600,
            Colors.blue.shade400,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Transactions',
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
                          'View and manage your transactions',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: isSmallScreen ? 12 : 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
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
                      size: isSmallScreen ? 16 : 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Container(
      padding:
          EdgeInsets.fromLTRB(screenWidth * 0.05, 16, screenWidth * 0.05, 0),
      child: Column(
        children: [
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
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _filterTransactions();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                hintStyle: TextStyle(
                  color: Colors.grey[500],
                  fontSize: isSmallScreen ? 12 : 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey[500],
                  size: isSmallScreen ? 18 : 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() {
                            _filterTransactions();
                          });
                        },
                        child: Icon(
                          Icons.clear,
                          color: Colors.grey[500],
                          size: isSmallScreen ? 18 : 20,
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isSmallScreen ? 12 : 16,
                ),
              ),
              style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
            ),
          ),
          if (_selectedDateRange != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
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
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.date_range,
                      color: Colors.blue,
                      size: isSmallScreen ? 14 : 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.start)} - '
                        '${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 10 : 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
                      padding: EdgeInsets.all(isSmallScreen ? 4 : 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.grey,
                        size: isSmallScreen ? 12 : 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    if (_isLoading || _error != null) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    double totalIncome = 0;
    double totalExpenses = 0;
    double totalPayments = 0;

    for (var transaction in _filteredTransactions) {
      if (transaction.isIncoming) {
        totalIncome += transaction.amount;
      } else {
        if (transaction.isPayment) {
          totalPayments += transaction.amount;
        } else {
          totalExpenses += transaction.amount;
        }
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final shouldStack = availableWidth < 300;

          if (shouldStack) {
            return Column(
              children: [
                _buildSummaryCard(
                  'Income',
                  totalIncome,
                  Colors.green,
                  Icons.arrow_downward,
                  isSmallScreen,
                ),
                const SizedBox(height: 8),
                _buildSummaryCard(
                  'Expenses',
                  totalExpenses,
                  Colors.red,
                  Icons.arrow_upward,
                  isSmallScreen,
                ),
                const SizedBox(height: 8),
                _buildSummaryCard(
                  'Payments',
                  totalPayments,
                  Colors.orange,
                  Icons.payment,
                  isSmallScreen,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Income',
                  totalIncome,
                  Colors.green,
                  Icons.arrow_downward,
                  isSmallScreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Expenses',
                  totalExpenses,
                  Colors.red,
                  Icons.arrow_upward,
                  isSmallScreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Payments',
                  totalPayments,
                  Colors.orange,
                  Icons.payment,
                  isSmallScreen,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    Color color,
    IconData icon,
    bool isSmallScreen,
  ) {
    final formatter = NumberFormat("#,##0", "en_US");

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
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
                padding: EdgeInsets.all(isSmallScreen ? 4 : 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: isSmallScreen ? 12 : 14,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${formatter.format(amount)} RWF',
              style: TextStyle(
                fontSize: isSmallScreen ? 11 : 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: isSmallScreen ? 40 : 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading transactions',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loadTransactions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    vertical: isSmallScreen ? 12 : 16,
                  ),
                ),
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredTransactions.isEmpty) {
      return Container(
        padding: EdgeInsets.all(isSmallScreen ? 30 : 40),
        margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: isSmallScreen ? 40 : 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty || _selectedDateRange != null
                  ? 'No transactions found'
                  : 'No transactions yet',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty || _selectedDateRange != null
                  ? 'Try adjusting your search or date filter'
                  : 'Your transactions will appear here',
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchController.text.isNotEmpty ||
                _selectedDateRange != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _selectedDateRange = null;
                      _filterTransactions();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 12 : 16,
                    ),
                  ),
                  child: const Text('Clear Filters'),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      margin:
          EdgeInsets.fromLTRB(screenWidth * 0.05, 16, screenWidth * 0.05, 0),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _filteredTransactions.length,
        itemBuilder: (context, index) {
          return _buildTransactionCard(_filteredTransactions[index]);
        },
      ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final formatter = NumberFormat("#,##0", "en_US");
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                decoration: BoxDecoration(
                  color: transaction.displayColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  transaction.displayIcon,
                  color: transaction.displayColor,
                  size: isSmallScreen ? 16 : 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: isSmallScreen ? 12 : 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            DateFormat('MMM dd, yyyy • HH:mm')
                                .format(transaction.date),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10 : 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${transaction.amountPrefix}${formatter.format(transaction.amount)} RWF',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 15,
                        fontWeight: FontWeight.bold,
                        color: transaction.displayColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 6 : 8,
                      vertical: isSmallScreen ? 2 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      transaction.reference ?? '',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 8 : 10,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
