import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';

class SplitBillScreen extends StatefulWidget {
  SplitBillScreen({super.key});

  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _totalController = TextEditingController();
  final _memberEmailController = TextEditingController();

  final List<String> _emailsList = [];

  String _activeToken = '';
  bool _isInitialized = false;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInitialized) {
      final routeArgs = ModalRoute.of(context)?.settings.arguments;

      if (routeArgs is String) {
        _activeToken = routeArgs.trim();
      }

      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _totalController.dispose();
    _memberEmailController.dispose();
    super.dispose();
  }

  void _addMemberEmailRow() {
    final email = _memberEmailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      _showMessage('Enter a participant email address.', Colors.orange);
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      _showMessage('Please enter a valid email address.', Colors.orange);
      return;
    }

    if (_emailsList.contains(email)) {
      _showMessage('This participant has already been added.', Colors.orange);
      return;
    }

    setState(() {
      _emailsList.add(email);
      _memberEmailController.clear();
    });
  }

  void _removeMember(String email) {
    setState(() {
      _emailsList.remove(email);
    });
  }

  void _setQuickAmount(double amount) {
    _totalController.text = amount.toStringAsFixed(2);
    setState(() {});
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

  Future<void> _handleSplitExecutionSubmit() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    // ----------------------------------------------------------
    // TOKEN
    // ----------------------------------------------------------

    if (_activeToken.isEmpty) {
      _showMessage(
        'Authentication token is missing. Please login again.',
        Colors.redAccent,
      );
      return;
    }

    // ----------------------------------------------------------
    // FORM
    // ----------------------------------------------------------

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // ----------------------------------------------------------
    // PARTICIPANTS
    // ----------------------------------------------------------

    if (_emailsList.isEmpty) {
      _showMessage(
        'Add at least one participant before continuing.',
        Colors.orange,
      );
      return;
    }

    // ----------------------------------------------------------
    // AMOUNT
    // ----------------------------------------------------------

    final totalAmount = double.tryParse(_totalController.text.trim()) ?? 0.0;

    if (totalAmount <= 0) {
      _showMessage('Please enter a valid total amount.', Colors.orange);
      return;
    }

    // ----------------------------------------------------------
    // CONFIRMATION
    // ----------------------------------------------------------

    final confirmed = await _showConfirmationDialog(totalAmount);

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
      // --------------------------------------------------------
      // API
      // --------------------------------------------------------

      final res = await WalletService.submitSplitBill(
        token: _activeToken,
        title: _titleController.text.trim(),
        totalAmount: totalAmount,
        memberEmails: _emailsList,
        currency: 'USD',
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
          res['message']?.toString() ??
              'Your split bill has been created successfully.',
        );

        return;
      }

      // --------------------------------------------------------
      // ERROR
      // --------------------------------------------------------

      _showErrorDialog(
        WalletService.readableErrorMessage(
          res,
          fallback: 'Unable to create the split bill.',
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showErrorDialog('Unable to process the split bill. Please try again.');
    }
  }

  Future<bool> _showConfirmationDialog(double totalAmount) async {
    final participantCount = _emailsList.length + 1;
    final perPerson = totalAmount / participantCount;

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
                LucideIcons.receiptText,
                color: AppColors.royalBlue,
                size: 23,
              ),
              SizedBox(width: 10),
              Text(
                'Review Split Bill',
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
              _dialogRow('Expense', _titleController.text.trim()),
              SizedBox(height: 12),
              _dialogRow('Total Bill', '\$${totalAmount.toStringAsFixed(2)}'),
              SizedBox(height: 12),
              _dialogRow('Participants', '$participantCount people'),
              SizedBox(height: 12),
              _dialogRow(
                'Each Person',
                '\$${perPerson.toStringAsFixed(2)}',
                valueColor: Colors.greenAccent,
              ),
              SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.royalBlue.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: AppColors.royalBlue.withOpacity(0.12),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LucideIcons.info,
                      color: AppColors.royalBlue,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Added emails must belong to NaNa Wallet accounts. Your share is included; any rounding remainder stays with you.',
                        style: TextStyle(
                          color: AppColors.themeText.withValues(alpha: 0.54),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
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
                  color: AppColors.themeText.withValues(alpha: 0.54),
                  fontWeight: FontWeight.w600,
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
                'CREATE SPLIT',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Widget _dialogRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.themeText, fontSize: 12)),
        SizedBox(width: 15),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? AppColors.themeText,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showSuccessDialog(String message) async {
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
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.greenAccent.withOpacity(0.10),
                ),
                child: Icon(
                  LucideIcons.circleCheck,
                  color: Colors.greenAccent,
                  size: 58,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Split Bill Created',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 9),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.themeText.withValues(alpha: 0.54),
                  fontSize: 13,
                  height: 1.45,
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
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
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withOpacity(0.10),
                ),
                child: Icon(
                  LucideIcons.circleX,
                  color: Colors.redAccent,
                  size: 52,
                ),
              ),
              SizedBox(height: 18),
              Text(
                'Split Bill Failed',
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.themeText.withValues(alpha: 0.54),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.royalBlue,
                  foregroundColor: AppColors.themeText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: Text(
                  'TRY AGAIN',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  InputDecoration _inputStyle(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: AppColors.themeText.withValues(alpha: 0.60),
        fontSize: 12,
      ),
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.themeText.withValues(alpha: 0.24),
        fontSize: 13,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Icon(icon, color: AppColors.royalBlue, size: 20),
      ),
      prefixIconConstraints: BoxConstraints(minWidth: 45, minHeight: 0),
      filled: true,
      fillColor: AppColors.adaptiveSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
        borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOnTheme(context);
    final grandTotal = double.tryParse(_totalController.text) ?? 0.0;

    final participantCount = _emailsList.length + 1;

    final perPersonShare = grandTotal > 0 ? grandTotal / participantCount : 0.0;

    return Scaffold(
      backgroundColor: AppColors.adaptiveSurfaceAlt,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.themeText),
        title: Text(
          'Split Bill',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoading()
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      SizedBox(height: 24),

                      _sectionTitle(
                        'Expense Details',
                        'Create a shared expense for your group.',
                      ),
                      SizedBox(height: 13),

                      TextFormField(
                        controller: _titleController,
                        style: TextStyle(
                          color: AppColors.themeText,
                          fontSize: 15,
                        ),
                        decoration: _inputStyle(
                          'Expense Name',
                          'e.g. Dinner at Brown',
                          LucideIcons.receiptText,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter an expense name';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 16),

                      TextFormField(
                        controller: _totalController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(
                          color: AppColors.themeText,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _inputStyle(
                          'Total Bill',
                          '0.00',
                          LucideIcons.dollarSign,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final amount = double.tryParse(value?.trim() ?? '');

                          if (amount == null || amount <= 0) {
                            return 'Enter a valid amount';
                          }

                          return null;
                        },
                      ),

                      SizedBox(height: 12),

                      _buildQuickAmounts(),

                      SizedBox(height: 26),

                      if (grandTotal > 0)
                        _buildSplitSummary(
                          grandTotal,
                          participantCount,
                          perPersonShare,
                        ),

                      SizedBox(height: 26),

                      _sectionTitle(
                        'Participants',
                        'Add the people who will share this bill.',
                      ),

                      SizedBox(height: 13),

                      _buildParticipantInput(),

                      SizedBox(height: 14),

                      if (_emailsList.isNotEmpty) _buildParticipantList(),

                      SizedBox(height: 24),

                      _buildSecurityInfo(),

                      SizedBox(height: 28),

                      _buildCreateButton(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.royalBlue.withOpacity(0.16),
            AppColors.neonPink.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: AppColors.royalBlue.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.royalBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              LucideIcons.usersRound,
              color: AppColors.royalBlue,
              size: 29,
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Split expenses easily',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Share the bill with friends and keep everyone on the same page.',
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.54),
                    fontSize: 11,
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

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.themeText.withValues(alpha: 0.38),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAmounts() {
    const amounts = [10.0, 20.0, 50.0, 100.0];

    return Row(
      children: amounts.map((amount) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _setQuickAmount(amount),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.adaptiveSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.themeText.withValues(alpha: 0.10),
                  ),
                ),
                child: Text(
                  '\$${amount.toStringAsFixed(0)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.70),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSplitSummary(double total, int count, double share) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.adaptiveSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.royalBlue.withOpacity(0.16)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.royalBlue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  LucideIcons.calculator,
                  color: AppColors.royalBlue,
                  size: 20,
                ),
              ),
              SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Split Summary',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '$count people',
                style: TextStyle(
                  color: AppColors.themeText.withValues(alpha: 0.38),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.royalBlue.withOpacity(0.10),
                  AppColors.neonPink.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'EACH PERSON PAYS',
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.38),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '\$${share.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 15),
          _summaryRow('Total Bill', '\$${total.toStringAsFixed(2)}'),
          SizedBox(height: 9),
          _summaryRow('Participants', '$count people'),
          SizedBox(height: 9),
          _summaryRow(
            'Equal Share',
            '\$${share.toStringAsFixed(2)}',
            valueColor: Colors.greenAccent,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.themeText, fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.themeText,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantInput() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _memberEmailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: AppColors.themeText, fontSize: 14),
            decoration: _inputStyle(
              'Participant Email',
              'friend@example.com',
              LucideIcons.mail,
            ),
            onSubmitted: (_) => _addMemberEmailRow(),
          ),
        ),
        SizedBox(width: 10),
        Container(
          height: 58,
          width: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.royalBlue, AppColors.neonPink],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: IconButton(
            onPressed: _addMemberEmailRow,
            icon: Icon(LucideIcons.plus, color: AppColors.themeText, size: 23),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantList() {
    return Column(
      children: [
        Row(
          children: [
            Text(
              'Added Participants',
              style: TextStyle(
                color: AppColors.themeText.withValues(alpha: 0.60),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Spacer(),
            Text(
              '${_emailsList.length} added',
              style: TextStyle(
                color: AppColors.royalBlue,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        ..._emailsList.asMap().entries.map((entry) {
          final index = entry.key;
          final email = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.adaptiveSurface,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: AppColors.themeText.withValues(alpha: 0.10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.royalBlue.withOpacity(0.22),
                        AppColors.neonPink.withOpacity(0.10),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: AppColors.themeText,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 11),
                Expanded(
                  child: Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.themeText,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _removeMember(email),
                  splashRadius: 20,
                  icon: Icon(
                    LucideIcons.trash2,
                    color: AppColors.themeText.withValues(alpha: 0.38),
                    size: 17,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.themeText.withOpacity(0.025),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.themeText.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: AppColors.royalBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              LucideIcons.shieldCheck,
              color: AppColors.royalBlue,
              size: 18,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NaNa Wallet Protected',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Your split bill request is securely processed through your authenticated wallet account.',
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.38),
                    fontSize: 10.5,
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

  Widget _buildCreateButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.royalBlue, AppColors.neonPink],
        ),
        borderRadius: BorderRadius.circular(17),
      ),
      child: ElevatedButton(
        onPressed: _handleSplitExecutionSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.themeText,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.send, size: 18),
            SizedBox(width: 9),
            Text(
              'CREATE SPLIT BILL',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
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
            'Creating Split Bill...',
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Please wait while we process your request.',
            style: TextStyle(
              color: AppColors.themeText.withValues(alpha: 0.38),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
