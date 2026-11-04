import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  final String token;
  final String paymentType;
  final String recipient;
  final double amount;
  final String currency;
  final String? description;
  final Future<Map<String, dynamic>> Function() onConfirm;

  PaymentConfirmationScreen({
    super.key,
    required this.token,
    required this.paymentType,
    required this.recipient,
    required this.amount,
    required this.currency,
    this.description,
    required this.onConfirm,
  });

  @override
  State<PaymentConfirmationScreen> createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  bool _isProcessing = false;

  // ============================================================
  // COLORS
  // ============================================================

  Color get _primaryColor => AppColors.royalBlue;
  Color get _accentColor => AppColors.neonPink;

  static Color get _background => AppColors.adaptiveSurfaceAlt;
  static Color get _card => AppColors.adaptiveSurface;

  // ============================================================
  // CURRENCY
  // ============================================================

  bool get _isKhr => widget.currency.toUpperCase() == 'KHR';

  String get _currencySymbol => _isKhr ? '៛' : '\$';

  String _formatAmount() {
    if (_isKhr) {
      return '${widget.amount.toStringAsFixed(0)} KHR';
    }

    return '\$${widget.amount.toStringAsFixed(2)}';
  }

  // ============================================================
  // PAYMENT TYPE
  // ============================================================

  String _paymentTypeLabel() {
    switch (widget.paymentType) {
      case 'bill_payment':
        return 'Bill Payment';

      case 'mobile_topup':
        return 'Mobile Top-Up';

      case 'transfer':
        return 'Money Transfer';

      case 'qr_payment':
        return 'QR Payment';

      case 'merchant_payment':
        return 'Merchant Payment';

      default:
        return widget.paymentType;
    }
  }

  IconData _paymentTypeIcon() {
    switch (widget.paymentType) {
      case 'bill_payment':
        return LucideIcons.receipt;

      case 'mobile_topup':
        return LucideIcons.smartphone;

      case 'transfer':
        return LucideIcons.send;

      case 'qr_payment':
        return LucideIcons.qrCode;

      case 'merchant_payment':
        return LucideIcons.store;

      default:
        return LucideIcons.walletCards;
    }
  }

  // ============================================================
  // CONFIRM PAYMENT
  // ============================================================

  Future<void> _confirmPayment() async {
    if (_isProcessing) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await widget.onConfirm();

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      if (result['status']?.toString().toLowerCase() == 'success') {
        _showSuccess(result);
      } else {
        _showError(result['message']?.toString() ?? 'Payment failed.');
      }
    } catch (e) {
      debugPrint('❌ Payment confirmation error: $e');

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      _showError('Unable to process the payment. Please try again.');
    }
  }

  // ============================================================
  // SUCCESS DIALOG
  // ============================================================

  void _showSuccess(Map<String, dynamic> result) {
    final reference =
        result['reference_id'] ??
        result['reference'] ??
        result['data']?['reference_id'] ??
        result['data']?['reference'] ??
        'N/A';

    final message =
        result['message']?.toString() ??
        'Your payment was processed successfully.';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 22),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 35,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ==================================================
                  // SUCCESS ICON
                  // ==================================================
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.greenAccent.withOpacity(0.20),
                          Colors.green.withOpacity(0.06),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.greenAccent.withOpacity(0.25),
                      ),
                    ),
                    child: Icon(
                      LucideIcons.circleCheck,
                      color: Colors.greenAccent,
                      size: 45,
                    ),
                  ),

                  SizedBox(height: 20),

                  // ==================================================
                  // TITLE
                  // ==================================================
                  Text(
                    'Payment Successful',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.themeText,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),

                  SizedBox(height: 8),

                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.themeText.withValues(alpha: 0.54),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),

                  SizedBox(height: 22),

                  // ==================================================
                  // AMOUNT
                  // ==================================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _primaryColor.withOpacity(0.13),
                          _accentColor.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _primaryColor.withOpacity(0.15),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'AMOUNT SENT',
                          style: TextStyle(
                            color: AppColors.themeText.withValues(alpha: 0.38),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),

                        SizedBox(height: 7),

                        Text(
                          '${_isKhr ? '' : _currencySymbol}${widget.amount.toStringAsFixed(_isKhr ? 0 : 2)}${_isKhr ? ' KHR' : ''}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _accentColor,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // ==================================================
                  // REFERENCE
                  // ==================================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.themeText.withOpacity(0.05)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              LucideIcons.hash,
                              color: AppColors.themeText.withValues(alpha: 0.38),
                              size: 13,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'REFERENCE ID',
                              style: TextStyle(
                                color: AppColors.themeText.withValues(alpha: 0.38),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 7),

                        Text(
                          reference.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.themeText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // ==================================================
                  // DONE
                  // ==================================================
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);

                        // Return TRUE to P2pTransferScreen.
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: AppColors.themeText,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.check, size: 19),
                          SizedBox(width: 9),
                          Text(
                            'Done',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(LucideIcons.circleAlert, color: AppColors.themeText, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget _detailRow({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _primaryColor, size: 18),
        ),

        SizedBox(width: 12),

        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AppColors.themeText.withValues(alpha: 0.54),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        SizedBox(width: 12),

        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? AppColors.themeText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primaryColor.withOpacity(0.15),
            _accentColor.withOpacity(0.045),
            _card,
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: _primaryColor.withOpacity(0.17)),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primaryColor.withOpacity(0.11),
              border: Border.all(color: _primaryColor.withOpacity(0.18)),
            ),
            child: Icon(_paymentTypeIcon(), color: _primaryColor, size: 31),
          ),

          SizedBox(height: 17),

          Text(
            'Review Your Payment',
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),

          SizedBox(height: 7),

          Text(
            'Please verify the payment details before confirming.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.themeText.withValues(alpha: 0.54),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECURITY CARD
  // ============================================================

  Widget _buildSecurityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.065),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _primaryColor.withOpacity(0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              LucideIcons.shieldCheck,
              color: _primaryColor,
              size: 19,
            ),
          ),

          SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Transaction',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  'Your transaction will be authorized using your Transaction PIN or biometric authentication.',
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.54),
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    AppColors.dependOnTheme(context);
    return Scaffold(
      backgroundColor: _background,

      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,

        leading: IconButton(
          onPressed: _isProcessing
              ? null
              : () {
                  Navigator.pop(context);
                },
          icon: Icon(
            LucideIcons.arrowLeft,
            color: _isProcessing ? AppColors.themeText.withValues(alpha: 0.24) : AppColors.themeText.withValues(alpha: 0.70),
            size: 21,
          ),
        ),

        title: Text(
          'Confirm Payment',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),

        centerTitle: true,
      ),

      // ========================================================
      // BODY
      // ========================================================
      body: SafeArea(
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // HERO
              // ==================================================
              _buildHero(),

              SizedBox(height: 25),

              // ==================================================
              // PAYMENT DETAILS TITLE
              // ==================================================
              Row(
                children: [
                  Icon(LucideIcons.fileText, color: AppColors.themeText.withValues(alpha: 0.70), size: 18),

                  SizedBox(width: 8),

                  Text(
                    'Payment Details',
                    style: TextStyle(
                      color: AppColors.themeText,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              // ==================================================
              // PAYMENT DETAILS CARD
              // ==================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(19),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.themeText.withOpacity(0.055)),
                ),
                child: Column(
                  children: [
                    _detailRow(
                      icon: _paymentTypeIcon(),
                      title: 'Payment Type',
                      value: _paymentTypeLabel(),
                    ),

                    Divider(color: AppColors.themeText.withValues(alpha: 0.10), height: 27),

                    _detailRow(
                      icon: LucideIcons.user,
                      title: 'Recipient',
                      value: widget.recipient,
                    ),

                    Divider(color: AppColors.themeText.withValues(alpha: 0.10), height: 27),

                    _detailRow(
                      icon: LucideIcons.wallet,
                      title: 'Currency',
                      value: widget.currency,
                    ),

                    Divider(color: AppColors.themeText.withValues(alpha: 0.10), height: 27),

                    _detailRow(
                      icon: _isKhr ? LucideIcons.coins : LucideIcons.dollarSign,
                      title: 'Amount',
                      value: _formatAmount(),
                      valueColor: _accentColor,
                    ),

                    if (widget.description != null &&
                        widget.description!.trim().isNotEmpty) ...[
                      Divider(color: AppColors.themeText.withValues(alpha: 0.10), height: 27),

                      _detailRow(
                        icon: LucideIcons.messageSquare,
                        title: 'Message',
                        value: widget.description!.trim(),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: 20),

              // ==================================================
              // AMOUNT HIGHLIGHT
              // ==================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.themeText.withOpacity(0.025),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: AppColors.themeText.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        LucideIcons.send,
                        color: _accentColor,
                        size: 19,
                      ),
                    ),

                    SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total to Send',
                            style: TextStyle(
                              color: AppColors.themeText.withValues(alpha: 0.54),
                              fontSize: 11,
                            ),
                          ),

                          SizedBox(height: 3),

                          Text(
                            'Final transaction amount',
                            style: TextStyle(
                              color: AppColors.themeText.withValues(alpha: 0.30),
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Text(
                      _formatAmount(),
                      style: TextStyle(
                        color: _accentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // ==================================================
              // SECURITY
              // ==================================================
              _buildSecurityCard(),

              SizedBox(height: 28),

              // ==================================================
              // CONFIRM BUTTON
              // ==================================================
              SizedBox(
                width: double.infinity,
                height: 57,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: _isProcessing
                        ? null
                        : LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [_primaryColor, _accentColor],
                          ),
                    color: _isProcessing ? AppColors.themeText.withValues(alpha: 0.12) : null,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: _isProcessing
                        ? null
                        : [
                            BoxShadow(
                              color: _primaryColor.withOpacity(0.18),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _confirmPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      foregroundColor: AppColors.themeText,
                      disabledForegroundColor: AppColors.themeText.withValues(alpha: 0.38),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: 180),
                      child: _isProcessing
                          ? Row(
                              key: ValueKey('processing'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.themeText,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Processing...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              key: ValueKey('confirm'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.shieldCheck, size: 20),
                                SizedBox(width: 9),
                                Text(
                                  'Confirm & Pay',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 11),

              // ==================================================
              // CANCEL
              // ==================================================
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          Navigator.pop(context);
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.themeText.withValues(alpha: 0.54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
