import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/quick_loan/services/quick_loan_service.dart';

class QuickLoanScreen extends StatefulWidget {
  final String? token;

  const QuickLoanScreen({super.key, this.token});

  @override
  State<QuickLoanScreen> createState() => _QuickLoanScreenState();
}

class _QuickLoanScreenState extends State<QuickLoanScreen> {
  String? _activeToken;

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _loans = [];

  Color get _mint => AppColors.brandMint;
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

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

    if (_activeToken != null && _activeToken!.trim().isNotEmpty && _isLoading) {
      _loadLoans();
    } else if (_activeToken == null || _activeToken!.trim().isEmpty) {
      _isLoading = false;
      _errorMessage = 'Your login session was not found. Please login again.';
    }
  }

  // ==========================================================
  // LOAD LOAN HISTORY
  // ==========================================================

  Future<void> _loadLoans() async {
    if (_activeToken == null || _activeToken!.trim().isEmpty) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await QuickLoanService.fetchLoans(token: _activeToken!);

      if (!mounted) return;

      if (response['success'] == true) {
        final result = response['data'];

        final List<dynamic> loanList = result is Map
            ? (result['data'] as List? ?? [])
            : (result is List ? result : []);

        setState(() {
          _loans = loanList
              .whereType<Map>()
              .map((loan) => Map<String, dynamic>.from(loan))
              .toList();

          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              response['message']?.toString() ?? 'Unable to load loans.';
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

  // ==========================================================
  // MONEY FORMATTING
  // ==========================================================

  double _number(dynamic value) {
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(dynamic value, String currency) {
    final amount = _number(value);

    if (currency.toUpperCase() == 'KHR') {
      return '\u17DB${amount.toStringAsFixed(0)}';
    }

    return '\$${amount.toStringAsFixed(2)}';
  }

  // ==========================================================
  // SEPARATE USD AND KHR SUMMARY TOTALS
  // ==========================================================

  String _summaryAmount({required bool outstanding}) {
    double usd = 0;
    double khr = 0;

    for (final loan in _loans) {
      final currency = loan['currency']?.toString().toUpperCase() ?? 'USD';

      final value = outstanding
          ? loan['outstanding_principal']
          : loan['principal'];

      final amount = _number(value);

      if (currency == 'KHR') {
        khr += amount;
      } else if (currency == 'USD') {
        usd += amount;
      }
    }

    return '\$${usd.toStringAsFixed(2)}\n'
        '\u17DB${khr.toStringAsFixed(0)}';
  }

  // ==========================================================
  // NAVIGATION
  // ==========================================================

  void _openApplyLoan() {
    Navigator.pushNamed(
      context,
      '/quick-loan/apply',
      arguments: _activeToken,
    ).then((result) {
      if (result == true && mounted) {
        _loadLoans();
      }
    });
  }

  void _openLoanDetails(Map<String, dynamic> loan) {
    Navigator.pushNamed(
      context,
      '/quick-loan/details',
      arguments: {'token': _activeToken, 'loanId': loan['id']},
    ).then((result) {
      if (result == true && mounted) {
        _loadLoans();
      }
    });
  }

  // ==========================================================
  // MAIN SCREEN
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        foregroundColor: _textColor,
        title: Text(
          'NaNa Quick Loan',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadLoans,
            icon: Icon(Icons.refresh_rounded, color: _mint),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: _mint))
            : RefreshIndicator(
                color: _mint,
                onRefresh: _loadLoans,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _buildHeroCard(),
                    const SizedBox(height: 20),
                    _buildSummaryCards(),
                    const SizedBox(height: 28),
                    _buildLoanHeader(),
                    const SizedBox(height: 12),
                    if (_errorMessage != null)
                      _buildErrorCard()
                    else if (_loans.isEmpty)
                      _buildEmptyState()
                    else
                      ..._loans.map(_buildLoanCard),
                    const SizedBox(height: 24),
                    _buildLoanInformation(),
                  ],
                ),
              ),
      ),
    );
  }

  // ==========================================================
  // HERO CARD
  // ==========================================================

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_mint, const Color(0xFF178A70)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _mint.withValues(alpha: 0.20),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  LucideIcons.wallet,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'QUICK LOAN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Need extra cash?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Get quick financial support directly in your NaNa Wallet.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _openApplyLoan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF178A70),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Apply for a Loan',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SUMMARY CARDS
  // ==========================================================

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: 'Total Borrowed',
            amount: _summaryAmount(outstanding: false),
            icon: LucideIcons.handCoins,
            iconColor: _mint,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            title: 'Outstanding',
            amount: _summaryAmount(outstanding: true),
            icon: LucideIcons.clock,
            iconColor: const Color(0xFFE5A63B),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 21),
          const SizedBox(height: 13),
          Text(
            title,
            style: TextStyle(
              color: _mutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            amount,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _textColor,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text('USD | KHR', style: TextStyle(color: _mutedColor, fontSize: 9)),
        ],
      ),
    );
  }

  // ==========================================================
  // LOAN HISTORY HEADER
  // ==========================================================

  Widget _buildLoanHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Loan History',
          style: TextStyle(
            color: _textColor,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          '${_loans.length} records',
          style: TextStyle(color: _mutedColor, fontSize: 12),
        ),
      ],
    );
  }

  // ==========================================================
  // LOAN HISTORY CARD
  // ==========================================================

  Widget _buildLoanCard(Map<String, dynamic> loan) {
    final currency = loan['currency']?.toString() ?? 'USD';
    final status = loan['status']?.toString() ?? 'Unknown';
    final outstanding = _number(loan['outstanding_principal']);
    final principal = loan['principal'];

    final statusColor = status.toLowerCase() == 'active'
        ? _mint
        : status.toLowerCase() == 'overdue'
        ? Colors.redAccent
        : _mutedColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: InkWell(
        onTap: () => _openLoanDetails(loan),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: _mint.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(LucideIcons.fileText, color: _mint, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Loan #${loan['id']}',
                          style: TextStyle(
                            color: _textColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${loan['term_days'] ?? '-'} days repayment term',
                          style: TextStyle(color: _mutedColor, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: _borderColor, height: 1),
              const SizedBox(height: 13),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _loanAmountColumn('Principal', _money(principal, currency)),
                  _loanAmountColumn(
                    'Outstanding',
                    _money(outstanding, currency),
                    alignEnd: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'View loan details',
                    style: TextStyle(
                      color: _mint,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded, color: _mint, size: 13),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loanAmountColumn(
    String label,
    String value, {
    bool alignEnd = false,
  }) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: _mutedColor, fontSize: 10)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: _textColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // EMPTY STATE
  // ==========================================================

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.wallet, size: 38, color: _mint),
          const SizedBox(height: 12),
          Text(
            'No loans yet',
            style: TextStyle(
              color: _textColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your loan applications and repayment history will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _mutedColor, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // ERROR STATE
  // ==========================================================

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _loadLoans,
            child: Text('Try again', style: TextStyle(color: _mint)),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // LOAN INFORMATION
  // ==========================================================

  Widget _buildLoanInformation() {
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
          Row(
            children: [
              Icon(LucideIcons.info, color: _mint, size: 19),
              const SizedBox(width: 8),
              Text(
                'Loan information',
                style: TextStyle(
                  color: _textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _informationRow('Maximum loan', '\$100 equivalent'),
          _informationRow('Interest rate', '5% upfront'),
          _informationRow('Available terms', '7, 14, or 30 days'),
          _informationRow('Approval', 'Automatic'),
          const SizedBox(height: 9),
          Text(
            'Interest is deducted before disbursement. You repay the principal amount shown in your loan agreement.',
            style: TextStyle(color: _mutedColor, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _informationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: _mutedColor, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              color: _textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
