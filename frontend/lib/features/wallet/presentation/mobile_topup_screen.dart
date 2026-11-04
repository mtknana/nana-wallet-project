import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';

class MobileTopUpScreen extends StatefulWidget {
  MobileTopUpScreen({super.key});

  @override
  State<MobileTopUpScreen> createState() => _MobileTopUpScreenState();
}

class _MobileTopUpScreenState extends State<MobileTopUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  String _activeToken = '';
  String _selectedOperator = 'Smart';
  double _selectedAmount = 5.00;

  bool _isInitialized = false;
  bool _isLoading = false;

  // ============================================================
  // OPERATORS
  // ============================================================

  final List<Map<String, dynamic>> _operators = [
    {
      'name': 'Smart',
      'description': 'Smart Axiata',
      'icon': LucideIcons.signal,
    },
    {'name': 'Cellcard', 'description': 'Cellcard', 'icon': LucideIcons.signal},
    {'name': 'Metfone', 'description': 'Metfone', 'icon': LucideIcons.signal},
  ];

  // ============================================================
  // AMOUNTS
  // ============================================================

  final List<double> _amounts = [1.00, 2.00, 5.00, 10.00, 20.00];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInitialized) {
      final arguments = ModalRoute.of(context)?.settings.arguments;

      if (arguments is String) {
        _activeToken = arguments.trim();
      }

      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // ============================================================
  // VERIFY TRANSACTION PIN
  // ============================================================

  Future<bool> _verifyTransactionPin() async {
    final result = await Navigator.pushNamed(
      context,
      '/transaction-pin-verify',
      arguments: _activeToken,
    );

    return result == true;
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<void> _handleTopUpSubmit() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    // ----------------------------------------------------------
    // TOKEN
    // ----------------------------------------------------------

    if (_activeToken.isEmpty) {
      _showError('Authentication token is missing. Please login again.');
      return;
    }

    // ----------------------------------------------------------
    // FORM
    // ----------------------------------------------------------

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // ----------------------------------------------------------
    // CONFIRM
    // ----------------------------------------------------------

    final confirmed = await _showConfirmationDialog();

    if (!confirmed || !mounted) {
      return;
    }

    // ----------------------------------------------------------
    // TRANSACTION PIN
    // ----------------------------------------------------------

    final pinVerified = await _verifyTransactionPin();

    if (!pinVerified || !mounted) {
      return;
    }

    // ----------------------------------------------------------
    // LOADING
    // ----------------------------------------------------------

    setState(() {
      _isLoading = true;
    });

    try {
      final uniqueKey = 'TOP-${DateTime.now().millisecondsSinceEpoch}';

      // --------------------------------------------------------
      // API
      // --------------------------------------------------------

      final res = await WalletService.executeMobileTopUp(
        token: _activeToken,
        phoneNumber: _phoneController.text.trim(),
        amount: _selectedAmount,
        idempotencyKey: uniqueKey,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // --------------------------------------------------------
      // SUCCESS
      // --------------------------------------------------------

      if (res['status']?.toString().toLowerCase() == 'success') {
        await _showSuccessDialog(
          referenceId:
              (res['reference'] ?? res['reference_id'])?.toString() ?? '',
        );

        if (!mounted) return;

        _phoneController.clear();

        Navigator.pop(context);
        return;
      }

      // --------------------------------------------------------
      // ERROR
      // --------------------------------------------------------

      _showError(
        res['message']?.toString() ?? 'Top-up failed. Please try again.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError('Unable to process top-up. Please try again.');
    }
  }

  // ============================================================
  // CONFIRMATION DIALOG
  // ============================================================

  Future<bool> _showConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.adaptiveSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(
                LucideIcons.smartphone,
                color: AppColors.royalBlue,
                size: 23,
              ),
              SizedBox(width: 10),
              Text(
                'Confirm Top-Up',
                style: TextStyle(
                  color: AppColors.themeText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogRow('Operator', _selectedOperator),
              SizedBox(height: 12),
              _dialogRow('Phone Number', _phoneController.text.trim()),
              SizedBox(height: 12),
              _dialogRow(
                'Top-Up Amount',
                '\$${_selectedAmount.toStringAsFixed(2)}',
                highlight: true,
              ),
              SizedBox(height: 14),
              Divider(color: AppColors.themeText.withValues(alpha: 0.12)),
              SizedBox(height: 8),
              Text(
                'Please make sure the phone number is correct before continuing.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.themeText.withValues(alpha: 0.54),
                  fontSize: 12,
                  height: 1.4,
                ),
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
                style: TextStyle(
                  color: AppColors.themeText.withValues(alpha: 0.60),
                ),
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
              child: Text(
                'TOP UP',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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

  Future<void> _showSuccessDialog({required String referenceId}) async {
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
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withOpacity(0.12),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.greenAccent,
                  size: 60,
                ),
              ),

              SizedBox(height: 20),

              Text(
                'Demo Top-Up Recorded',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 8),

              Text(
                'Your top-up request was recorded in the NaNa Wallet demo. No mobile carrier was contacted.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.themeText.withValues(alpha: 0.60),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.themeText.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _dialogRow('Operator', _selectedOperator),
                    SizedBox(height: 10),
                    _dialogRow('Phone', _phoneController.text.trim()),
                    SizedBox(height: 10),
                    _dialogRow(
                      'Amount',
                      '\$${_selectedAmount.toStringAsFixed(2)}',
                      highlight: true,
                    ),
                    if (referenceId.isNotEmpty) ...[
                      SizedBox(height: 10),
                      Divider(
                        color: AppColors.themeText.withValues(alpha: 0.12),
                      ),
                      SizedBox(height: 8),
                      _dialogRow('Reference', referenceId),
                    ],
                  ],
                ),
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
  // ERROR
  // ============================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ============================================================
  // DIALOG ROW
  // ============================================================

  Widget _dialogRow(String title, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: highlight
                ? AppColors.themeText
                : AppColors.themeText.withValues(alpha: 0.60),
            fontSize: 13,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: highlight ? AppColors.neonPink : AppColors.themeText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.themeText),
        title: Text(
          'Mobile Top-Up',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================
      body: SafeArea(
        child: _isLoading
            ? _buildLoading()
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ==================================================
                      // HEADER
                      // ==================================================
                      Text(
                        'Top up mobile credit',
                        style: TextStyle(
                          color: AppColors.themeText,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 6),

                      Text(
                        'Send airtime instantly to any supported mobile number.',
                        style: TextStyle(
                          color: AppColors.themeText.withValues(alpha: 0.54),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),

                      SizedBox(height: 26),

                      // ==================================================
                      // OPERATOR
                      // ==================================================
                      Text(
                        'Mobile Operator',
                        style: TextStyle(
                          color: AppColors.themeText,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 12),

                      _buildOperatorSelector(),

                      SizedBox(height: 26),

                      // ==================================================
                      // PHONE
                      // ==================================================
                      Text(
                        'Phone Number',
                        style: TextStyle(
                          color: AppColors.themeText,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 12),

                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(
                          color: AppColors.themeText,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        onChanged: (_) {
                          setState(() {});
                        },
                        decoration: _inputDecoration(
                          hint: 'Enter recipient phone number',
                          icon: LucideIcons.smartphone,
                        ),
                        validator: (value) {
                          final phone = value?.trim() ?? '';

                          if (phone.isEmpty) {
                            return 'Please enter a phone number';
                          }

                          if (phone.length < 9) {
                            return 'Please enter a valid phone number';
                          }

                          return null;
                        },
                      ),

                      SizedBox(height: 26),

                      // ==================================================
                      // AMOUNT
                      // ==================================================
                      Text(
                        'Top-Up Amount',
                        style: TextStyle(
                          color: AppColors.themeText,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 12),

                      _buildAmountSelector(),

                      SizedBox(height: 28),

                      // ==================================================
                      // SUMMARY
                      // ==================================================
                      _buildSummary(),

                      SizedBox(height: 24),

                      // ==================================================
                      // INFO
                      // ==================================================
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.royalBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.royalBlue.withOpacity(0.18),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              LucideIcons.shieldCheck,
                              color: AppColors.royalBlue,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Check the phone number carefully. Mobile top-ups are normally processed immediately.',
                                style: TextStyle(
                                  color: AppColors.themeText.withValues(
                                    alpha: 0.60,
                                  ),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 26),

                      // ==================================================
                      // BUTTON
                      // ==================================================
                      _buildTopUpButton(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ============================================================
  // OPERATOR SELECTOR
  // ============================================================

  Widget _buildOperatorSelector() {
    return Row(
      children: _operators.map((operator) {
        final selected = _selectedOperator == operator['name'];

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: operator == _operators.last ? 0 : 8,
            ),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedOperator = operator['name'];
                });
              },
              child: AnimatedContainer(
                duration: Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.royalBlue.withOpacity(0.12)
                      : AppColors.adaptiveSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? AppColors.royalBlue
                        : AppColors.themeText.withValues(alpha: 0.10),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? AppColors.royalBlue.withOpacity(0.16)
                            : AppColors.themeText.withOpacity(0.05),
                      ),
                      child: Icon(
                        operator['icon'],
                        color: selected
                            ? AppColors.royalBlue
                            : AppColors.themeText.withValues(alpha: 0.54),
                        size: 21,
                      ),
                    ),

                    SizedBox(height: 9),

                    Text(
                      operator['name'],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.themeText,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 3),

                    Text(
                      operator['description'],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.themeText.withValues(alpha: 0.38),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // AMOUNT SELECTOR
  // ============================================================

  Widget _buildAmountSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _amounts.map((amount) {
        final selected = _selectedAmount == amount;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedAmount = amount;
            });
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 180),
            width: 94,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.royalBlue.withOpacity(0.14)
                  : AppColors.adaptiveSurface,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: selected
                    ? AppColors.royalBlue
                    : AppColors.themeText.withValues(alpha: 0.10),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  '\$${amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: selected
                        ? AppColors.themeText
                        : AppColors.themeText.withValues(alpha: 0.70),
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Airtime',
                  style: TextStyle(
                    color: selected
                        ? AppColors.royalBlue
                        : AppColors.themeText.withValues(alpha: 0.38),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.themeText.withOpacity(0.045),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.themeText.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.receiptText,
                color: AppColors.royalBlue,
                size: 19,
              ),
              SizedBox(width: 9),
              Text(
                'Top-Up Summary',
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          SizedBox(height: 18),

          _summaryRow('Operator', _selectedOperator),

          SizedBox(height: 11),

          _summaryRow(
            'Phone Number',
            _phoneController.text.isEmpty
                ? 'Not entered'
                : _phoneController.text,
          ),

          SizedBox(height: 11),

          _summaryRow('Airtime', '\$${_selectedAmount.toStringAsFixed(2)}'),

          Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: AppColors.themeText.withValues(alpha: 0.10)),
          ),

          _summaryRow(
            'Total',
            '\$${_selectedAmount.toStringAsFixed(2)}',
            highlight: true,
          ),
        ],
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
            color: highlight
                ? AppColors.themeText
                : AppColors.themeText.withValues(alpha: 0.54),
            fontSize: 12,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: highlight ? AppColors.neonPink : AppColors.themeText,
              fontSize: highlight ? 16 : 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // INPUT
  // ============================================================

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.themeText.withValues(alpha: 0.30),
        fontSize: 13,
      ),
      prefixIcon: Icon(icon, color: AppColors.royalBlue, size: 20),
      filled: true,
      fillColor: AppColors.adaptiveSurface,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: AppColors.themeText.withValues(alpha: 0.10),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.royalBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.redAccent),
      ),
    );
  }

  // ============================================================
  // TOP-UP BUTTON
  // ============================================================

  Widget _buildTopUpButton() {
    final enabled = _phoneController.text.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: enabled
            ? LinearGradient(colors: [AppColors.royalBlue, AppColors.neonPink])
            : null,
        color: enabled ? null : AppColors.themeText.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ElevatedButton(
        onPressed: enabled ? _handleTopUpSubmit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: AppColors.themeText,
          disabledForegroundColor: AppColors.themeText.withValues(alpha: 0.30),
          padding: const EdgeInsets.symmetric(vertical: 17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.smartphoneCharging, size: 20),
            SizedBox(width: 10),
            Text(
              'TOP UP NOW',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.royalBlue.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(22),
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.royalBlue,
              ),
            ),
          ),

          SizedBox(height: 20),

          Text(
            'Processing Top-Up...',
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 7),

          Text(
            'Please do not close the app.',
            style: TextStyle(color: AppColors.themeText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
