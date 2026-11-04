import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';
import 'package:digital_wallet_app/features/wallet/presentation/transaction_details_screen.dart';

class PaymentHistoryScreen extends StatefulWidget {
  PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  String _activeToken = '';

  List<TransactionModel> _transactions = [];
  List<TransactionModel> _filteredTransactions = [];

  bool _isLoading = true;
  bool _isInitialized = false;

  String _selectedFilter = 'All';

  final TextEditingController _searchController = TextEditingController();

  // ==========================================================
  // INITIALIZE TOKEN
  // ==========================================================

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isInitialized) {
      return;
    }

    final Object? args = ModalRoute.of(context)?.settings.arguments;

    if (args is String && args.trim().isNotEmpty) {
      _activeToken = args.trim();
      _isInitialized = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadTransactions();
        }
      });
    } else {
      _isInitialized = true;
      _isLoading = false;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showError('Authentication token is missing. Please login again.');
        }
      });
    }
  }

  // ==========================================================
  // LOAD TRANSACTIONS
  // ==========================================================

  Future<void> _loadTransactions() async {
    if (_activeToken.trim().isEmpty) {
      _showError('Your session has expired. Please login again.');
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final transactions = await WalletService.fetchHistory(_activeToken);

      if (!mounted) return;

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      debugPrint('❌ Payment history error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _transactions = [];
        _filteredTransactions = [];
      });

      _showError('Unable to load payment history.');
    }
  }

  // ==========================================================
  // SEARCH
  // ==========================================================

  void _onSearchChanged(String value) {
    _applyFilters();
  }

  // ==========================================================
  // FILTER
  // ==========================================================

  void _setFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });

    _applyFilters();
  }

  void _applyFilters() {
    final search = _searchController.text.trim().toLowerCase();

    List<TransactionModel> result = List<TransactionModel>.from(_transactions);

    // --------------------------------------------------------
    // STATUS FILTER
    // --------------------------------------------------------

    if (_selectedFilter != 'All') {
      result = result.where((transaction) {
        final status = _statusLabel(transaction).toLowerCase();

        return status == _selectedFilter.toLowerCase();
      }).toList();
    }

    // --------------------------------------------------------
    // SEARCH FILTER
    // --------------------------------------------------------

    if (search.isNotEmpty) {
      result = result.where((transaction) {
        final description = transaction.description.toLowerCase();

        final type = transaction.type.toLowerCase();

        final reference = transaction.referenceId.toLowerCase();

        final amount = transaction.amount.toString();

        return description.contains(search) ||
            type.contains(search) ||
            reference.contains(search) ||
            amount.contains(search);
      }).toList();
    }

    if (!mounted) return;

    setState(() {
      _filteredTransactions = result;
    });
  }

  // ==========================================================
  // STATUS LABEL
  // ==========================================================

  String _statusLabel(TransactionModel transaction) {
    final status = transaction.status.trim().toLowerCase();

    switch (status) {
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

  // ==========================================================
  // STATUS COLOR
  // ==========================================================

  Color _statusColor(TransactionModel transaction) {
    final status = transaction.status.trim().toLowerCase();

    switch (status) {
      case 'completed':
      case 'complete':
      case 'success':
      case 'successful':
        return Colors.greenAccent;

      case 'pending':
      case 'processing':
        return Colors.orangeAccent;

      case 'cancelled':
      case 'canceled':
        return Colors.redAccent;

      case 'failed':
      case 'failure':
        return Colors.redAccent;

      default:
        return Colors.greenAccent;
    }
  }

  // ==========================================================
  // STATUS ICON
  // ==========================================================

  IconData _statusIcon(TransactionModel transaction) {
    final status = transaction.status.trim().toLowerCase();

    switch (status) {
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

  // ==========================================================
  // TRANSACTION COLOR
  // ==========================================================

  Color _transactionColor(TransactionModel transaction) {
    final type = transaction.type.toLowerCase();

    if (type == 'withdrawal' ||
        type == 'bill_payment' ||
        type == 'mobile_topup' ||
        type == 'mobile_top_up' ||
        type == 'transfer_out' ||
        type == 'payment') {
      return Colors.redAccent;
    }

    return Colors.greenAccent;
  }

  // ==========================================================
  // TRANSACTION ICON
  // ==========================================================

  IconData _transactionIcon(TransactionModel transaction) {
    final type = transaction.type.toLowerCase();

    if (type == 'withdrawal' || type == 'withdraw') {
      return LucideIcons.arrowUpFromLine;
    }

    if (type == 'bill_payment' || type == 'bill') {
      return LucideIcons.receipt;
    }

    if (type == 'mobile_topup' ||
        type == 'mobile_top_up' ||
        type == 'top_up' ||
        type == 'top-up') {
      return LucideIcons.smartphone;
    }

    if (type == 'transfer_out') {
      return LucideIcons.arrowUpRight;
    }

    if (type == 'transfer_in') {
      return LucideIcons.arrowDownLeft;
    }

    if (type == 'transfer' || type == 'p2p' || type == 'p2p_transfer') {
      return LucideIcons.arrowLeftRight;
    }

    if (type == 'deposit') {
      return LucideIcons.arrowDownToLine;
    }

    if (type == 'qr_payment' || type == 'qr') {
      return LucideIcons.qrCode;
    }

    if (type == 'wallet_transfer' || type == 'transfer_between') {
      return LucideIcons.arrowLeftRight;
    }

    return LucideIcons.wallet;
  }

  // ==========================================================
  // AMOUNT
  // ==========================================================

  String _formatAmount(TransactionModel transaction) {
    final type = transaction.type.toLowerCase();

    final isNegative =
        type == 'withdrawal' ||
        type == 'withdraw' ||
        type == 'bill_payment' ||
        type == 'bill' ||
        type == 'mobile_topup' ||
        type == 'mobile_top_up' ||
        type == 'top_up' ||
        type == 'top-up' ||
        type == 'transfer_out' ||
        type == 'payment';

    final prefix = isNegative ? '- ' : '+ ';

    return '$prefix\$${transaction.amount.abs().toStringAsFixed(2)}';
  }

  // ==========================================================
  // STATUS BADGE
  // ==========================================================

  Widget _buildStatusBadge(TransactionModel transaction) {
    final color = _statusColor(transaction);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(transaction), color: color, size: 12),
          SizedBox(width: 5),
          Text(
            _statusLabel(transaction),
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // OPEN TRANSACTION DETAILS
  // ==========================================================

  Future<void> _openTransactionDetails(TransactionModel transaction) async {
    if (_activeToken.trim().isEmpty) {
      _showError('Your session has expired. Please login again.');
      return;
    }

    final transactionMap = <String, dynamic>{
      'type': transaction.type,
      'amount': transaction.amount,
      'description': transaction.description,
      'reference_id': transaction.referenceId,
      'created_at': transaction.createdAt,
      'status': transaction.status,
    };

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionDetailsScreen(
          token: _activeToken,
          transaction: transactionMap,
        ),
      ),
    );

    if (!mounted) return;

    // ========================================================
    // TRANSACTION WAS CANCELLED
    // ========================================================

    if (result == true) {
      await _loadTransactions();
    }
  }

  // ==========================================================
  // ERROR
  // ==========================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================================
  // UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    AppColors.dependOnTheme(context);
    return Scaffold(
      backgroundColor: AppColors.adaptiveSurfaceAlt,

      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,

        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(LucideIcons.arrowLeft, color: AppColors.themeText),
        ),

        title: Text(
          'PAYMENT HISTORY',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadTransactions,
            icon: Icon(
              LucideIcons.refreshCw,
              color: AppColors.themeText.withValues(alpha: 0.70),
              size: 20,
            ),
          ),
          SizedBox(width: 8),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.neonPink),
            )
          : RefreshIndicator(
              color: AppColors.neonPink,
              backgroundColor: AppColors.adaptiveSurface,
              onRefresh: _loadTransactions,

              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // ==================================================
                    // HEADER
                    // ==================================================
                    Text(
                      'Transaction History',
                      style: TextStyle(
                        color: AppColors.themeText,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 5),

                    Text(
                      '${_transactions.length} transaction'
                      '${_transactions.length == 1 ? '' : 's'}',

                      style: TextStyle(
                        color: AppColors.themeText.withValues(alpha: 0.54),
                        fontSize: 13,
                      ),
                    ),

                    SizedBox(height: 20),

                    // ==================================================
                    // SEARCH
                    // ==================================================
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.adaptiveSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.themeText.withOpacity(0.05),
                        ),
                      ),

                      child: TextField(
                        controller: _searchController,

                        onChanged: _onSearchChanged,

                        style: TextStyle(
                          color: AppColors.themeText,
                          fontSize: 13,
                        ),

                        cursorColor: AppColors.neonPink,

                        decoration: InputDecoration(
                          hintText: 'Search transactions...',
                          hintStyle: TextStyle(
                            color: AppColors.themeText.withValues(alpha: 0.38),
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            LucideIcons.search,
                            color: AppColors.themeText.withValues(alpha: 0.38),
                            size: 19,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 18),

                    // ==================================================
                    // FILTERS
                    // ==================================================
                    _buildFilters(),

                    SizedBox(height: 20),

                    // ==================================================
                    // TRANSACTION LIST
                    // ==================================================
                    _buildTransactionList(),
                  ],
                ),
              ),
            ),
    );
  }

  // ==========================================================
  // FILTER BUTTONS
  // ==========================================================

  Widget _buildFilters() {
    const filters = ['All', 'Completed', 'Pending', 'Cancelled', 'Failed'];

    return SizedBox(
      height: 38,

      child: ListView.separated(
        scrollDirection: Axis.horizontal,

        itemCount: filters.length,

        separatorBuilder: (_, __) => SizedBox(width: 8),

        itemBuilder: (context, index) {
          final filter = filters[index];

          final selected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () {
              _setFilter(filter);
            },

            child: AnimatedContainer(
              duration: Duration(milliseconds: 180),

              padding: const EdgeInsets.symmetric(horizontal: 14),

              alignment: Alignment.center,

              decoration: BoxDecoration(
                color: selected ? AppColors.royalBlue : AppColors.adaptiveSurface,

                borderRadius: BorderRadius.circular(12),

                border: Border.all(
                  color: selected
                      ? AppColors.royalBlue
                      : AppColors.themeText.withOpacity(0.05),
                ),
              ),

              child: Text(
                filter,

                style: TextStyle(
                  color: selected ? AppColors.themeText : AppColors.themeText.withValues(alpha: 0.54),

                  fontSize: 11,

                  fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // TRANSACTION LIST
  // ==========================================================

  Widget _buildTransactionList() {
    if (_filteredTransactions.isEmpty) {
      return Container(
        width: double.infinity,

        padding: const EdgeInsets.symmetric(vertical: 45, horizontal: 20),

        decoration: BoxDecoration(
          color: AppColors.adaptiveSurface,

          borderRadius: BorderRadius.circular(18),

          border: Border.all(color: AppColors.themeText.withOpacity(0.05)),
        ),

        child: Column(
          children: [
            Icon(LucideIcons.receipt, color: AppColors.themeText.withValues(alpha: 0.24), size: 40),

            SizedBox(height: 14),

            Text(
              _transactions.isEmpty
                  ? 'No transactions yet'
                  : 'No matching transactions',

              style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.54), fontSize: 13),
            ),

            if (_transactions.isNotEmpty) ...[
              SizedBox(height: 6),

              Text(
                'Try changing your search or filter.',
                style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.30), fontSize: 11),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.adaptiveSurface,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: AppColors.themeText.withOpacity(0.05)),
      ),

      child: Column(
        children: List.generate(_filteredTransactions.length, (index) {
          final transaction = _filteredTransactions[index];

          return Column(
            children: [
              _transactionTile(transaction),

              if (index < _filteredTransactions.length - 1)
                Divider(
                  height: 1,
                  color: AppColors.themeText.withOpacity(0.05),
                  indent: 74,
                  endIndent: 15,
                ),
            ],
          );
        }),
      ),
    );
  }

  // ==========================================================
  // TRANSACTION TILE
  // ==========================================================

  Widget _transactionTile(TransactionModel transaction) {
    final transactionColor = _transactionColor(transaction);

    return Material(
      color: Colors.transparent,

      child: InkWell(
        borderRadius: BorderRadius.circular(18),

        onTap: () {
          _openTransactionDetails(transaction);
        },

        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // ==================================================
              // ICON
              // ==================================================
              Container(
                width: 46,
                height: 46,

                decoration: BoxDecoration(
                  color: transactionColor.withOpacity(0.10),

                  shape: BoxShape.circle,
                ),

                child: Icon(
                  _transactionIcon(transaction),

                  color: transactionColor,

                  size: 20,
                ),
              ),

              SizedBox(width: 13),

              // ==================================================
              // DETAILS
              // ==================================================
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      transaction.description.isEmpty
                          ? transaction.type
                          : transaction.description,

                      maxLines: 2,

                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        color: AppColors.themeText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    SizedBox(height: 5),

                    Text(
                      transaction.referenceId.isEmpty
                          ? transaction.createdAt
                          : transaction.referenceId,

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        color: AppColors.themeText.withValues(alpha: 0.38),
                        fontSize: 10,
                      ),
                    ),

                    SizedBox(height: 8),

                    _buildStatusBadge(transaction),
                  ],
                ),
              ),

              SizedBox(width: 10),

              // ==================================================
              // AMOUNT + DATE + CHEVRON
              // ==================================================
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,

                children: [
                  Text(
                    _formatAmount(transaction),

                    style: TextStyle(
                      color: transactionColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 7),

                  Text(
                    _formatDate(transaction.createdAt),

                    style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.30), fontSize: 9),
                  ),

                  SizedBox(height: 5),

                  Icon(
                    LucideIcons.chevronRight,
                    color: AppColors.themeText.withValues(alpha: 0.24),
                    size: 15,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // DATE FORMAT
  // ==========================================================

  String _formatDate(String value) {
    if (value.trim().isEmpty) {
      return '';
    }

    try {
      final date = DateTime.parse(value).toLocal();

      final month = date.month.toString().padLeft(2, '0');

      final day = date.day.toString().padLeft(2, '0');

      final hour = date.hour.toString().padLeft(2, '0');

      final minute = date.minute.toString().padLeft(2, '0');

      return '${date.year}-$month-$day '
          '$hour:$minute';
    } catch (_) {
      return value;
    }
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
