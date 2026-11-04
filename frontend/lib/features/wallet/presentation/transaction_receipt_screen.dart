import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
class TransactionReceiptScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> transaction;

  TransactionReceiptScreen({
    super.key,
    required this.token,
    required this.transaction,
  });

  @override
  State<TransactionReceiptScreen> createState() =>
      _TransactionReceiptScreenState();
}

class _TransactionReceiptScreenState extends State<TransactionReceiptScreen> {
  bool _isSendingEmail = false;

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

  // ==========================================================
  // TRANSACTION TYPE LABEL
  // ==========================================================

  String get _typeLabel {
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
  // STATUS LABEL
  // ==========================================================

  String get _statusLabel {
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
        if (_status.trim().isEmpty) {
          return 'Unknown';
        }

        return '${_status[0].toUpperCase()}'
            '${_status.substring(1)}';
    }
  }

  // ==========================================================
  // STATUS COLOR
  // ==========================================================

  Color get _statusColor {
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

  IconData get _statusIcon {
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
  // DATE FORMAT
  // ==========================================================

  String get _formattedDate {
    if (_createdAt.trim().isEmpty) {
      return 'Not available';
    }

    try {
      final date = DateTime.parse(_createdAt).toLocal();

      final hour = date.hour > 12
          ? date.hour - 12
          : date.hour == 0
          ? 12
          : date.hour;

      final minute = date.minute.toString().padLeft(2, '0');

      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year} '
          '$hour:$minute $period';
    } catch (_) {
      return _createdAt;
    }
  }

  // ==========================================================
  // RECEIPT NUMBER
  // ==========================================================

  String get _receiptNumber {
    if (_referenceId.trim().isEmpty) {
      return 'NANA-${DateTime.now().millisecondsSinceEpoch}';
    }

    return 'RCPT-$_referenceId';
  }

  // ==========================================================
  // DETAIL ROW
  // ==========================================================

  Widget _detailRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Color(0xFF7F929A), fontSize: 13),
            ),
          ),

          SizedBox(width: 20),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.themeText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // RECEIPT HEADER
  // ==========================================================

  Widget _buildReceiptHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF6675FF), Color(0xFFE85CFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF6675FF).withOpacity(0.25),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              LucideIcons.walletCards,
              color: AppColors.themeText,
              size: 29,
            ),
          ),

          SizedBox(height: 13),

          Text(
            'NaNa Wallet',
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),

          SizedBox(height: 5),

          Text(
            'TRANSACTION RECEIPT',
            style: TextStyle(
              color: Color(0xFF7F929A),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // STATUS SECTION
  // ==========================================================

  Widget _buildStatusSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _statusColor.withOpacity(0.10),
            ),
            child: Icon(_statusIcon, color: _statusColor, size: 31),
          ),

          SizedBox(height: 12),

          Text(
            _statusLabel,
            style: TextStyle(
              color: _statusColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // AMOUNT SECTION
  // ==========================================================

  Widget _buildAmountSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
      child: Column(
        children: [
          Text(
            '\$${_amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),

          SizedBox(height: 4),

          Text(
            _currency,
            style: TextStyle(
              color: Color(0xFF8FA3AD),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),

          SizedBox(height: 8),

          Text(
            _typeLabel,
            style: TextStyle(
              color: Color(0xFFB8C5CA),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // RECEIPT DETAILS
  // ==========================================================

  Widget _buildReceiptDetails() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          Divider(height: 1, color: AppColors.themeText.withOpacity(0.06)),

          _detailRow(label: 'Transaction Type', value: _typeLabel),

          Divider(height: 1, color: AppColors.themeText.withOpacity(0.06)),

          _detailRow(
            label: 'Reference ID',
            value: _referenceId.isEmpty ? 'Not available' : _referenceId,
          ),

          Divider(height: 1, color: AppColors.themeText.withOpacity(0.06)),

          _detailRow(label: 'Date & Time', value: _formattedDate),

          if (_description.trim().isNotEmpty) ...[
            Divider(height: 1, color: AppColors.themeText.withOpacity(0.06)),

            _detailRow(label: 'Description', value: _description),
          ],

          Divider(height: 1, color: AppColors.themeText.withOpacity(0.06)),

          _detailRow(label: 'Receipt No.', value: _receiptNumber),
        ],
      ),
    );
  }

  // ==========================================================
  // SECURITY FOOTER
  // ==========================================================

  Widget _buildSecurityFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 26),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.shieldCheck,
            color: Color(0xFF7DD3FC),
            size: 18,
          ),

          SizedBox(width: 9),

          Expanded(
            child: Text(
              'This receipt is generated by NaNa Wallet '
              'and represents the transaction information '
              'recorded in your account.',
              style: TextStyle(
                color: Color(0xFF71858E),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // COMPLETE RECEIPT CARD
  // ==========================================================

  Widget _buildReceipt() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.adaptiveSurface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.themeText.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildReceiptHeader(),

          Divider(height: 1, color: AppColors.themeText.withOpacity(0.06)),

          _buildStatusSection(),

          _buildAmountSection(),

          _buildReceiptDetails(),

          _buildSecurityFooter(),
        ],
      ),
    );
  }

  // ==========================================================
  // US-040 — EMAIL RECEIPT
  // ==========================================================

  Future<void> _emailReceipt() async {
    if (_isSendingEmail) return;

    if (widget.token.trim().isEmpty) {
      _showErrorDialog('Your session has expired. Please login again.');
      return;
    }

    if (_referenceId.trim().isEmpty) {
      _showErrorDialog('This transaction does not have a valid reference ID.');
      return;
    }

    setState(() {
      _isSendingEmail = true;
    });

    try {
      final result = await WalletService.emailTransactionReceipt(
        token: widget.token,
        referenceId: _referenceId,
      );

      if (!mounted) return;

      if (result['status']?.toString().toLowerCase() == 'success') {
        _showEmailSuccessDialog(
          result['email']?.toString() ?? 'your registered email',
        );
      } else {
        _showErrorDialog(
          result['message']?.toString() ?? 'Unable to send receipt email.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showErrorDialog('Unable to send receipt email. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSendingEmail = false;
        });
      }
    }
  }

  // ==========================================================
  // EMAIL SUCCESS DIALOG
  // ==========================================================

  void _showEmailSuccessDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.adaptiveSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(LucideIcons.circleCheck, color: Color(0xFF3DDC97), size: 25),

              SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Receipt Sent',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          content: Text(
            'Your transaction receipt has been sent to:\n\n$email',
            style: TextStyle(
              color: Color(0xFFB8C5CA),
              fontSize: 14,
              height: 1.5,
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                'DONE',
                style: TextStyle(
                  color: Color(0xFF7DD3FC),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // EMAIL ERROR DIALOG
  // ==========================================================

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.adaptiveSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(LucideIcons.circleAlert, color: Color(0xFFFF6B6B), size: 25),

              SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Email Failed',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          content: Text(
            message,
            style: TextStyle(
              color: Color(0xFFB8C5CA),
              fontSize: 14,
              height: 1.5,
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                'OK',
                style: TextStyle(
                  color: Color(0xFF7DD3FC),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // COMING SOON DIALOG
  // ==========================================================

  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.adaptiveSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Coming Soon',
            style: TextStyle(color: AppColors.themeText, fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Receipt sharing will be available soon.',
            style: TextStyle(
              color: Color(0xFF9AAEB6),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                'OK',
                style: TextStyle(
                  color: Color(0xFF7DD3FC),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // EMAIL RECEIPT BUTTON
  // ==========================================================

  Widget _buildEmailReceiptButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSendingEmail ? null : _emailReceipt,

        icon: _isSendingEmail
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.themeText),
                ),
              )
            : Icon(LucideIcons.mail, size: 18),

        label: Text(
          _isSendingEmail ? 'SENDING RECEIPT...' : 'EMAIL RECEIPT',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),

        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF6675FF),
          foregroundColor: AppColors.themeText,
          disabledBackgroundColor: Color(0xFF6675FF).withOpacity(0.45),
          disabledForegroundColor: AppColors.themeText.withValues(alpha: 0.70),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // SHARE RECEIPT BUTTON
  // ==========================================================

  Widget _buildShareReceiptButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          _showComingSoon(context);
        },
        icon: Icon(LucideIcons.share2, size: 18),
        label: Text(
          'SHARE RECEIPT',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.themeText.withValues(alpha: 0.70),
          side: BorderSide(color: AppColors.themeText.withOpacity(0.10)),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // DONE BUTTON
  // ==========================================================

  Widget _buildDoneButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _isSendingEmail
            ? null
            : () {
                Navigator.pop(context);
              },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.themeText.withValues(alpha: 0.70),
          disabledForegroundColor: AppColors.themeText.withValues(alpha: 0.24),
          side: BorderSide(color: AppColors.themeText.withOpacity(0.10)),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          'DONE',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
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
        backgroundColor: Colors.transparent,
        elevation: 0,

        leading: IconButton(
          onPressed: _isSendingEmail
              ? null
              : () {
                  Navigator.pop(context);
                },
          icon: Icon(LucideIcons.arrowLeft, color: AppColors.themeText),
        ),

        title: Text(
          'RECEIPT',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Share Receipt',
            onPressed: () {
              _showComingSoon(context);
            },
            icon: Icon(
              LucideIcons.share2,
              color: AppColors.themeText.withValues(alpha: 0.70),
              size: 20,
            ),
          ),

          SizedBox(width: 8),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          child: Column(
            children: [
              // ==================================================
              // RECEIPT
              // ==================================================
              _buildReceipt(),

              SizedBox(height: 18),

              // ==================================================
              // EMAIL RECEIPT — US-040
              // ==================================================
              _buildEmailReceiptButton(),

              SizedBox(height: 10),

              // ==================================================
              // SHARE RECEIPT
              // ==================================================
              _buildShareReceiptButton(),

              SizedBox(height: 10),

              // ==================================================
              // DONE
              // ==================================================
              _buildDoneButton(),
            ],
          ),
        ),
      ),
    );
  }
}
