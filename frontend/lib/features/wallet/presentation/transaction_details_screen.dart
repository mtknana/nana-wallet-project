import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';
import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'transaction_receipt_screen.dart';

class TransactionDetailsScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> transaction;

  TransactionDetailsScreen({
    super.key,
    required this.token,
    required this.transaction,
  });

  @override
  State<TransactionDetailsScreen> createState() =>
      _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState extends State<TransactionDetailsScreen> {
  bool _isCancelling = false;

  // ==========================================================
  // TRANSACTION DATA
  // ==========================================================

  String get _type {
    return widget.transaction['type']?.toString() ?? 'transaction';
  }

  double get _amount {
    return double.tryParse(widget.transaction['amount']?.toString() ?? '0') ??
        0.0;
  }

  String get _description {
    return widget.transaction['description']?.toString() ?? '';
  }

  String get _referenceId {
    return widget.transaction['reference_id']?.toString() ??
        widget.transaction['referenceId']?.toString() ??
        '';
  }

  String get _createdAt {
    return widget.transaction['created_at']?.toString() ??
        widget.transaction['createdAt']?.toString() ??
        '';
  }

  String get _currency {
    return widget.transaction['currency']?.toString() ?? 'USD';
  }

  String get _status {
    return widget.transaction['status']?.toString().toLowerCase() ??
        'completed';
  }

  bool get _canCancel {
    return _status == 'completed';
  }

  // ==========================================================
  // FORMAT AMOUNT
  // ==========================================================

  String _formatAmount() {
    return '${_amount.abs().toStringAsFixed(2)} $_currency';
  }

  // ==========================================================
  // FORMAT TYPE
  // ==========================================================

  String _formatType() {
    switch (_type.toLowerCase()) {
      case 'transfer':
      case 'p2p':
      case 'p2p_transfer':
        return 'Money Transfer';

      case 'deposit':
        return 'Deposit';

      case 'withdraw':
      case 'withdrawal':
        return 'Cash Out';

      case 'qr_payment':
      case 'qr':
        return 'QR Payment';

      case 'bill_payment':
      case 'bill':
        return 'Bill Payment';

      case 'mobile_top_up':
      case 'mobile_topup':
      case 'top_up':
      case 'top-up':
        return 'Mobile Top-Up';

      case 'wallet_transfer':
      case 'transfer_between':
        return 'Wallet Transfer';

      case 'payment':
        return 'Payment';

      default:
        if (_type.trim().isEmpty) {
          return 'Transaction';
        }

        return _type
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

  // ==========================================================
  // STATUS COLOR
  // ==========================================================

  Color _statusColor() {
    switch (_status) {
      case 'completed':
      case 'complete':
      case 'success':
      case 'successful':
        return Color(0xFF3DDC97);

      case 'pending':
      case 'processing':
        return Color(0xFFFFC857);

      case 'cancelled':
      case 'canceled':
        return Color(0xFFFF6B6B);

      case 'failed':
      case 'failure':
        return Color(0xFFFF5252);

      default:
        return Color(0xFF8FA3AD);
    }
  }

  // ==========================================================
  // STATUS ICON
  // ==========================================================

  IconData _statusIcon() {
    switch (_status) {
      case 'completed':
      case 'complete':
      case 'success':
      case 'successful':
        return Icons.check_circle_rounded;

      case 'pending':
      case 'processing':
        return Icons.access_time_rounded;

      case 'cancelled':
      case 'canceled':
        return Icons.cancel_rounded;

      case 'failed':
      case 'failure':
        return Icons.error_rounded;

      default:
        return Icons.info_rounded;
    }
  }

  // ==========================================================
  // STATUS LABEL
  // ==========================================================

  String _statusLabel() {
    switch (_status) {
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
        if (_status.isEmpty) {
          return 'Unknown';
        }

        return '${_status[0].toUpperCase()}'
            '${_status.substring(1)}';
    }
  }

  // ==========================================================
  // FORMAT DATE
  // ==========================================================

  String _formatDate(String value) {
    if (value.trim().isEmpty) {
      return 'Not available';
    }

    try {
      final date = DateTime.parse(value).toLocal();

      final hour = date.hour > 12
          ? date.hour - 12
          : date.hour == 0
          ? 12
          : date.hour;

      final minute = date.minute.toString().padLeft(2, '0');

      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}  '
          '$hour:$minute $period';
    } catch (_) {
      return value;
    }
  }

  // ==========================================================
  // VIEW RECEIPT
  // ==========================================================

  Future<void> _openReceipt() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionReceiptScreen(
          token: widget.token,
          transaction: widget.transaction,
        ),
      ),
    );
  }

  // ==========================================================
  // START CANCELLATION
  // ==========================================================

  Future<void> _startCancellation() async {
    if (_isCancelling || !_canCancel) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.adaptiveSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Cancel Transaction?',
            style: TextStyle(color: AppColors.themeText, fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Are you sure you want to cancel this transaction?\n\n'
            'Amount: ${_formatAmount()}\n'
            'Reference: $_referenceId',
            style: TextStyle(color: Color(0xFFB8C5CA), height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(
                'Keep Transaction',
                style: TextStyle(color: Color(0xFF9AAEB7)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF5C5C),
                foregroundColor: AppColors.themeText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                'Continue',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    final pinVerified = await Navigator.pushNamed(
      context,
      '/transaction-pin-verify',
      arguments: widget.token,
    );

    if (!mounted || pinVerified != true) {
      return;
    }

    await _cancelTransaction();
  }

  // ==========================================================
  // CANCEL TRANSACTION
  // ==========================================================

  Future<void> _cancelTransaction() async {
    if (_isCancelling) {
      return;
    }

    setState(() {
      _isCancelling = true;
    });

    try {
      final result = await WalletService.cancelTransaction(
        token: widget.token,
        referenceId: _referenceId,
      );

      if (!mounted) {
        return;
      }

      if (result['status']?.toString().toLowerCase() == 'success') {
        await _showSuccessDialog(result);
      } else {
        _showError(
          result['message']?.toString() ?? 'Unable to cancel this transaction.',
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showError('Unable to cancel transaction. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  // ==========================================================
  // SUCCESS DIALOG
  // ==========================================================

  Future<void> _showSuccessDialog(Map<String, dynamic> result) async {
    final newReference =
        result['transaction']?['reference_id']?.toString() ??
        result['reference_id']?.toString() ??
        'REV-$_referenceId';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.adaptiveSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF3DDC97).withOpacity(0.12),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 42,
                  color: Color(0xFF3DDC97),
                ),
              ),

              SizedBox(height: 20),

              Text(
                'Transaction Cancelled',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),

              SizedBox(height: 10),

              Text(
                'The transaction has been cancelled successfully '
                'and the amount has been restored to your wallet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB8C5CA), height: 1.5),
              ),

              SizedBox(height: 16),

              Text(
                newReference,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF7DD3FC),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),

              SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF3DDC97),
                    foregroundColor: AppColors.adaptiveSurfaceAlt,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }

    Navigator.pop(context, true);
  }

  // ==========================================================
  // ERROR MESSAGE
  // ==========================================================

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.adaptiveSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFF6B6B).withOpacity(0.10),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFFF6B6B),
                  size: 32,
                ),
              ),

              SizedBox(height: 18),

              Text(
                'Something Went Wrong',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),

              SizedBox(height: 10),

              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB8C5CA), height: 1.5),
              ),

              SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF6B6B),
                    foregroundColor: AppColors.themeText,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: Text(
                    'OK',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================
  // DETAIL ROW
  // ==========================================================

  Widget _detailRow({
    required String label,
    required String value,
    bool selectable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: TextStyle(color: Color(0xFF7F929A), fontSize: 13),
            ),
          ),

          SizedBox(width: 10),

          Expanded(
            child: selectable
                ? SelectableText(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppColors.themeText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppColors.themeText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // STATUS BADGE
  // ==========================================================

  Widget _buildStatusBadge() {
    final color = _statusColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(), size: 16, color: color),

          SizedBox(width: 7),

          Text(
            _statusLabel(),
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // VIEW RECEIPT BUTTON
  // ==========================================================

  Widget _buildReceiptButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _openReceipt,
        icon: Icon(LucideIcons.receiptText, size: 18),
        label: Text(
          'VIEW RECEIPT',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Color(0xFF7DD3FC),
          side: BorderSide(color: Color(0xFF7DD3FC).withOpacity(0.25)),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // CANCEL SECTION
  // ==========================================================

  Widget _buildCancelSection() {
    if (!_canCancel) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.themeText.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(_statusIcon(), color: _statusColor(), size: 20),

            SizedBox(width: 10),

            Expanded(
              child: Text(
                'This transaction cannot be cancelled '
                'because its current status is '
                '${_statusLabel().toLowerCase()}.',
                style: TextStyle(
                  color: Color(0xFF9AAEB7),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color(0xFFFF5C5C).withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFFFF5C5C).withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Color(0xFFFF5C5C).withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFF6B6B),
                  size: 21,
                ),
              ),

              SizedBox(width: 12),

              Expanded(
                child: Text(
                  'Cancel this transaction',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          Text(
            'Cancelling this transaction will reverse the '
            'transaction amount and restore it to your wallet.',
            style: TextStyle(
              color: Color(0xFF9AAEB7),
              fontSize: 13,
              height: 1.5,
            ),
          ),

          SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCancelling ? null : _startCancellation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF5C5C),
                disabledBackgroundColor: Color(0xFF3A3032),
                foregroundColor: AppColors.themeText,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isCancelling
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.themeText,
                      ),
                    )
                  : Text(
                      'CANCEL TRANSACTION',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SECURITY NOTICE
  // ==========================================================

  Widget _buildSecurityNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF7DD3FC).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF7DD3FC).withOpacity(0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: Color(0xFF7DD3FC), size: 19),

          SizedBox(width: 10),

          Expanded(
            child: Text(
              'For your security, Transaction PIN verification '
              'is required before cancelling a transaction.',
              style: TextStyle(
                color: Color(0xFF9AAEB7),
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
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
        backgroundColor: AppColors.adaptiveSurfaceAlt,
        elevation: 0,

        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.themeText,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: Text(
          'Transaction Details',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: Column(
            children: [
              SizedBox(height: 12),

              // ==================================================
              // AMOUNT CARD
              // ==================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 28,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: AppColors.adaptiveSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.themeText.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    Text(
                      _formatType(),
                      style: TextStyle(
                        color: Color(0xFF9AAEB7),
                        fontSize: 14,
                      ),
                    ),

                    SizedBox(height: 10),

                    Text(
                      _formatAmount(),
                      style: TextStyle(
                        color: AppColors.themeText,
                        fontSize: 31,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    SizedBox(height: 15),

                    _buildStatusBadge(),
                  ],
                ),
              ),

              SizedBox(height: 18),

              // ==================================================
              // TRANSACTION DETAILS
              // ==================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.adaptiveSurface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.themeText.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    _detailRow(label: 'Type', value: _formatType()),

                    Divider(color: AppColors.themeText.withOpacity(0.05), height: 1),

                    _detailRow(label: 'Amount', value: _formatAmount()),

                    Divider(color: AppColors.themeText.withOpacity(0.05), height: 1),

                    _detailRow(label: 'Status', value: _statusLabel()),

                    Divider(color: AppColors.themeText.withOpacity(0.05), height: 1),

                    _detailRow(
                      label: 'Reference',
                      value: _referenceId.isEmpty
                          ? 'Not available'
                          : _referenceId,
                      selectable: true,
                    ),

                    Divider(color: AppColors.themeText.withOpacity(0.05), height: 1),

                    _detailRow(label: 'Date', value: _formatDate(_createdAt)),

                    if (_description.trim().isNotEmpty) ...[
                      Divider(color: AppColors.themeText.withOpacity(0.05), height: 1),

                      _detailRow(label: 'Description', value: _description),
                    ],
                  ],
                ),
              ),

              SizedBox(height: 20),

              // ==================================================
              // US-039 — VIEW RECEIPT
              // ==================================================
              _buildReceiptButton(),

              SizedBox(height: 20),

              // ==================================================
              // US-038 — CANCEL TRANSACTION
              // ==================================================
              _buildCancelSection(),

              SizedBox(height: 20),

              // ==================================================
              // SECURITY NOTICE
              // ==================================================
              _buildSecurityNotice(),
            ],
          ),
        ),
      ),
    );
  }
}
