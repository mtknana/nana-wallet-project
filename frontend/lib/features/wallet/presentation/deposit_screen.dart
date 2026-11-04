import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';

class DepositScreen extends StatefulWidget {
  DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  String _activeToken = "";
  String _selectedCurrency = "USD";
  String _selectedMethod = "Bank Transfer";

  bool _isInitialized = false;
  bool _isLoading = false;

  String _depositReference = "";

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInitialized) {
      final routeArgs = ModalRoute.of(context)?.settings.arguments;

      if (routeArgs is String) {
        _activeToken = routeArgs;
      }

      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // QUICK AMOUNT
  // ------------------------------------------------------------

  void _selectQuickAmount(double value) {
    final dynamicValue = _selectedCurrency == "KHR" ? value * 4000 : value;

    setState(() {
      _amountController.text = dynamicValue.toStringAsFixed(0);
    });
  }

  // ------------------------------------------------------------
  // GENERATE REFERENCE
  // ------------------------------------------------------------

  String _generateReference() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    return "NANA-${timestamp.substring(timestamp.length - 6)}";
  }
  // ------------------------------------------------------------
  // VERIFY TRANSACTION PIN
  // ------------------------------------------------------------

  Future<bool> _verifyTransactionPin() async {
    final result = await Navigator.pushNamed(
      context,
      '/transaction-pin-verify',
      arguments: _activeToken,
    );

    return result == true;
  }
  // ------------------------------------------------------------
  // CONFIRM DEPOSIT
  // ------------------------------------------------------------

  Future<void> _handleDepositSubmit() async {
    FocusScope.of(context).unfocus();

    // ----------------------------------------------------------
    // FORM VALIDATION
    // ----------------------------------------------------------

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // ----------------------------------------------------------
    // TOKEN CHECK
    // ----------------------------------------------------------

    if (_activeToken.trim().isEmpty) {
      _showMessage(
        "Authentication token is missing. Please login again.",
        isSuccess: false,
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      _showMessage("Please enter a valid deposit amount.", isSuccess: false);
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
      final uniqueKey = "DEP-${DateTime.now().millisecondsSinceEpoch}";

      // --------------------------------------------------------
      // API
      // --------------------------------------------------------

      final res = await WalletService.executeDeposit(
        token: _activeToken,
        amount: amount,
        currency: _selectedCurrency,
        idempotencyKey: uniqueKey,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
      // ------------------------------------------------------------
      // DEPOSIT SUCCESS DIALOG
      // ------------------------------------------------------------

      void _showDepositSuccess(double amount) {
        final currencySymbol = _selectedCurrency == "USD" ? "\$" : "៛";

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              backgroundColor: AppColors.adaptiveSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success icon
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.green.withOpacity(0.35),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      LucideIcons.circleCheck,
                      color: Colors.greenAccent,
                      size: 42,
                    ),
                  ),

                  SizedBox(height: 20),

                  Text(
                    "Deposit Successful",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.themeText,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 10),

                  Text(
                    "Your deposit has been successfully processed.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.themeText.withValues(alpha: 0.60),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),

                  SizedBox(height: 20),

                  // Amount
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.themeText.withValues(alpha: 0.10)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "DEPOSIT AMOUNT",
                          style: TextStyle(
                            color: AppColors.themeText.withValues(alpha: 0.38),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),

                        SizedBox(height: 6),

                        Text(
                          "$currencySymbol${_formatAmount(amount)}",
                          style: TextStyle(
                            color: AppColors.themeText,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 14),

                  // Reference
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.receiptText,
                        color: AppColors.neonPink,
                        size: 15,
                      ),
                      SizedBox(width: 6),
                      Text(
                        _depositReference,
                        style: TextStyle(
                          color: AppColors.themeText.withValues(alpha: 0.54),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Done button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // close dialog
                        Navigator.pop(
                          context,
                          true,
                        ); // return to previous screen
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.royalBlue,
                        foregroundColor: AppColors.themeText,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        "DONE",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }

      // --------------------------------------------------------
      // SUCCESS
      // --------------------------------------------------------

      final status = res['status']?.toString().toLowerCase();

      if (status == 'success') {
        _showDepositSuccess(amount);
      } else {
        _showMessage(
          res['message']?.toString() ?? "Unable to submit deposit request.",
          isSuccess: false,
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        "Unable to process deposit. Please try again.",
        isSuccess: false,
      );
    }
  }

  // ------------------------------------------------------------
  // MESSAGE
  // ------------------------------------------------------------

  void _showMessage(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
      ),
    );
  }

  // ------------------------------------------------------------
  // FORMAT AMOUNT
  // ------------------------------------------------------------

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
  }

  // ------------------------------------------------------------
  // INPUT STYLE
  // ------------------------------------------------------------

  InputDecoration _inputStyle(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.themeText.withValues(alpha: 0.70), fontSize: 13),
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.themeText.withValues(alpha: 0.24), fontSize: 13),
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Icon(icon, color: AppColors.royalBlue, size: 20),
      ),
      prefixIconConstraints: BoxConstraints(minWidth: 40, minHeight: 0),
      filled: true,
      fillColor: AppColors.adaptiveSurface,
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.themeText.withValues(alpha: 0.10)),
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

  // ------------------------------------------------------------
  // METHOD CARD
  // ------------------------------------------------------------

  Widget _buildMethodCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _selectedMethod == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod = value;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.royalBlue.withOpacity(0.12)
              : AppColors.adaptiveSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.royalBlue : AppColors.themeText.withValues(alpha: 0.10),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.royalBlue.withOpacity(0.15)
                    : AppColors.themeText.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.royalBlue : AppColors.themeText.withValues(alpha: 0.60),
                size: 23,
              ),
            ),

            SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.themeText,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: AppColors.themeText, fontSize: 11),
                  ),
                ],
              ),
            ),

            Icon(
              isSelected ? LucideIcons.circleCheck : LucideIcons.circle,
              color: isSelected ? AppColors.royalBlue : AppColors.themeText.withValues(alpha: 0.24),
              size: 21,
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // TRANSFER INFORMATION
  // ------------------------------------------------------------

  Widget _buildTransferInfo() {
    if (_selectedMethod != "Bank Transfer") {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.themeText.withOpacity(0.035),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.themeText.withValues(alpha: 0.10)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.info, color: AppColors.royalBlue, size: 21),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Visit a participating NaNa Wallet agent "
                "and provide your wallet account information "
                "and the amount you want to deposit.",
                style: TextStyle(
                  color: AppColors.themeText.withValues(alpha: 0.60),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.royalBlue.withOpacity(0.13),
            AppColors.neonPink.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.royalBlue.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.building2, color: AppColors.royalBlue, size: 21),
              SizedBox(width: 10),
              Text(
                "Bank Transfer Details",
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          SizedBox(height: 18),

          _infoRow("Bank", "NaNa Wallet Settlement"),

          SizedBox(height: 12),

          _infoRow("Account Number", "001 888 888"),

          SizedBox(height: 12),

          _infoRow("Account Name", "NaNa Wallet Co., Ltd."),

          SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.receiptText,
                  color: AppColors.neonPink,
                  size: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Transfer Reference",
                        style: TextStyle(color: AppColors.themeText, fontSize: 10),
                      ),
                      SizedBox(height: 3),
                      Text(
                        _depositReference,
                        style: TextStyle(
                          color: AppColors.themeText,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 12),

          Text(
            "Use the reference above when making your bank transfer.",
            style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.38), fontSize: 10, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: TextStyle(color: AppColors.themeText, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    AppColors.dependOnTheme(context);
    final symbol = _selectedCurrency == "USD" ? "\$" : "៛";

    if (_depositReference.isEmpty) {
      _depositReference = _generateReference();
    }

    return Scaffold(
      backgroundColor: AppColors.adaptiveSurfaceAlt,

      appBar: AppBar(
        title: Text(
          "Deposit Money",
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.themeText),
      ),

      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.neonPink),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ------------------------------------------------
                    // HEADER ICON
                    // ------------------------------------------------
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.royalBlue.withOpacity(0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.royalBlue.withOpacity(0.20),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          LucideIcons.arrowDownToLine,
                          color: AppColors.royalBlue,
                          size: 40,
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    Text(
                      "Add money to your NaNa Wallet",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.themeText,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 7),

                    Text(
                      "Choose a funding method and follow the instructions.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.themeText, fontSize: 12),
                    ),

                    SizedBox(height: 30),

                    // ------------------------------------------------
                    // DEPOSIT METHOD
                    // ------------------------------------------------
                    Text(
                      "DEPOSIT METHOD",
                      style: TextStyle(
                        color: AppColors.themeText,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),

                    SizedBox(height: 10),

                    _buildMethodCard(
                      title: "Bank Transfer",
                      subtitle: "Transfer money from your bank account",
                      icon: LucideIcons.building2,
                      value: "Bank Transfer",
                    ),

                    SizedBox(height: 10),

                    _buildMethodCard(
                      title: "Cash / Agent",
                      subtitle: "Deposit cash through a NaNa agent",
                      icon: LucideIcons.banknote,
                      value: "Cash / Agent",
                    ),

                    SizedBox(height: 25),

                    // ------------------------------------------------
                    // WALLET
                    // ------------------------------------------------
                    Text(
                      "DEPOSIT TO",
                      style: TextStyle(
                        color: AppColors.themeText.withValues(alpha: 0.54),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),

                    SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: _selectedCurrency,
                      dropdownColor: AppColors.adaptiveSurface,
                      style: TextStyle(color: AppColors.themeText, fontSize: 14),
                      decoration: _inputStyle(
                        "Wallet",
                        "",
                        LucideIcons.walletCards,
                      ),
                      items:  [
                        DropdownMenuItem(
                          value: "USD",
                          child: Text("USD Wallet — United States Dollar (\$)"),
                        ),
                        DropdownMenuItem(
                          value: "KHR",
                          child: Text("KHR Wallet — Cambodian Riel (៛)"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          _selectedCurrency = value;
                          _amountController.clear();
                          _depositReference = _generateReference();
                        });
                      },
                    ),

                    SizedBox(height: 20),

                    // ------------------------------------------------
                    // AMOUNT
                    // ------------------------------------------------
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(color: AppColors.themeText, fontSize: 15),
                      decoration: _inputStyle(
                        "Amount",
                        "0.00",
                        LucideIcons.banknoteArrowDown,
                      ),
                      validator: (value) {
                        final amount = double.tryParse(value?.trim() ?? '');

                        if (amount == null || amount <= 0) {
                          return "Enter a valid amount";
                        }

                        return null;
                      },
                    ),

                    SizedBox(height: 12),

                    // ------------------------------------------------
                    // QUICK AMOUNTS
                    // ------------------------------------------------
                    Row(
                      children: [10.0, 50.0, 100.0, 500.0].map((amount) {
                        final displayLabel = _selectedCurrency == "USD"
                            ? "\$${amount.toStringAsFixed(0)}"
                            : "${(amount * 4000).toStringAsFixed(0)}៛";

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(
                                displayLabel,
                                style: TextStyle(
                                  color: AppColors.themeText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              selected: false,
                              backgroundColor: AppColors.adaptiveSurface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: AppColors.themeText.withValues(alpha: 0.10)),
                              ),
                              onSelected: (_) => _selectQuickAmount(amount),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    SizedBox(height: 25),

                    // ------------------------------------------------
                    // TRANSFER INSTRUCTIONS
                    // ------------------------------------------------
                    _buildTransferInfo(),

                    SizedBox(height: 28),

                    // ------------------------------------------------
                    // CONFIRM BUTTON
                    // ------------------------------------------------
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.royalBlue, AppColors.neonPink],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        onPressed: _handleDepositSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _selectedMethod == "Bank Transfer"
                              ? "I'VE MADE THE TRANSFER"
                              : "CONFIRM CASH DEPOSIT",
                          style: TextStyle(
                            color: AppColors.themeText,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 14),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.shieldCheck,
                          color: AppColors.themeText.withValues(alpha: 0.30),
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          "Secure deposit processing",
                          style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.30), fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
