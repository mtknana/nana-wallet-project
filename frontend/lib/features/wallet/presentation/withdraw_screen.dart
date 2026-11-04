import 'dart:math';
import 'package:flutter/material.dart';
import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';

class WithdrawScreen extends StatefulWidget {
  WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _amountController = TextEditingController();

  final TextEditingController _accountController = TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  String _withdrawMethod = 'bank';
  String _currency = 'USD';

  bool _isLoading = false;

  String _token = '';

  // ============================================================
  // FEES
  // ============================================================

  // Display fee only.
  //
  // IMPORTANT:
  // The real fee is calculated by Laravel.
  // Flutter only displays the expected fee.
  double get _serviceFee {
    if (_withdrawMethod == 'bank') {
      return 0.25;
    }

    return 0.50;
  }

  double get _withdrawAmount {
    return double.tryParse(_amountController.text.trim()) ?? 0.00;
  }

  double get _totalDeducted {
    if (_withdrawAmount <= 0) {
      return 0.00;
    }

    return _withdrawAmount + _serviceFee;
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_token.isEmpty) {
      final arguments = ModalRoute.of(context)?.settings.arguments;

      if (arguments is String) {
        _token = arguments.trim();
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  // ============================================================
  // QUICK AMOUNT
  // ============================================================

  void _setAmount(double amount) {
    _amountController.text = amount.toStringAsFixed(2);

    setState(() {});
  }

  // ============================================================
  // TRANSACTION PIN VERIFICATION
  // ============================================================

  Future<bool> _verifyTransactionPin() async {
    final result = await Navigator.pushNamed(
      context,
      '/transaction-pin-verify',
      arguments: _token,
    );

    return result == true;
  }

  // ============================================================
  // SUBMIT WITHDRAWAL
  // ============================================================

  Future<void> _submitWithdrawal() async {
    FocusScope.of(context).unfocus();

    // ------------------------------------------------------------
    // TOKEN CHECK
    // ------------------------------------------------------------

    if (_token.trim().isEmpty) {
      _showError('Authentication token is missing. Please login again.');
      return;
    }

    // ------------------------------------------------------------
    // ACCOUNT CHECK
    // ------------------------------------------------------------

    if (_withdrawMethod == 'bank' && _accountController.text.trim().isEmpty) {
      _showError('Please enter your bank account number.');
      return;
    }

    // ------------------------------------------------------------
    // AMOUNT CHECK
    // ------------------------------------------------------------

    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      _showError('Please enter a valid withdrawal amount.');
      return;
    }

    if (amount < 0.01) {
      _showError('Minimum withdrawal amount is \$0.01.');
      return;
    }

    // ------------------------------------------------------------
    // CONFIRMATION
    // ------------------------------------------------------------

    final shouldContinue = await _showConfirmationDialog(amount);

    if (!shouldContinue || !mounted) {
      return;
    }

    // ------------------------------------------------------------
    // TRANSACTION PIN VERIFICATION
    // ------------------------------------------------------------

    final pinVerified = await _verifyTransactionPin();

    if (!pinVerified || !mounted) {
      return;
    }

    // ------------------------------------------------------------
    // LOADING
    // ------------------------------------------------------------

    setState(() {
      _isLoading = true;
    });

    try {
      // ----------------------------------------------------------
      // UNIQUE IDEMPOTENCY KEY
      // ----------------------------------------------------------

      final idempotencyKey =
          'WD-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';

      // ----------------------------------------------------------
      // CALL LARAVEL API
      // ----------------------------------------------------------

      final response = await WalletService.executeWithdraw(
        token: _token,
        amount: amount,
        idempotencyKey: idempotencyKey,
        currency: _currency,
      );

      if (!mounted) return;

      // ----------------------------------------------------------
      // STOP LOADING
      // ----------------------------------------------------------

      setState(() {
        _isLoading = false;
      });

      // ----------------------------------------------------------
      // SUCCESS
      // ----------------------------------------------------------

      if (response['status']?.toString() == 'success') {
        final serviceFee =
            double.tryParse(response['service_fee']?.toString() ?? '') ??
            _serviceFee;

        final totalDeducted =
            double.tryParse(response['total_deducted']?.toString() ?? '') ??
            (amount + serviceFee);

        final referenceId = response['reference_id']?.toString() ?? '';

        await _showSuccessDialog(
          amount: amount,
          serviceFee: serviceFee,
          totalDeducted: totalDeducted,
          referenceId: referenceId,
        );

        if (!mounted) return;

        // Clear fields
        _amountController.clear();
        _accountController.clear();

        return;
      }

      // ----------------------------------------------------------
      // ERROR FROM SERVER
      // ----------------------------------------------------------

      final message =
          response['message']?.toString() ??
          'Withdrawal failed. Please try again.';

      _showError(message);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError('Something went wrong. Please try again.');
    }
  }

  // ============================================================
  // CONFIRMATION DIALOG
  // ============================================================

  Future<bool> _showConfirmationDialog(double amount) async {
    final fee = _serviceFee;
    final total = amount + fee;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.adaptiveSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Confirm Withdrawal',
            style: TextStyle(color: AppColors.themeText, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogRow('Withdrawal Amount', '\$${amount.toStringAsFixed(2)}'),
              SizedBox(height: 10),
              _dialogRow('Service Fee', '\$${fee.toStringAsFixed(2)}'),
              Divider(color: AppColors.themeText.withValues(alpha: 0.24), height: 24),
              _dialogRow(
                'Total Deducted',
                '\$${total.toStringAsFixed(2)}',
                isTotal: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: Text(
                'CANCEL',
                style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.70)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.royalBlue,
                foregroundColor: AppColors.themeText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('CONFIRM'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ============================================================
  // SUCCESS DIALOG
  // ============================================================

  Future<void> _showSuccessDialog({
    required double amount,
    required double serviceFee,
    required double totalDeducted,
    required String referenceId,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.adaptiveSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --------------------------------------------------
              // SUCCESS ICON
              // --------------------------------------------------
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withOpacity(0.15),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.greenAccent,
                  size: 58,
                ),
              ),

              SizedBox(height: 20),

              Text(
                'Withdrawal Successful',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 10),

              Text(
                '\$${amount.toStringAsFixed(2)} has been processed successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.70), fontSize: 14),
              ),

              SizedBox(height: 20),

              // --------------------------------------------------
              // DETAILS
              // --------------------------------------------------
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.themeText.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _dialogRow('Withdrawal', '\$${amount.toStringAsFixed(2)}'),

                    SizedBox(height: 8),

                    _dialogRow(
                      'Service Fee',
                      '\$${serviceFee.toStringAsFixed(2)}',
                    ),

                    SizedBox(height: 8),

                    _dialogRow(
                      'Total Deducted',
                      '\$${totalDeducted.toStringAsFixed(2)}',
                      isTotal: true,
                    ),

                    if (referenceId.isNotEmpty) ...[
                      SizedBox(height: 12),

                      Divider(color: AppColors.themeText.withValues(alpha: 0.12)),

                      SizedBox(height: 8),

                      _dialogRow('Reference', referenceId),
                    ],
                  ],
                ),
              ),

              SizedBox(height: 20),

              Text(
                'Your withdrawal has been recorded in your wallet history.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.54), fontSize: 12),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.royalBlue,
                  foregroundColor: AppColors.themeText,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'DONE',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // DIALOG ROW
  // ============================================================

  Widget _dialogRow(String title, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isTotal ? AppColors.themeText : AppColors.themeText.withValues(alpha: 0.60),
            fontSize: 13,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: isTotal ? AppColors.neonPink : AppColors.themeText,
              fontSize: 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      backgroundColor: AppColors.adaptiveSurfaceAlt,

      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Withdraw Money',
          style: TextStyle(color: AppColors.themeText, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: AppColors.themeText),
      ),

      // ========================================================
      // BODY
      // ========================================================
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // HEADER
              // ==================================================
              Text(
                'Move money out of your NaNa Wallet',
                style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.70), fontSize: 14),
              ),

              SizedBox(height: 24),

              // ==================================================
              // WITHDRAW METHOD
              // ==================================================
              Text(
                'Withdrawal Method',
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _methodCard(
                      value: 'bank',
                      icon: Icons.account_balance,
                      title: 'Bank Account',
                      subtitle: '\$0.25 fee',
                    ),
                  ),

                  SizedBox(width: 12),

                  Expanded(
                    child: _methodCard(
                      value: 'cash',
                      icon: Icons.storefront,
                      title: 'Cash / Agent',
                      subtitle: '\$0.50 fee',
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24),

              // ==================================================
              // CURRENCY
              // ==================================================
              Text(
                'Wallet',
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.themeText.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.themeText.withOpacity(0.08)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _currency,
                    isExpanded: true,
                    dropdownColor: AppColors.adaptiveSurface,
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.themeText.withValues(alpha: 0.70),
                    ),
                    style: TextStyle(color: AppColors.themeText, fontSize: 15),
                    items:  [
                      DropdownMenuItem(
                        value: 'USD',
                        child: Text('USD — US Dollar'),
                      ),
                      DropdownMenuItem(
                        value: 'KHR',
                        child: Text('KHR — Cambodian Riel'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        _currency = value;
                      });
                    },
                  ),
                ),
              ),

              SizedBox(height: 24),

              // ==================================================
              // BANK ACCOUNT
              // ==================================================
              if (_withdrawMethod == 'bank') ...[
                Text(
                  'Bank Account Number',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 12),

                TextField(
                  controller: _accountController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppColors.themeText),
                  decoration: InputDecoration(
                    hintText: 'Enter bank account number',
                    hintStyle: TextStyle(color: AppColors.themeText.withValues(alpha: 0.38)),
                    prefixIcon: Icon(
                      Icons.account_balance,
                      color: AppColors.themeText.withValues(alpha: 0.54),
                    ),
                    filled: true,
                    fillColor: AppColors.themeText.withOpacity(0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.royalBlue),
                    ),
                  ),
                ),

                SizedBox(height: 24),
              ],

              // ==================================================
              // CASH / AGENT INFO
              // ==================================================
              if (_withdrawMethod == 'cash') ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.royalBlue.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.royalBlue.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.storefront, color: AppColors.royalBlue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cash / Agent Withdrawal',
                              style: TextStyle(
                                color: AppColors.themeText,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Visit a NaNa Wallet agent to receive your withdrawal in cash.',
                              style: TextStyle(
                                color: AppColors.themeText.withValues(alpha: 0.60),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),
              ],

              // ==================================================
              // AMOUNT
              // ==================================================
              Text(
                'Withdrawal Amount',
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 12),

              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) {
                  setState(() {});
                },
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.24),
                    fontSize: 22,
                  ),
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  filled: true,
                  fillColor: AppColors.themeText.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: AppColors.royalBlue),
                  ),
                ),
              ),

              SizedBox(height: 14),

              // ==================================================
              // QUICK AMOUNTS
              // ==================================================
              Row(
                children: [
                  _quickAmountButton(10),
                  SizedBox(width: 8),
                  _quickAmountButton(20),
                  SizedBox(width: 8),
                  _quickAmountButton(50),
                  SizedBox(width: 8),
                  _quickAmountButton(100),
                ],
              ),

              SizedBox(height: 28),

              // ==================================================
              // SUMMARY
              // ==================================================
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.themeText.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.themeText.withOpacity(0.08)),
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Withdrawal Summary',
                        style: TextStyle(
                          color: AppColors.themeText,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    SizedBox(height: 18),

                    _summaryRow(
                      'Withdrawal Amount',
                      '\$${_withdrawAmount.toStringAsFixed(2)}',
                    ),

                    SizedBox(height: 12),

                    _summaryRow(
                      'Service Fee',
                      '\$${_serviceFee.toStringAsFixed(2)}',
                    ),

                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(color: AppColors.themeText.withValues(alpha: 0.12)),
                    ),

                    _summaryRow(
                      'Total Deducted',
                      '\$${_totalDeducted.toStringAsFixed(2)}',
                      highlight: true,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // ==================================================
              // INFO
              // ==================================================
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withOpacity(0.20)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'The withdrawal amount and service fee will be deducted from your NaNa Wallet. Service fees are transferred to the NaNa Wallet admin account.',
                        style: TextStyle(
                          color: AppColors.themeText.withValues(alpha: 0.60),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 28),

              // ==================================================
              // CONFIRM BUTTON
              // ==================================================
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitWithdrawal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.royalBlue,
                    disabledBackgroundColor: AppColors.themeText.withValues(alpha: 0.12),
                    foregroundColor: AppColors.themeText,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.themeText,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance_wallet, size: 21),
                            SizedBox(width: 10),
                            Text(
                              'CONFIRM WITHDRAWAL',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 0.5,
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
  }

  // ============================================================
  // METHOD CARD
  // ============================================================

  Widget _methodCard({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _withdrawMethod == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _withdrawMethod = value;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.royalBlue.withOpacity(0.15)
              : AppColors.themeText.withOpacity(0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.royalBlue : AppColors.themeText.withValues(alpha: 0.12),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.royalBlue : AppColors.themeText.withValues(alpha: 0.60),
              size: 28,
            ),

            SizedBox(height: 12),

            Text(
              title,
              style: TextStyle(
                color: AppColors.themeText,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 4),

            Text(
              subtitle,
              style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.54), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // QUICK AMOUNT BUTTON
  // ============================================================

  Widget _quickAmountButton(double amount) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _setAmount(amount);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.themeText.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.themeText.withValues(alpha: 0.12)),
          ),
          child: Text(
            '\$${amount.toStringAsFixed(0)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.themeText.withValues(alpha: 0.70),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SUMMARY ROW
  // ============================================================

  Widget _summaryRow(String title, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: highlight ? AppColors.themeText : AppColors.themeText.withValues(alpha: 0.60),
            fontSize: 13,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlight ? AppColors.neonPink : AppColors.themeText,
            fontSize: highlight ? 16 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
