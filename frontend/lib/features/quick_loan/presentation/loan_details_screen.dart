import 'package:flutter/material.dart';
import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/quick_loan/services/quick_loan_service.dart';

class LoanDetailsScreen extends StatefulWidget {
  final String? token;
  final int? loanId;

  const LoanDetailsScreen({super.key, this.token, this.loanId});

  @override
  State<LoanDetailsScreen> createState() => _LoanDetailsScreenState();
}

class _LoanDetailsScreenState extends State<LoanDetailsScreen> {
  String? _activeToken;
  int? _activeLoanId;

  bool _isLoading = true;
  bool _isRepaying = false;
  String? _pendingRepaymentKey;
  String? _pendingRepaymentAmount;
  String? _errorMessage;
  Map<String, dynamic>? _loan;

  final TextEditingController _repaymentController = TextEditingController();

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

  @override
  void initState() {
    super.initState();
    _activeToken = widget.token;
    _activeLoanId = widget.loanId;
  }

  @override
  void dispose() {
    _repaymentController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final arguments = ModalRoute.of(context)?.settings.arguments;

    if (arguments is Map) {
      _activeToken ??= arguments['token']?.toString();
      _activeLoanId ??= int.tryParse(arguments['loanId']?.toString() ?? '');
    }

    if (_activeToken != null &&
        _activeToken!.trim().isNotEmpty &&
        _activeLoanId != null &&
        _isLoading) {
      _loadLoan();
    } else if (_activeToken == null || _activeLoanId == null) {
      _isLoading = false;
      _errorMessage = 'Loan information is missing. Please reopen this screen.';
    }
  }

