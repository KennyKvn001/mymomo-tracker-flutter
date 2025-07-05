import 'package:flutter/material.dart';

class BudgetView extends StatefulWidget {
  const BudgetView({super.key});

  @override
  State<BudgetView> createState() => _BudgetViewState();
}

class _BudgetViewState extends State<BudgetView> {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        // Simulate refresh
        await Future.delayed(const Duration(seconds: 1));
      },
      color: Colors.green,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildHeader(),
            _buildComingSoonContent(),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
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
          statusBarHeight + (isSmallScreen ? 20 : 30),
          screenWidth * 0.05,
          isSmallScreen ? 20 : 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade600,
            Colors.orange.shade400,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Budget',
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
                          'Manage your spending & savings',
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
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: isSmallScreen ? 18 : 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComingSoonContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 400 || screenHeight < 700;

    return Container(
      margin:
          EdgeInsets.fromLTRB(screenWidth * 0.05, 40, screenWidth * 0.05, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 40 : 60),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 20 : 30),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    Icons.construction,
                    size: isSmallScreen ? 60 : 80,
                    color: Colors.orange.shade600,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 20 : 30),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Coming Soon!',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 12 : 16),
                Text(
                  'Budget management features are currently under development. Soon you\'ll be able to:',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isSmallScreen ? 20 : 30),
                _buildFeatureList(isSmallScreen),
                SizedBox(height: isSmallScreen ? 20 : 30),
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange.shade600,
                        size: isSmallScreen ? 18 : 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Stay tuned for updates!',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureList(bool isSmallScreen) {
    final features = [
      'Set spending limits for categories',
      'Track your savings goals',
      'Get spending insights & alerts',
      'Create custom budget plans',
      'Monitor monthly expenses',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: features.map((feature) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: EdgeInsets.all(isSmallScreen ? 2 : 3),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: isSmallScreen ? 10 : 12,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  feature,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    color: Colors.grey[700],
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
