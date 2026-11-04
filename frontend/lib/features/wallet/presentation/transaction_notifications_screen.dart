import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';

class TransactionNotificationsScreen extends StatefulWidget {
  final String token;

  TransactionNotificationsScreen({super.key, required this.token});

  @override
  State<TransactionNotificationsScreen> createState() =>
      _TransactionNotificationsScreenState();
}

class _TransactionNotificationsScreenState
    extends State<TransactionNotificationsScreen> {
  bool _isLoading = true;
  List<TransactionModel> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  // ==========================================================
  // LOAD TRANSACTION NOTIFICATIONS
  // US-050 Transaction Notification
  // ==========================================================

  Future<void> _loadNotifications() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final transactions = await WalletService.fetchTransactionNotifications(
        token: widget.token,
      );

      if (!mounted) return;

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Failed to load transaction notifications: $e');

      if (!mounted) return;

      setState(() {
        _transactions = [];
        _isLoading = false;
      });
    }
  }

  // ==========================================================
  // TRANSACTION ICON
  // ==========================================================

  IconData _getTransactionIcon(String type) {
    final normalized = type.toLowerCase();

    if (normalized.contains('transfer')) {
      return LucideIcons.arrowLeftRight;
    }

    if (normalized.contains('deposit')) {
      return LucideIcons.arrowDownToLine;
    }

    if (normalized.contains('withdraw')) {
      return LucideIcons.arrowUpFromLine;
    }

    if (normalized.contains('bill')) {
      return LucideIcons.receipt;
    }

    if (normalized.contains('top')) {
      return LucideIcons.smartphone;
    }

    if (normalized.contains('qr')) {
      return LucideIcons.qrCode;
    }

    if (normalized.contains('fee')) {
      return LucideIcons.badgeDollarSign;
    }

    if (normalized.contains('split')) {
      return LucideIcons.users;
    }

    return LucideIcons.walletCards;
  }

  // ==========================================================
  // TRANSACTION LABEL
  // ==========================================================

  String _getTransactionLabel(String type) {
    final normalized = type.toLowerCase();

    if (normalized.contains('transfer')) {
      return 'TRANSFER';
    }

    if (normalized.contains('deposit')) {
      return 'DEPOSIT';
    }

    if (normalized.contains('withdraw')) {
      return 'WITHDRAWAL';
    }

    if (normalized.contains('bill')) {
      return 'BILL PAYMENT';
    }

    if (normalized.contains('top')) {
      return 'MOBILE TOP-UP';
    }

    if (normalized.contains('qr')) {
      return 'QR PAYMENT';
    }

    if (normalized.contains('fee')) {
      return 'FEE';
    }

    if (normalized.contains('split')) {
      return 'SPLIT BILL';
    }

    return type.toUpperCase();
  }

  // ==========================================================
  // TRANSACTION COLOR
  // ==========================================================

  Color _getTransactionColor(String type) {
    final normalized = type.toLowerCase();

    if (normalized.contains('deposit') ||
        normalized.contains('receive') ||
        normalized.contains('income')) {
      return Colors.greenAccent;
    }

    if (normalized.contains('withdraw') ||
        normalized.contains('transfer') ||
        normalized.contains('payment') ||
        normalized.contains('bill') ||
        normalized.contains('top') ||
        normalized.contains('fee')) {
      return Colors.orangeAccent;
    }

    return AppColors.royalBlue;
  }

  // ==========================================================
  // AMOUNT PREFIX
  // ==========================================================

  String _getAmountPrefix(String type) {
    final normalized = type.toLowerCase();

    if (normalized.contains('deposit') ||
        normalized.contains('receive') ||
        normalized.contains('income')) {
      return '+';
    }

    return '-';
  }

  // ==========================================================
  // DATE FORMAT
  // ==========================================================

  String _formatDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return 'Unknown time';
    }

    try {
      final date = DateTime.parse(value.toString()).toLocal();

      final hour = date.hour == 0
          ? 12
          : date.hour > 12
          ? date.hour - 12
          : date.hour;

      final minute = date.minute.toString().padLeft(2, '0');

      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year} • '
          '$hour:$minute $period';
    } catch (_) {
      return value.toString();
    }
  }

  // ==========================================================
  // STATUS COLOR
  // ==========================================================

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
      case 'successful':
        return Colors.greenAccent;

      case 'pending':
        return Colors.orangeAccent;

      case 'failed':
      case 'cancelled':
      case 'canceled':
        return Colors.redAccent;

      default:
        return AppColors.themeText.withValues(alpha: 0.54);
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    AppColors.dependOnTheme(context);
    return Scaffold(
      backgroundColor: AppColors.adaptiveSurfaceAlt,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Transaction Notifications',
          style: TextStyle(
            color: AppColors.themeText,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadNotifications,
            icon: Icon(LucideIcons.refreshCw, color: AppColors.themeText),
            tooltip: 'Refresh',
          ),
          SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        color: AppColors.royalBlue,
        backgroundColor: AppColors.adaptiveSurface,
        child: _buildBody(),
      ),
    );
  }

  // ==========================================================
  // BODY
  // ==========================================================

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_transactions.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      physics: AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _buildHeaderCard(),

        SizedBox(height: 24),

        Text(
          'RECENT TRANSACTIONS',
          style: TextStyle(
            color: AppColors.themeText.withValues(alpha: 0.70),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
          ),
        ),

        SizedBox(height: 12),

        ..._transactions.map(
          (transaction) => _buildTransactionCard(transaction),
        ),
      ],
    );
  }

  // ==========================================================
  // HEADER CARD
  // ==========================================================

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.royalBlue.withOpacity(0.22),
            AppColors.adaptiveSurface,
          ],
        ),
        border: Border.all(color: AppColors.royalBlue.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.royalBlue.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.bellRing,
              color: AppColors.royalBlue,
              size: 27,
            ),
          ),

          SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:  [
                Text(
                  'Transaction Activity',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Stay informed about recent activity on your NaNa Wallet account.',
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.60),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // TRANSACTION CARD
  // ==========================================================

  Widget _buildTransactionCard(TransactionModel transaction) {
    final color = _getTransactionColor(transaction.type);

    final statusColor = _getStatusColor(transaction.status);

    final icon = _getTransactionIcon(transaction.type);

    final label = _getTransactionLabel(transaction.type);

    final prefix = _getAmountPrefix(transaction.type);

    final isIncoming = prefix == '+';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.adaptiveSurfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.themeText.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),

              SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description.trim().isEmpty
                          ? label
                          : transaction.description,
                      style: TextStyle(
                        color: AppColors.themeText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: 6),

                    _buildSmallBadge(icon: icon, text: label, color: color),
                  ],
                ),
              ),

              SizedBox(width: 10),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$prefix${transaction.symbol}${transaction.formattedAmount}',
                    style: TextStyle(
                      color: isIncoming
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  SizedBox(height: 6),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      transaction.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 15),

          Divider(color: AppColors.themeText.withOpacity(0.06), height: 1),

          SizedBox(height: 14),

          _buildInfoRow(
            icon: LucideIcons.hash,
            label: 'Reference',
            value: transaction.referenceId.isEmpty
                ? 'Not available'
                : transaction.referenceId,
          ),

          SizedBox(height: 11),

          _buildInfoRow(
            icon: LucideIcons.clock3,
            label: 'Time',
            value: _formatDate(transaction.createdAt),
          ),

          SizedBox(height: 11),

          _buildInfoRow(
            icon: LucideIcons.coins,
            label: 'Currency',
            value: transaction.currency,
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SMALL BADGE
  // ==========================================================

  Widget _buildSmallBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // INFO ROW
  // ==========================================================

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.themeText.withValues(alpha: 0.38)),

        SizedBox(width: 10),

        SizedBox(
          width: 82,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.themeText.withValues(alpha: 0.38),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // EMPTY STATE
  // ==========================================================

  Widget _buildEmptyState() {
    return ListView(
      physics: AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(height: 90),

        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.royalBlue.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.bellOff,
              color: AppColors.royalBlue,
              size: 38,
            ),
          ),
        ),

        SizedBox(height: 22),

        Center(
          child: Text(
            'No Transaction Activity',
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        SizedBox(height: 8),

        Center(
          child: Text(
            'Your recent wallet transactions will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.54), fontSize: 13, height: 1.5),
          ),
        ),
      ],
    );
  }
}
