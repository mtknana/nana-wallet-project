import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';
import 'package:digital_wallet_app/features/wallet/presentation/savings_goal_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/daily_expense_tracker_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/exchange_rates_screen.dart';
import 'package:digital_wallet_app/core/config/api_config.dart';

class WalletDashboardScreen extends StatefulWidget {
  final String? activeToken;

  const WalletDashboardScreen({super.key, this.activeToken});

  @override
  State<WalletDashboardScreen> createState() => _WalletDashboardScreenState();
}

class _WalletDashboardScreenState extends State<WalletDashboardScreen> {
  static const String _baseUrl = ApiConfig.baseUrl;

  List<WalletModel> _wallets = [];
  WalletModel? _activeWallet;
  List<TransactionModel> _recentTransactions = [];

  String _selectedCurrency = 'USD';
  String _activeToken = '';

  bool _isLoading = true;
  bool _isBalanceVisible = true;
  bool _isInitialized = false;

  List<Map<String, dynamic>> _savingsGoals = [];
  bool _isSavingsLoading = false;

  double _todayExpenseUsd = 0;
  double _todayExpenseKhr = 0;
  int _todayExpenseRecords = 0;
  Map<String, double> _todayExpenseCategories = {};
  bool _isExpenseSummaryLoading = false;

  // AUTHENTICATION
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isInitialized) return;

    final Object? args = ModalRoute.of(context)?.settings.arguments;
    final routeToken = args is String ? args.trim() : '';
    final explicitToken = widget.activeToken?.trim() ?? '';

    _activeToken = explicitToken.isNotEmpty ? explicitToken : routeToken;
    _isInitialized = true;

    if (_activeToken.isNotEmpty) {
      debugPrint('Dashboard authentication token: RECEIVED');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadDashboardData();
      });
    } else {
      _isLoading = false;

      debugPrint('Dashboard authentication token: EMPTY');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showErrorAndReturnToLogin();
      });
    }
  }

  // LOAD DASHBOARD
  Future<void> _loadDashboardData() async {
    if (_activeToken.trim().isEmpty) {
      debugPrint('Cannot load dashboard: Empty Auth Token');
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      List<WalletModel> fetchedWallets = [];

      try {
        fetchedWallets = await WalletService.fetchWalletBalances(_activeToken);
      } catch (e) {
        debugPrint('Wallet error: $e');
      }

      List<TransactionModel> fetchedHistory = [];

      try {
        fetchedHistory = await WalletService.fetchHistory(_activeToken);
      } catch (e) {
        debugPrint('History error: $e');
      }

      WalletModel? selectedWallet;

      for (final wallet in fetchedWallets) {
        if (wallet.currency.toUpperCase() == _selectedCurrency.toUpperCase()) {
          selectedWallet = wallet;
          break;
        }
      }

      if (selectedWallet == null && fetchedWallets.isNotEmpty) {
        selectedWallet = fetchedWallets.first;
        _selectedCurrency = selectedWallet.currency.toUpperCase();
      }

      if (!mounted) return;

      setState(() {
        _wallets = fetchedWallets;
        _activeWallet = selectedWallet;
        _recentTransactions = fetchedHistory.take(4).toList();
        _isLoading = false;
      });

      debugPrint('Dashboard wallet data loaded');
      debugPrint('Wallet count: ${_wallets.length}');

      for (final wallet in _wallets) {
        debugPrint('${wallet.currency}: ${wallet.balance}');
      }

      await Future.wait([_loadSavingsGoals(), _loadTodayExpenseSummary()]);
    } catch (e) {
      debugPrint('Dashboard loading exception: $e');

      if (!mounted) return;

      setState(() => _isLoading = false);
      _showError('Unable to load wallet information.');
    }
  }

  // SAVINGS GOALS
  Future<void> _loadSavingsGoals() async {
    if (_activeToken.trim().isEmpty) return;

    if (mounted) setState(() => _isSavingsLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/savings-goals?status=active'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $_activeToken',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Unable to load savings goals.');
      }

      final decoded = jsonDecode(response.body);
      List<dynamic> rawGoals = [];

      if (decoded is List) {
        rawGoals = decoded;
      } else if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];

        if (data is List) {
          rawGoals = data;
        } else if (decoded['goals'] is List) {
          rawGoals = decoded['goals'];
        } else if (data is Map<String, dynamic> && data['goals'] is List) {
          rawGoals = data['goals'];
        }
      }

      final goals = rawGoals
          .whereType<Map>()
          .map((goal) => Map<String, dynamic>.from(goal))
          .where(
            (goal) =>
                (goal['status']?.toString() ?? 'active').toLowerCase() ==
                'active',
          )
          .take(3)
          .toList();

      if (!mounted) return;

      setState(() {
        _savingsGoals = goals;
        _isSavingsLoading = false;
      });
    } catch (e) {
      debugPrint('Savings Goals error: $e');

      if (!mounted) return;

      setState(() {
        _savingsGoals = [];
        _isSavingsLoading = false;
      });
    }
  }

  // TODAY'S EXPENSE SUMMARY
  Future<void> _loadTodayExpenseSummary() async {
    if (_activeToken.trim().isEmpty) return;

    if (mounted) setState(() => _isExpenseSummaryLoading = true);

    try {
      final now = DateTime.now();
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      final uri = Uri.parse(
        '$_baseUrl/expenses/summary',
      ).replace(queryParameters: {'start_date': today, 'end_date': today});

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $_activeToken',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Unable to load expense summary.');
      }

      final decoded = jsonDecode(response.body);
      Map<String, dynamic> summary = {};

      if (decoded is Map<String, dynamic>) {
        if (decoded['data'] is Map<String, dynamic>) {
          summary = Map<String, dynamic>.from(decoded['data']);
        } else {
          summary = decoded;
        }
      }

      final totalUsd = _toDouble(
        summary['total_usd'] ?? summary['usd_total'] ?? summary['totalUSD'],
      );

      final totalKhr = _toDouble(
        summary['total_khr'] ?? summary['khr_total'] ?? summary['totalKHR'],
      );

      final records =
          int.tryParse(
            (summary['records'] ??
                    summary['total_records'] ??
                    summary['count'] ??
                    0)
                .toString(),
          ) ??
          0;

      final categories = <String, double>{};
      final rawCategories = summary['by_category'];

      if (rawCategories is Map) {
        rawCategories.forEach((key, value) {
          categories[key.toString().toLowerCase()] = _extractCategoryAmount(
            value,
          );
        });
      } else if (rawCategories is List) {
        for (final item in rawCategories) {
          if (item is Map) {
            final category = item['category']?.toString() ?? '';

            if (category.isNotEmpty) {
              categories[category.toLowerCase()] = _extractCategoryAmount(item);
            }
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _todayExpenseUsd = totalUsd;
        _todayExpenseKhr = totalKhr;
        _todayExpenseRecords = records;
        _todayExpenseCategories = categories;
        _isExpenseSummaryLoading = false;
      });
    } catch (e) {
      debugPrint('Expense summary error: $e');

      if (!mounted) return;

      setState(() {
        _todayExpenseUsd = 0;
        _todayExpenseKhr = 0;
        _todayExpenseRecords = 0;
        _todayExpenseCategories = {};
        _isExpenseSummaryLoading = false;
      });
    }
  }

  // NUMBER HELPERS
  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _extractCategoryAmount(dynamic value) {
    if (value is num) return value.toDouble();

    if (value is Map) {
      return _toDouble(
        value['total'] ?? value['amount'] ?? value['total_amount'],
      );
    }

    return _toDouble(value);
  }

  // CHANGE CURRENCY
  void _selectCurrency(String currency) {
    WalletModel? selectedWallet;

    for (final wallet in _wallets) {
      if (wallet.currency.toUpperCase() == currency.toUpperCase()) {
        selectedWallet = wallet;
        break;
      }
    }

    if (selectedWallet == null) {
      _showError('$currency wallet is not available.');
      return;
    }

    setState(() {
      _selectedCurrency = currency.toUpperCase();
      _activeWallet = selectedWallet;
    });
  }

  // NAVIGATION
  Future<void> _openPage(String route) async {
    if (_activeToken.trim().isEmpty) {
      _showError('Your session has expired. Please login again.');
      return;
    }

    await Navigator.pushNamed(context, route, arguments: _activeToken);

    if (mounted) _loadDashboardData();
  }

  Future<void> _openSavingsGoals() async {
    if (_activeToken.trim().isEmpty) {
      _showError('Your session has expired. Please login again.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SavingsGoalScreen(activeToken: _activeToken),
      ),
    );

    if (mounted) _loadSavingsGoals();
  }

  Future<void> _openExpenseTracker() async {
    if (_activeToken.trim().isEmpty) {
      _showError('Your session has expired. Please login again.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailyExpenseTrackerScreen(activeToken: _activeToken),
      ),
    );

    if (mounted) _loadTodayExpenseSummary();
  }

  // US-085: EXCHANGE RATES
  Future<void> _openExchangeRates() async {
    if (_activeToken.trim().isEmpty) {
      _showError('Your session has expired. Please login again.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExchangeRatesScreen(token: _activeToken),
      ),
    );

    if (mounted) _loadDashboardData();
  }

  // US-086: SPENDING PREDICTION
  Future<void> _openSpendingPrediction() async {
    if (_activeToken.trim().isEmpty) {
      _showError('Your session has expired. Please login again.');
      return;
    }

    await Navigator.pushNamed(
      context,
      '/spending-prediction',
      arguments: _activeToken,
    );

    if (mounted) _loadDashboardData();
  }

  // ERRORS
  void _showErrorAndReturnToLogin() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Authentication token is missing. Please login again.'),
        backgroundColor: Colors.redAccent,
      ),
    );

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  // TRANSACTION HELPERS
  Color _transactionColor(TransactionModel transaction) {
    final type = transaction.type.toLowerCase();

    if ([
      'withdrawal',
      'bill_payment',
      'mobile_topup',
      'transfer_out',
      'payment',
    ].contains(type)) {
      return Colors.redAccent;
    }

    return Colors.green;
  }

  IconData _transactionIcon(TransactionModel transaction) {
    switch (transaction.type.toLowerCase()) {
      case 'withdrawal':
        return LucideIcons.arrowUpFromLine;
      case 'bill_payment':
        return LucideIcons.receipt;
      case 'mobile_topup':
        return LucideIcons.smartphone;
      case 'transfer_out':
        return LucideIcons.arrowUpRight;
      case 'transfer_in':
        return LucideIcons.arrowDownLeft;
      case 'deposit':
        return LucideIcons.arrowDownToLine;
      default:
        return LucideIcons.wallet;
    }
  }

  String _formatAmount(TransactionModel transaction) {
    final type = transaction.type.toLowerCase();

    final isNegative = [
      'withdrawal',
      'bill_payment',
      'mobile_topup',
      'transfer_out',
      'payment',
    ].contains(type);

    final prefix = isNegative ? '- ' : '+ ';
    final currency = transaction.currency.toUpperCase();
    final formatted = transaction.amount.toStringAsFixed(2);
    final parts = formatted.split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    final withCommas = integerPart.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );

    if (currency == 'KHR') {
      return '$prefix៛$withCommas.$decimalPart';
    }

    return '$prefix\$$withCommas.$decimalPart';
  }

  String _statusLabel(TransactionModel transaction) {
    switch (transaction.status.trim().toLowerCase()) {
      case 'completed':
      case 'complete':
      case 'success':
      case 'successful':
        return 'Completed';
      case 'pending':
      case 'processing':
        return 'Pending';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      case 'failed':
      case 'failure':
        return 'Failed';
      default:
        return 'Completed';
    }
  }

  Color _statusColor(TransactionModel transaction) {
    switch (transaction.status.trim().toLowerCase()) {
      case 'completed':
      case 'complete':
      case 'success':
      case 'successful':
        return Colors.green;
      case 'pending':
      case 'processing':
        return Colors.orange;
      case 'cancelled':
      case 'canceled':
      case 'failed':
      case 'failure':
        return Colors.redAccent;
      default:
        return Colors.green;
    }
  }

  IconData _statusIcon(TransactionModel transaction) {
    switch (transaction.status.trim().toLowerCase()) {
      case 'completed':
      case 'complete':
      case 'success':
      case 'successful':
        return LucideIcons.circleCheck;
      case 'pending':
      case 'processing':
        return LucideIcons.clock3;
      case 'cancelled':
      case 'canceled':
        return LucideIcons.circleX;
      case 'failed':
      case 'failure':
        return LucideIcons.triangleAlert;
      default:
        return LucideIcons.circleCheck;
    }
  }

  Widget _buildStatusBadge(TransactionModel transaction) {
    final color = _statusColor(transaction);

    return Container(
      constraints: const BoxConstraints(maxWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(transaction), color: color, size: 11),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _statusLabel(transaction),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatWalletBalance(double balance, String currency) {
    final formatted = balance.toStringAsFixed(2);
    final parts = formatted.split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    final withCommas = integerPart.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );

    if (currency.toUpperCase() == 'KHR') {
      return '៛ $withCommas.$decimalPart';
    }

    return '\$ $withCommas.$decimalPart';
  }

  // NOTIFICATIONS
  Widget _buildNotificationButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => _openPage('/transaction-notifications'),
          icon: Icon(
            LucideIcons.bell,
            color: AppColors.themeText.withValues(alpha: 0.70),
            size: 20,
          ),
        ),
        Positioned(
          right: 7,
          top: 6,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.neonPink,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.adaptiveSurfaceAlt,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // QUICK ACTIONS
  Widget _quickActionItem({
    required IconData icon,
    required String label,
    required String route,
  }) {
    final colors = Theme.of(context).colorScheme;
    final compact = MediaQuery.of(context).size.width < 380;

    return Expanded(
      child: InkWell(
        onTap: () => _openPage(route),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            children: [
              Container(
                width: compact ? 46 : 54,
                height: compact ? 46 : 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: 0.10),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.72),
                    width: 1.3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.10),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: colors.primary,
                  size: compact ? 19 : 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: compact ? 9 : 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // BOTTOM NAVIGATION
  Widget _bottomNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final color = selected ? colors.primary : colors.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 21, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    final colors = Theme.of(context).colorScheme;
    final compact = MediaQuery.of(context).size.width < 380;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 82,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: EdgeInsets.fromLTRB(
              compact ? 8 : 14,
              0,
              compact ? 8 : 14,
              8,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 4 : 7,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colors.onSurface.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                _bottomNavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  onTap: () {},
                  selected: true,
                ),
                _bottomNavItem(
                  icon: LucideIcons.chartNoAxesColumnIncreasing,
                  label: 'Analytics',
                  onTap: _openExpenseTracker,
                ),
                Expanded(
                  child: Center(
                    child: Transform.translate(
                      offset: Offset(0, compact ? -6 : -9),
                      child: Material(
                        color: colors.primary,
                        shape: const CircleBorder(),
                        elevation: 8,
                        shadowColor: colors.primary.withValues(alpha: 0.45),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _openPage('/pay-qr'),
                          child: SizedBox(
                            width: compact ? 46 : 54,
                            height: compact ? 46 : 54,
                            child: Icon(
                              LucideIcons.scanQrCode,
                              color: colors.onPrimary,
                              size: compact ? 20 : 23,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _bottomNavItem(
                  icon: LucideIcons.wallet,
                  label: 'Wallet',
                  onTap: () => _openPage('/wallet'),
                ),
                _bottomNavItem(
                  icon: LucideIcons.userRound,
                  label: 'Profile',
                  onTap: () => _openPage('/profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // MAIN BUILD
  @override
  Widget build(BuildContext context) {
    AppColors.dependOnTheme(context);

    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: _buildBottomNavigationBar(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'NaNa Wallet',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadDashboardData,
            icon: Icon(
              LucideIcons.refreshCw,
              color: AppColors.themeText.withValues(alpha: 0.70),
              size: 20,
            ),
          ),
          IconButton(
            tooltip: 'NaNa Assistant',
            onPressed: () => _openPage('/chatbot'),
            icon: Icon(
              Icons.chat_bubble_outline,
              color: AppColors.themeText.withValues(alpha: 0.70),
              size: 20,
            ),
          ),
          _buildNotificationButton(),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => _openPage('/settings'),
            icon: Icon(
              LucideIcons.settings,
              color: AppColors.themeText.withValues(alpha: 0.70),
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildDashboardBody(colors),
    );
  }

  // SHARED DASHBOARD BODY
  Widget _buildDashboardBody(ColorScheme colors) {
    return RefreshIndicator(
      color: colors.primary,
      backgroundColor: colors.surface,
      onRefresh: _loadDashboardData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: colors.primary,
                  backgroundColor: colors.onSurface.withValues(alpha: 0.08),
                ),
              ),
            ),
          Text(
            'Welcome back,',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            _activeWallet?.name ?? 'User Account',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 22),
          _buildBalanceCard(),
          const SizedBox(height: 28),
          Text(
            'Quick Actions',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _quickActionItem(
                icon: LucideIcons.arrowUpRight,
                label: 'Send',
                route: '/p2p-transfer',
              ),
              _quickActionItem(
                icon: LucideIcons.arrowDownLeft,
                label: 'Request',
                route: '/receive-money',
              ),
              _quickActionItem(
                icon: LucideIcons.scanQrCode,
                label: 'Scan & Pay',
                route: '/pay-qr',
              ),
              _quickActionItem(
                icon: LucideIcons.smartphone,
                label: 'Top Up',
                route: '/top-up',
              ),
            ],
          ),
          const SizedBox(height: 28),
          _buildSavingsGoalsSection(),
          const SizedBox(height: 24),
          _buildTodayExpensesSection(),
          const SizedBox(height: 28),
          _buildMoreActions(),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent Transactions',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _openPage('/payment-history'),
                child: Text(
                  'See All',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTransactions(),
        ],
      ),
    );
  }

  // DARK MODE BALANCE CARD
  Widget _buildBalanceCard() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final wallet = _activeWallet;
    final currency = wallet?.currency ?? _selectedCurrency;
    final balance = wallet?.balance ?? 0;

    final balanceLabel = wallet == null
        ? (_isLoading ? 'Loading balance…' : 'Balance unavailable')
        : _formatWalletBalance(balance, currency);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? [
                  AppColors.adaptiveSurface,
                  AppColors.royalBlue.withValues(alpha: 0.35),
                  AppColors.neonPink.withValues(alpha: 0.16),
                ]
              : const [Color(0xFFE2F7ED), Color(0xFFF7FCF9), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.primary.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: dark ? 0.12 : 0.10),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Available Balance',
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.60),
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                onPressed: () =>
                    setState(() => _isBalanceVisible = !_isBalanceVisible),
                icon: Icon(
                  _isBalanceVisible ? LucideIcons.eye : LucideIcons.eyeOff,
                  color: AppColors.themeText.withValues(alpha: 0.70),
                  size: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _isBalanceVisible ? balanceLabel : '••••••••',
                maxLines: 1,
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _buildCurrencySwitcher(),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _balanceAction(
                  icon: LucideIcons.banknoteArrowUp,
                  label: 'Cash Out',
                  onTap: () => _openPage('/withdraw'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // USD / KHR SWITCHER
  Widget _buildCurrencySwitcher() {
    return Row(
      children: [
        Expanded(child: _currencyButton('USD')),
        const SizedBox(width: 10),
        Expanded(child: _currencyButton('KHR')),
      ],
    );
  }

  Widget _currencyButton(String currency) {
    final selected = _selectedCurrency.toUpperCase() == currency;
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _selectCurrency(currency),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.royalBlue.withValues(alpha: dark ? 0.25 : 0.12)
              : colors.onSurface.withValues(alpha: dark ? 0.14 : 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.royalBlue
                : colors.onSurface.withValues(alpha: 0.10),
          ),
        ),
        child: Center(
          child: Text(
            currency,
            style: TextStyle(
              color: selected
                  ? AppColors.themeText
                  : AppColors.themeText.withValues(alpha: 0.54),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.7,
            ),
          ),
        ),
      ),
    );
  }

  Widget _balanceAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colors.onSurface.withValues(alpha: dark ? 0.15 : 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.onSurface.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.themeText, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: AppColors.themeText,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // SAVINGS GOALS
  Widget _buildSavingsGoalsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Savings Goals',
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: _openSavingsGoals,
              child: Text(
                'See All',
                style: TextStyle(
                  color: AppColors.royalBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isSavingsLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: _cardDecoration(),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.neonPink,
                ),
              ),
            ),
          )
        else if (_savingsGoals.isEmpty)
          _buildEmptySavingsGoals()
        else
          ..._savingsGoals.map(_buildSavingsGoalCard),
      ],
    );
  }

  Widget _buildEmptySavingsGoals() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.royalBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              LucideIcons.target,
              color: AppColors.royalBlue,
              size: 21,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No active savings goals',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start saving toward something important.',
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.54),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _openSavingsGoals,
            child: Text(
              'Create',
              style: TextStyle(
                color: AppColors.neonPink,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsGoalCard(Map<String, dynamic> goal) {
    final name = goal['name']?.toString() ?? 'Savings Goal';
    final currency = goal['currency']?.toString().toUpperCase() ?? 'USD';
    final current = _toDouble(goal['current_amount']);
    final target = _toDouble(goal['target_amount']);

    double progress = _toDouble(goal['progress_percentage']);

    if (progress <= 0 && target > 0) {
      progress = (current / target) * 100;
    }

    progress = progress.clamp(0, 100);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.royalBlue.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  LucideIcons.target,
                  color: AppColors.royalBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${progress.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: AppColors.neonPink,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 7,
              backgroundColor: AppColors.themeText.withValues(alpha: 0.07),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonPink),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_formatSimpleMoney(current, currency)} saved',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.70),
                    fontSize: 10,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  '${_formatSimpleMoney(target, currency)} target',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.54),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatSimpleMoney(double amount, String currency) {
    if (currency == 'KHR') {
      return '៛${_addCommas(amount.toStringAsFixed(0))}';
    }

    return '\$${_addCommas(amount.toStringAsFixed(2))}';
  }

  String _addCommas(String value) {
    final parts = value.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? '.${parts[1]}' : '';

    final formatted = integerPart.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );

    return '$formatted$decimalPart';
  }

  // TODAY'S EXPENSES
  Widget _buildTodayExpensesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "Today's Expenses",
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: _openExpenseTracker,
              child: Text(
                'See All',
                style: TextStyle(
                  color: AppColors.royalBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isExpenseSummaryLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: _cardDecoration(),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.neonPink,
                ),
              ),
            ),
          )
        else
          _buildExpenseSummaryCard(),
      ],
    );
  }

  Widget _buildExpenseSummaryCard() {
    final hasExpenses =
        _todayExpenseRecords > 0 ||
        _todayExpenseUsd > 0 ||
        _todayExpenseKhr > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.adaptiveSurface,
            AppColors.neonPink.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.themeText.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.neonPink.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  LucideIcons.chartNoAxesColumnIncreasing,
                  color: AppColors.neonPink,
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasExpenses ? 'Spent today' : 'No expenses today',
                      style: TextStyle(
                        color: AppColors.themeText,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasExpenses
                          ? '$_todayExpenseRecords expense record${_todayExpenseRecords == 1 ? '' : 's'}'
                          : 'Your daily spending will appear here.',
                      style: TextStyle(
                        color: AppColors.themeText.withValues(alpha: 0.54),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasExpenses) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _expenseCurrencySummary(
                    currency: 'USD',
                    amount: _todayExpenseUsd,
                    symbol: '\$',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _expenseCurrencySummary(
                    currency: 'KHR',
                    amount: _todayExpenseKhr,
                    symbol: '៛',
                  ),
                ),
              ],
            ),
            if (_todayExpenseCategories.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildExpenseCategoryChips(),
            ],
          ],
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openExpenseTracker,
              icon: const Icon(LucideIcons.walletCards, size: 16),
              label: const Text(
                'Manage Daily Expenses',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.themeText.withValues(alpha: 0.70),
                side: BorderSide(
                  color: AppColors.themeText.withValues(alpha: 0.08),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _expenseCurrencySummary({
    required String currency,
    required double amount,
    required String symbol,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.adaptiveSurfaceAlt,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currency,
            style: TextStyle(
              color: AppColors.themeText.withValues(alpha: 0.54),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$symbol${_addCommas(amount.toStringAsFixed(currency == 'KHR' ? 0 : 2))}',
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCategoryChips() {
    const categories = ['food', 'transport', 'study', 'other'];

    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: categories.map((category) {
        final amount = _todayExpenseCategories[category] ?? 0;

        if (amount <= 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.themeText.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_categoryLabel(category)} • ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: AppColors.themeText.withValues(alpha: 0.70),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'food':
        return 'Food';
      case 'transport':
        return 'Transport';
      case 'study':
        return 'Study';
      case 'other':
        return 'Other';
      default:
        return category;
    }
  }

  // MORE ACTIONS — ONE HORIZONTAL, SWIPEABLE ROW
  Widget _buildMoreActions() {
    final actions = <Widget>[
      _horizontalActionCard(
        icon: LucideIcons.split,
        title: 'Split Bill',
        subtitle: 'Share expenses',
        onTap: () => _openPage('/split-bill'),
      ),
      _horizontalActionCard(
        icon: LucideIcons.arrowLeftRight,
        title: 'Wallet Transfer',
        subtitle: 'Move money',
        onTap: () => _openPage('/wallet-transfer'),
      ),
      _horizontalActionCard(
        icon: LucideIcons.qrCode,
        title: 'My QR',
        subtitle: 'Receive payments',
        onTap: () => _openPage('/my-qr'),
      ),
      _horizontalActionCard(
        icon: LucideIcons.smartphone,
        title: 'Mobile Top-Up',
        subtitle: 'Top up phone',
        onTap: () => _openPage('/top-up'),
      ),
      _horizontalActionCard(
        icon: LucideIcons.receiptText,
        title: 'Pay Bills',
        subtitle: 'Pay services',
        onTap: () => _openPage('/pay-bill'),
      ),
      _horizontalActionCard(
        icon: LucideIcons.banknoteArrowUp,
        title: 'Cash Out',
        subtitle: 'Withdraw money',
        onTap: () => _openPage('/withdraw'),
      ),
      _horizontalActionCard(
        icon: LucideIcons.calendarClock,
        title: 'Scheduled Payment',
        subtitle: 'Manage payments',
        onTap: () => _openPage('/scheduled-payment'),
      ),
      _horizontalActionCard(
        icon: LucideIcons.fileDown,
        title: 'PDF Statement',
        subtitle: 'Download statement',
        onTap: () => _openPage('/pdf-statement'),
      ),
      _horizontalActionCard(
        icon: LucideIcons.arrowLeftRight,
        title: 'Exchange Rates',
        subtitle: 'Convert currencies',
        onTap: _openExchangeRates,
      ),
      _horizontalActionCard(
        icon: LucideIcons.handCoins,
        title: 'Quick Loan',
        subtitle: 'Apply for a loan',
        onTap: () => _openPage('/quick-loan'),
      ),
      _horizontalActionCard(
        icon: Icons.chat_bubble_outline,
        title: 'NaNa Assistant',
        subtitle: 'Ask about your wallet',
        onTap: () => _openPage('/chatbot'),
      ),
      _horizontalActionCard(
        icon: LucideIcons.chartNoAxesCombined,
        title: 'Spending Prediction',
        subtitle: 'Forecast expenses',
        onTap: _openSpendingPrediction,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'More Actions',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),

        // A single horizontal list. Swipe left/right to see every card.
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(right: 4, bottom: 2),
            itemCount: actions.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) => actions[index],
          ),
        ),
      ],
    );
  }

  // HORIZONTAL ACTION CARD
  Widget _horizontalActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 148,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.adaptiveSurfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.themeText.withValues(alpha: 0.07),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.royalBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: AppColors.royalBlue, size: 18),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.themeText.withValues(alpha: 0.54),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // TRANSACTIONS
  Widget _buildTransactions() {
    if (_recentTransactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(25),
        decoration: _cardDecoration(),
        child: Column(
          children: [
            Icon(
              LucideIcons.receiptText,
              color: AppColors.themeText.withValues(alpha: 0.30),
              size: 30,
            ),
            const SizedBox(height: 10),
            Text(
              'No recent transactions',
              style: TextStyle(
                color: AppColors.themeText.withValues(alpha: 0.54),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (int i = 0; i < _recentTransactions.length; i++) ...[
            _transactionTile(_recentTransactions[i]),
            if (i != _recentTransactions.length - 1)
              Divider(
                height: 1,
                color: AppColors.themeText.withValues(alpha: 0.05),
              ),
          ],
        ],
      ),
    );
  }

  Widget _transactionTile(TransactionModel transaction) {
    final color = _transactionColor(transaction);
    final icon = _transactionIcon(transaction);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _transactionTitle(transaction),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  transaction.description.trim().isEmpty
                      ? _formatTransactionDate(transaction.createdAt)
                      : transaction.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.54),
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 6),
                _buildStatusBadge(transaction),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _formatAmount(transaction),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _transactionTitle(TransactionModel transaction) {
    final type = transaction.type.trim().toLowerCase();

    switch (type) {
      case 'withdrawal':
        return 'Cash Out';
      case 'deposit':
        return 'Deposit';
      case 'transfer_out':
        return 'Money Sent';
      case 'transfer_in':
        return 'Money Received';
      case 'bill_payment':
        return 'Bill Payment';
      case 'mobile_topup':
        return 'Mobile Top-Up';
      case 'payment':
        return 'Payment';
      default:
        if (transaction.type.trim().isEmpty) {
          return 'Wallet Transaction';
        }

        return transaction.type
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1)}',
            )
            .join(' ');
    }
  }

  String _formatTransactionDate(String rawDate) {
    if (rawDate.trim().isEmpty) return 'Recent transaction';

    try {
      final date = DateTime.parse(rawDate);
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      return '$day/$month/$year';
    } catch (_) {
      return rawDate;
    }
  }

  // COMMON CARD DECORATION
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.adaptiveSurface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.themeText.withValues(alpha: 0.06)),
    );
  }
}