  Future<void> _loadLoan() async {
    if (_activeToken == null || _activeLoanId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await QuickLoanService.fetchLoanDetails(
        token: _activeToken!,
        loanId: _activeLoanId!,
      );

      if (!mounted) return;

      if (response['success'] == true && response['data'] is Map) {
        setState(() {
          _loan = Map<String, dynamic>.from(response['data']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              response['message']?.toString() ?? 'Unable to load loan details.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  double _number(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;

  String _money(dynamic value, String currency) {
    final amount = _number(value);

    if (currency.toUpperCase() == 'KHR') {
      return '៛${amount.toStringAsFixed(0)}';
    }

    return '\$${amount.toStringAsFixed(2)}';
  }

  String _date(dynamic value) {
    if (value == null) return 'Not available';

    final parsed = DateTime.tryParse(value.toString());

    if (parsed == null) return value.toString();

    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/'
        '${parsed.year}';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'approved':
      case 'repaid':
      case 'completed':
      case 'paid':
        return _mint;
      case 'overdue':
      case 'defaulted':
      case 'failed':
        return Colors.redAccent;
      default:
        return Colors.orange;
    }
  }

  bool get _canRepay {
    if (_loan == null) return false;

    final status = _loan!['status']?.toString().toLowerCase() ?? '';

    return ['active', 'partially_paid', 'overdue'].contains(status) &&
        _number(_loan!['outstanding_principal']) > 0;
  }

  double get _outstanding => _number(_loan?['outstanding_principal']);

  String get _currency => _loan?['currency']?.toString().toUpperCase() ?? 'USD';

  int get _currencyDecimals => _currency == 'KHR' ? 0 : 2;

  void _setFullBalance() {
    _repaymentController.text = _outstanding.toStringAsFixed(_currencyDecimals);
  }

  Future<void> _submitRepayment() async {
    if (_isRepaying || !_canRepay) return;

    final amountText = _repaymentController.text.trim();
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      _showMessage('Please enter a valid repayment amount.');
      return;
    }

    if (_currencyDecimals == 0 && !RegExp(r'^\d+$').hasMatch(amountText)) {
      _showMessage('KHR repayments must use whole numbers.');
      return;
    }

    if (_currencyDecimals == 2 &&
        !RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(amountText)) {
      _showMessage('USD repayments can have up to 2 decimal places.');
      return;
    }

    if (amount > _outstanding) {
      _showMessage(
        'Repayment cannot exceed ${_money(_outstanding, _currency)}.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Confirm repayment',
            style: TextStyle(color: _textColor, fontWeight: FontWeight.w800),
          ),
          content: Text(
            'You are about to repay '
            '${_money(amount, _currency)}.\n\n'
            'This payment will reduce your outstanding loan balance. '
            'Your original 5% upfront interest will not be refunded.',
            style: TextStyle(color: _mutedColor, height: 1.5, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Cancel', style: TextStyle(color: _mutedColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _mint,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm payment'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRepaying = true);

    try {
      final response = await QuickLoanService.repayLoan(
        token: _activeToken!,
        loanId: _activeLoanId!,
        amount: amount,
        idempotencyKey: _repaymentKeyFor(amount),
      );

      if (!mounted) return;

      if (response['success'] == true) {
        _pendingRepaymentKey = null;
        _pendingRepaymentAmount = null;
        _repaymentController.clear();

        await _loadLoan();

        if (!mounted) return;

        _showMessage(
          response['message']?.toString() ??
              'Repayment completed successfully.',
          success: true,
        );
      } else {
        _showMessage(
          response['message']?.toString() ??
              'Repayment could not be completed.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isRepaying = false);
      }
    }
  }

  String _repaymentKeyFor(double amount) {
    final canonicalAmount = amount.toStringAsFixed(_currencyDecimals);
    if (_pendingRepaymentAmount != canonicalAmount || _pendingRepaymentKey == null) {
      _pendingRepaymentAmount = canonicalAmount;
      _pendingRepaymentKey = 'nana-repay-$_activeLoanId-'
          '${DateTime.now().microsecondsSinceEpoch}';
    }
    return _pendingRepaymentKey!;
  }

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? const Color(0xFF178A70) : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
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
          'Loan Details',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadLoan,
            icon: Icon(Icons.refresh_rounded, color: _mint),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading && _loan == null
            ? Center(child: CircularProgressIndicator(color: _mint))
            : _errorMessage != null && _loan == null
            ? _buildError()
            : _loan == null
            ? _buildError()
            : RefreshIndicator(
                color: _mint,
                onRefresh: _loadLoan,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 18),
                    _buildAmountsCard(),
                    const SizedBox(height: 18),
                    _buildScheduleCard(),
                    if (_canRepay) ...[
                      const SizedBox(height: 18),
                      _buildRepaymentForm(),
                    ],
                    const SizedBox(height: 22),
                    _buildRepaymentHeader(),
                    const SizedBox(height: 12),
                    _buildRepayments(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = _loan!['status']?.toString() ?? 'Unknown';
    final currency = _currency;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_mint, const Color(0xFF178A70)]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 9),
              const Text(
                'NANA QUICK LOAN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Outstanding principal',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            _money(_loan!['outstanding_principal'], currency),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Loan #${_loan!['id']}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountsCard() {
    final currency = _currency;

    return _sectionCard(
      title: 'Loan breakdown',
      children: [
        _detailRow('Loan principal', _money(_loan!['principal'], currency)),
        _detailRow(
          'Upfront interest',
          _money(_loan!['upfront_interest'], currency),
        ),
        _detailRow(
          'Amount disbursed',
          _money(_loan!['disbursed_amount'], currency),
        ),
        _detailRow(
          'Outstanding principal',
          _money(_loan!['outstanding_principal'], currency),
          highlight: true,
        ),
        _detailRow(
          'Interest rate',
          '${_number(_loan!['interest_rate']).toStringAsFixed(2)}%',
        ),
      ],
    );
  }

  Widget _buildScheduleCard() {
    return _sectionCard(
      title: 'Repayment schedule',
      children: [
        _detailRow('Loan term', '${_loan!['term_days'] ?? '-'} days'),
        _detailRow('Disbursement date', _date(_loan!['disbursed_at'])),
        _detailRow('Due date', _date(_loan!['due_at'])),
        _detailRow('Repaid date', _date(_loan!['repaid_at'])),
      ],
    );
  }

  Widget _buildRepaymentForm() {
    return _sectionCard(
      title: 'Make a repayment',
      children: [
        Text(
          'You can repay part or all of your outstanding balance at any time.',
          style: TextStyle(color: _mutedColor, fontSize: 11, height: 1.5),
        ),
        const SizedBox(height: 16),
        Text(
          'Outstanding balance: ${_money(_outstanding, _currency)}',
          style: TextStyle(
            color: _mint,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _repaymentController,
          enabled: !_isRepaying,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: _textColor, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            labelText: 'Repayment amount ($_currency)',
            labelStyle: TextStyle(color: _mutedColor),
            prefixIcon: Icon(Icons.payments_outlined, color: _mint),
            filled: true,
            fillColor: _backgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _mint, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isRepaying ? null : _setFullBalance,
            child: Text(
              'Pay full balance',
              style: TextStyle(color: _mint, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 49,
          child: ElevatedButton(
            onPressed: _isRepaying ? null : _submitRepayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: _mint,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _mint.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _isRepaying
                ? const SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Repay loan',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Note: Your original upfront interest is not refunded when you repay early.',
          style: TextStyle(color: _mutedColor, fontSize: 10, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildRepaymentHeader() {
    final repayments = _loan!['repayments'];
    final count = repayments is List ? repayments.length : 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Repayment history',
          style: TextStyle(
            color: _textColor,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          '$count records',
          style: TextStyle(color: _mutedColor, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildRepayments() {
    final raw = _loan!['repayments'];
    final repayments = raw is List ? raw : [];
    final currency = _currency;

    if (repayments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long_rounded, color: _mint, size: 32),
            const SizedBox(height: 10),
            Text(
              'No repayment records yet',
              style: TextStyle(color: _textColor, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              'Your repayment activity will appear here.',
              style: TextStyle(color: _mutedColor, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return Column(
      children: repayments.whereType<Map>().map((item) {
        final repayment = Map<String, dynamic>.from(item);
        final status = repayment['status']?.toString() ?? 'Unknown';
        final color = _statusColor(status);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: _mint, size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Repayment',
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              _detailRow(
                'Amount due',
                _money(repayment['amount_due'], currency),
              ),
              _detailRow(
                'Amount collected',
                _money(repayment['amount_collected'], currency),
              ),
              _detailRow(
                'Remaining',
                _money(repayment['remaining_amount'], currency),
                highlight: true,
              ),
              _detailRow('Processed date', _date(repayment['processed_at'])),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _textColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 13),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: _mutedColor, fontSize: 11),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: highlight ? _mint : _textColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 38,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Loan details could not be loaded.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _mutedColor),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadLoan,
              child: Text('Try again', style: TextStyle(color: _mint)),
            ),
          ],
        ),
      ),
    );
  }
}
