import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/quick_loan/services/quick_loan_service.dart';

class ApplyLoanScreen extends StatefulWidget {
  final String? token;

  const ApplyLoanScreen({super.key, this.token});

  @override
  State<ApplyLoanScreen> createState() => _ApplyLoanScreenState();
}

class _ApplyLoanScreenState extends State<ApplyLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  String? _activeToken;
  String _currency = 'USD';
  int _termDays = 7;

  bool _isSubmitting = false;
  String? _pendingApplicationKey;

  static const double _interestRate = 0.05;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _mint => AppColors.brandMint;
  Color get _textColor =>
      _isDark ? AppColors.textPrimary : const Color(0xFF17231F);
  Color get _mutedColor =>
      _isDark ? AppColors.textSecondary : const Color(0xFF687873);
  Color get _surfaceColor => _isDark ? AppColors.surface : Colors.white;
  Color get _backgroundColor =>
      _isDark ? AppColors.midnightBlue : const Color(0xFFF4F8F6);
  Color get _borderColor =>
      _isDark ? AppColors.glassBorder : const Color(0xFFE1EAE5);

  double get _principal => double.tryParse(_amountController.text.trim()) ?? 0;

  double get _interest => _principal * _interestRate;

  double get _disbursed => _principal - _interest;

  String _formatMoney(double amount) {
    if (_currency == 'KHR') {
      return '៛${amount.toStringAsFixed(0)}';
    }
    return '\$${amount.toStringAsFixed(2)}';
  }

  @override
  void initState() {
    super.initState();
    _activeToken = widget.token;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_activeToken == null || _activeToken!.trim().isEmpty) {
      final arguments = ModalRoute.of(context)?.settings.arguments;

      if (arguments is String) {
        _activeToken = arguments;
      } else if (arguments is Map) {
        _activeToken =
            arguments['token']?.toString() ??
            arguments['activeToken']?.toString();
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitApplication() async {
    FocusScope.of(context).unfocus();

    if (_activeToken == null || _activeToken!.trim().isEmpty) {
      _showMessage('Your session has expired. Please login again.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final response = await QuickLoanService.applyForLoan(
        token: _activeToken!,
        amount: _principal,
        currency: _currency,
        termDays: _termDays,
        idempotencyKey: _pendingApplicationKey ??=
            'nana-loan-${DateTime.now().microsecondsSinceEpoch}',
      );

      if (!mounted) return;

      if (response['success'] == true) {
        _pendingApplicationKey = null;
        final loan = response['data'];

        final principal =
            double.tryParse(loan?['principal']?.toString() ?? '') ?? _principal;

        final interest =
            double.tryParse(loan?['upfront_interest']?.toString() ?? '') ??
            _interest;

        final received =
            double.tryParse(loan?['disbursed_amount']?.toString() ?? '') ??
            (principal - interest);

        final currency = loan?['currency']?.toString() ?? _currency;

        setState(() => _isSubmitting = false);

        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: _surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: _mint.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: _mint,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loan Approved!',
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    response['message']?.toString() ??
                        'Your loan was approved successfully.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _mutedColor, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  _resultRow(
                    'Loan principal',
                    _formatForCurrency(principal, currency),
                  ),
                  _resultRow(
                    'Upfront interest',
                    _formatForCurrency(interest, currency),
                  ),
                  Divider(color: _borderColor),
                  _resultRow(
                    'Amount received',
                    _formatForCurrency(received, currency),
                    highlight: true,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mint,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
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
      } else {
        setState(() => _isSubmitting = false);
        _showMessage(
          response['message']?.toString() ??
              'Unable to submit your loan application.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _formatForCurrency(double amount, String currency) {
    if (currency.toUpperCase() == 'KHR') {
      return '៛${amount.toStringAsFixed(0)}';
    }
    return '\$${amount.toStringAsFixed(2)}';
  }

  Widget _resultRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlight ? _textColor : _mutedColor,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w500,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight ? _mint : _textColor,
              fontWeight: FontWeight.w800,
              fontSize: highlight ? 16 : 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        foregroundColor: _textColor,
        elevation: 0,
        title: Text(
          'Apply for a Loan',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              _buildIntroduction(),
              const SizedBox(height: 22),
              _buildCurrencySelector(),
              const SizedBox(height: 20),
              _buildAmountInput(),
              const SizedBox(height: 22),
              _buildTermSelector(),
              const SizedBox(height: 22),
              _buildCalculationCard(),
              const SizedBox(height: 20),
              _buildImportantNotice(),
              const SizedBox(height: 25),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroduction() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_mint, const Color(0xFF178A70)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
            size: 30,
          ),
          SizedBox(height: 12),
          Text(
            'Get the support you need.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Choose your loan amount and repayment period.',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Loan currency'),
        const SizedBox(height: 10),
        Row(
          children: [
            _currencyOption('USD', 'US Dollar'),
            const SizedBox(width: 12),
            _currencyOption('KHR', 'Khmer Riel'),
          ],
        ),
      ],
    );
  }

  Widget _currencyOption(String currency, String label) {
    final selected = _currency == currency;

    return Expanded(
      child: InkWell(
        onTap: _isSubmitting
            ? null
            : () {
                setState(() {
                  _currency = currency;
                  _amountController.clear();
                });
              },
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: selected ? _mint.withValues(alpha: 0.10) : _surfaceColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? _mint : _borderColor,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                currency,
                style: TextStyle(
                  color: selected ? _mint : _textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: _mutedColor, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Loan amount'),
        const SizedBox(height: 10),
        TextFormField(
          controller: _amountController,
          enabled: !_isSubmitting,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              _currency == 'KHR' ? RegExp(r'^\d*') : RegExp(r'^\d*\.?\d{0,2}'),
            ),
          ],
          style: TextStyle(
            color: _textColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            prefixText: _currency == 'USD' ? '\$ ' : '៛ ',
            prefixStyle: TextStyle(
              color: _mint,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
            hintText: 'Enter amount',
            hintStyle: TextStyle(color: _mutedColor),
            filled: true,
            fillColor: _surfaceColor,
            contentPadding: const EdgeInsets.all(18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: _mint, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
          ),
          validator: (value) {
            final amount = double.tryParse(value?.trim() ?? '');

            if (amount == null || amount <= 0) {
              return 'Please enter a valid loan amount.';
            }

            if (_currency == 'KHR' && amount != amount.roundToDouble()) {
              return 'KHR amounts must be whole numbers.';
            }
            if (_currency == 'USD' &&
                ((amount * 100) - (amount * 100).round()).abs() > 0.000001) {
              return 'USD amounts can have up to 2 decimal places.';
            }

            return null;
          },
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 7),
        Text(
          'Maximum loan: \$100 equivalent. The server will verify the current exchange rate and limit.',
          style: TextStyle(color: _mutedColor, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildTermSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Repayment period'),
        const SizedBox(height: 10),
        Row(
          children: [7, 14, 30].map((days) {
            final selected = _termDays == days;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: days == 30 ? 0 : 10),
                child: InkWell(
                  onTap: _isSubmitting
                      ? null
                      : () => setState(() => _termDays = days),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: selected
                          ? _mint.withValues(alpha: 0.10)
                          : _surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? _mint : _borderColor,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$days',
                          style: TextStyle(
                            color: selected ? _mint : _textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Days',
                          style: TextStyle(color: _mutedColor, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCalculationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Loan calculation'),
          const SizedBox(height: 15),
          _resultRow('Loan principal', _formatMoney(_principal)),
          _resultRow('Upfront interest (5%)', _formatMoney(_interest)),
          Divider(color: _borderColor, height: 22),
          _resultRow(
            'You will receive',
            _formatMoney(_disbursed),
            highlight: true,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _mint.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: _mint, size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You repay ${_formatMoney(_principal)} principal. Interest is already deducted before disbursement.',
                    style: TextStyle(
                      color: _mutedColor,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportantNotice() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Please review the amount, interest, and repayment period before confirming. Loan approval and disbursement are processed by the server.',
              style: TextStyle(color: _mutedColor, fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitApplication,
        style: ElevatedButton.styleFrom(
          backgroundColor: _mint,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _mint.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 17),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Confirm Loan Application',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: _textColor,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
