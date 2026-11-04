import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';
import 'package:digital_wallet_app/features/wallet/presentation/payment_confirmation_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/transaction_verification_dialog.dart';

class BillPaymentScreen extends StatefulWidget {
  BillPaymentScreen({super.key});

  @override
  State<BillPaymentScreen> createState() => _BillPaymentScreenState();
}

class _BillPaymentScreenState extends State<BillPaymentScreen> {
  // ============================================================
  // FORM
  // ============================================================

  final _formKey = GlobalKey<FormState>();

  final _consumerController = TextEditingController();
  final _amountController = TextEditingController();

  // ============================================================
  // TOKEN
  // ============================================================

  String _activeToken = '';

  bool _isInitialized = false;

  // ============================================================
  // CATEGORY
  // ============================================================

  String _selectedCategory = 'water';

  // ============================================================
  // MERCHANT
  // ============================================================

  List<Map<String, dynamic>> _merchants = [];

  Map<String, dynamic>? _selectedMerchant;

  bool _isLoadingMerchants = false;

  // ============================================================
  // WALLETS
  // ============================================================

  List<WalletModel> _wallets = [];

  String _selectedCurrency = 'USD';

  bool _isLoadingWallets = false;

  // ============================================================
  // CATEGORY DATA
  // ============================================================

  static const List<Map<String, dynamic>> _categories = [
    {'value': 'water', 'label': 'Water', 'icon': Icons.water_drop_rounded},
    {
      'value': 'electricity',
      'label': 'Electricity',
      'icon': Icons.bolt_rounded,
    },
    {'value': 'mobile', 'label': 'Mobile', 'icon': Icons.phone_android_rounded},
    {'value': 'internet', 'label': 'Internet', 'icon': Icons.language_rounded},
    {'value': 'education', 'label': 'Education', 'icon': Icons.school_rounded},
    {
      'value': 'government',
      'label': 'Government',
      'icon': Icons.account_balance_rounded,
    },
    {'value': 'retail', 'label': 'Retail', 'icon': Icons.shopping_bag_rounded},
    {
      'value': 'food',
      'label': 'Food & Beverage',
      'icon': Icons.restaurant_rounded,
    },
    {'value': 'other', 'label': 'Other', 'icon': Icons.more_horiz_rounded},
  ];

  // ============================================================
  // QUICK AMOUNTS
  // ============================================================

  static const List<double> _usdQuickAmounts = [5.00, 10.00, 20.00, 50.00];

  static const List<double> _khrQuickAmounts = [10000, 20000, 50000, 100000];

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

      if (_activeToken.isNotEmpty) {
        _loadInitialData();
      }
    }
  }

  // ============================================================
  // INITIAL DATA
  // ============================================================

  Future<void> _loadInitialData() async {
    await Future.wait([_loadWallets(), _loadMerchants()]);
  }

  // ============================================================
  // LOAD WALLETS
  // ============================================================

  Future<void> _loadWallets() async {
    if (_activeToken.isEmpty) return;

    if (mounted) {
      setState(() {
        _isLoadingWallets = true;
      });
    }

    try {
      final wallets = await WalletService.fetchWalletBalances(_activeToken);

      if (!mounted) return;

      setState(() {
        _wallets = wallets;
        _isLoadingWallets = false;
      });
    } catch (e) {
      debugPrint('❌ Failed to load wallet balances: $e');

      if (!mounted) return;

      setState(() {
        _wallets = [];
        _isLoadingWallets = false;
      });
    }
  }

  // ============================================================
  // LOAD MERCHANTS
  // ============================================================

  Future<void> _loadMerchants() async {
    if (_activeToken.isEmpty) return;

    if (mounted) {
      setState(() {
        _isLoadingMerchants = true;
        _selectedMerchant = null;
        _merchants = [];
      });
    }

    try {
      final merchants = await WalletService.fetchMerchants(
        token: _activeToken,
        category: _selectedCategory,
      );

      if (!mounted) return;

      setState(() {
        _merchants = merchants;
        _isLoadingMerchants = false;
      });
    } catch (e) {
      debugPrint('❌ Failed to load merchants: $e');

      if (!mounted) return;

      setState(() {
        _merchants = [];
        _selectedMerchant = null;
        _isLoadingMerchants = false;
      });
    }
  }

  // ============================================================
  // SELECT CATEGORY
  // ============================================================

  Future<void> _selectCategory(String category) async {
    if (_selectedCategory == category && !_isLoadingMerchants) {
      return;
    }

    setState(() {
      _selectedCategory = category;
      _selectedMerchant = null;
      _merchants = [];
    });

    await _loadMerchants();
  }

  // ============================================================
  // SELECT MERCHANT
  // ============================================================

  void _selectMerchant(Map<String, dynamic> merchant) {
    setState(() {
      _selectedMerchant = merchant;
    });
  }

  // ============================================================
  // WALLET HELPERS
  // ============================================================

  WalletModel? get _selectedWallet {
    for (final wallet in _wallets) {
      if (wallet.currency.toUpperCase() == _selectedCurrency) {
        return wallet;
      }
    }

    return null;
  }

  double get _selectedBalance {
    return _selectedWallet?.balance ?? 0.00;
  }

  bool get _isKhr {
    return _selectedCurrency == 'KHR';
  }

  String get _currencySymbol {
    return _isKhr ? '៛' : '\$';
  }

  int get _currencyDecimals {
    return _isKhr ? 0 : 2;
  }

  List<double> get _quickAmounts {
    return _isKhr ? _khrQuickAmounts : _usdQuickAmounts;
  }

  // ============================================================
  // AMOUNT
  // ============================================================

  double get _amount {
    return double.tryParse(_amountController.text.trim()) ?? 0.00;
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(_currencyDecimals);
  }

  String _formatCurrency(double amount) {
    return '$_currencySymbol${_formatAmount(amount)}';
  }

  // ============================================================
  // CHANGE CURRENCY
  // ============================================================

  void _selectCurrency(String currency) {
    if (_selectedCurrency == currency) {
      return;
    }

    setState(() {
      _selectedCurrency = currency;

      _amountController.clear();
    });
  }

  // ============================================================
  // SET QUICK AMOUNT
  // ============================================================

  void _setAmount(double amount) {
    setState(() {
      _amountController.text = amount.toStringAsFixed(_currencyDecimals);
    });
  }

  // ============================================================
  // MERCHANT NAME
  // ============================================================

  String get _merchantName {
    return _selectedMerchant?['merchant_name']?.toString() ?? 'Select Merchant';
  }

  String get _merchantCode {
    return _selectedMerchant?['merchant_code']?.toString() ?? '';
  }

  String get _merchantDescription {
    return _selectedMerchant?['description']?.toString() ?? '';
  }

  int? get _merchantId {
    final value = _selectedMerchant?['id'];

    return int.tryParse(value?.toString() ?? '');
  }

  // ============================================================
  // SUBMIT BILL PAYMENT
  // ============================================================

  Future<void> _handleBillSubmit() async {
    FocusScope.of(context).unfocus();

    // ----------------------------------------------------------
    // TOKEN
    // ----------------------------------------------------------

    if (_activeToken.isEmpty) {
      _showError('Authentication token is missing. Please login again.');
      return;
    }

    // ----------------------------------------------------------
    // MERCHANT
    // ----------------------------------------------------------

    if (_selectedMerchant == null || _merchantId == null) {
      _showError('Please select a merchant.');
      return;
    }

    // ----------------------------------------------------------
    // FORM
    // ----------------------------------------------------------

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // ----------------------------------------------------------
    // AMOUNT
    // ----------------------------------------------------------

    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      _showError('Please enter a valid bill amount.');
      return;
    }

    // ----------------------------------------------------------
    // BALANCE
    // ----------------------------------------------------------

    if (amount > _selectedBalance) {
      _showError('Insufficient $_selectedCurrency wallet balance.');
      return;
    }

    // ----------------------------------------------------------
    // PAYMENT CONFIRMATION
    // ----------------------------------------------------------

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return PaymentConfirmationScreen(
            token: _activeToken,

            paymentType: 'bill_payment',

            recipient: '$_merchantName - ${_consumerController.text.trim()}',

            amount: amount,

            currency: _selectedCurrency,

            description:
                '$_merchantName | Account: ${_consumerController.text.trim()}',

            // ------------------------------------------------
            // CONFIRM & PAY
            // ------------------------------------------------
            onConfirm: () async {
              // ----------------------------------------------
              // TRANSACTION VERIFICATION
              // PIN OR BIOMETRIC
              // ----------------------------------------------

              final verificationMethod =
                  await showDialog<TransactionVerificationMethod>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) {
                      return TransactionVerificationDialog(token: _activeToken);
                    },
                  );

              // ----------------------------------------------
              // CANCELLED
              // ----------------------------------------------

              if (verificationMethod == null ||
                  verificationMethod ==
                      TransactionVerificationMethod.cancelled) {
                return {
                  'status': 'error',
                  'message': 'Transaction verification was cancelled.',
                };
              }

              // ----------------------------------------------
              // PIN
              // ----------------------------------------------

              if (verificationMethod == TransactionVerificationMethod.pin) {
                final pinVerified = await Navigator.pushNamed(
                  context,
                  '/transaction-pin-verify',
                  arguments: _activeToken,
                );

                if (pinVerified != true) {
                  return {
                    'status': 'error',
                    'message': 'Transaction PIN verification failed.',
                  };
                }

                debugPrint('✅ Bill payment PIN verified.');
              }

              // ----------------------------------------------
              // BIOMETRIC
              // ----------------------------------------------

              if (verificationMethod ==
                  TransactionVerificationMethod.biometric) {
                debugPrint('✅ Bill payment biometric verification successful.');
              }

              // ----------------------------------------------
              // IDEMPOTENCY KEY
              // ----------------------------------------------

              final uniqueKey = 'BILL-${DateTime.now().millisecondsSinceEpoch}';

              try {
                // --------------------------------------------
                // BILL PAYMENT API
                // --------------------------------------------

                final paymentResult = await WalletService.executeBillPayment(
                  token: _activeToken,

                  merchantId: _merchantId!,

                  consumerNumber: _consumerController.text.trim(),

                  amount: amount,

                  currency: _selectedCurrency,

                  idempotencyKey: uniqueKey,
                );

                return paymentResult;
              } catch (e) {
                debugPrint('❌ Bill Payment Error: $e');

                return {
                  'status': 'error',
                  'message':
                      'Unable to process bill payment. Please try again.',
                };
              }
            },
          );
        },
      ),
    );

    // ----------------------------------------------------------
    // SUCCESS
    // ----------------------------------------------------------

    if (!mounted) return;

    if (result == true) {
      _clearForm();

      await _loadWallets();
    }
  }

  // ============================================================
  // CLEAR FORM
  // ============================================================

  void _clearForm() {
    _consumerController.clear();
    _amountController.clear();

    setState(() {});
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
  // INPUT STYLE
  // ============================================================

  InputDecoration _inputStyle({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,

      hintStyle: TextStyle(color: AppColors.themeText.withValues(alpha: 0.30), fontSize: 13),

      prefixIcon: Icon(icon, color: AppColors.royalBlue, size: 20),

      filled: true,

      fillColor: AppColors.adaptiveSurface,

      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),

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
            color: highlight ? AppColors.themeText : AppColors.themeText.withValues(alpha: 0.54),
            fontSize: 12,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
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
          'Pay Bills',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _activeToken.isEmpty ? null : _loadInitialData,
            icon: Icon(LucideIcons.refreshCw, size: 20),
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================
      body: SafeArea(
        child: SingleChildScrollView(
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
                  'Pay your bills',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 6),

                Text(
                  'Choose a category and merchant, then pay securely with NaNa Wallet.',
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.54),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),

                SizedBox(height: 26),

                // ==================================================
                // CATEGORY
                // ==================================================
                Text(
                  'Select Category',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 12),

                _buildCategorySelector(),

                SizedBox(height: 28),

                // ==================================================
                // MERCHANT
                // ==================================================
                Text(
                  'Select Merchant',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 12),

                _buildMerchantSelector(),

                SizedBox(height: 28),

                // ==================================================
                // CURRENCY
                // ==================================================
                Text(
                  'Payment Currency',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 12),

                _buildCurrencySelector(),

                SizedBox(height: 28),

                // ==================================================
                // CONSUMER ACCOUNT
                // ==================================================
                Text(
                  'Consumer Account',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 12),

                TextFormField(
                  controller: _consumerController,

                  keyboardType: TextInputType.text,

                  style: TextStyle(color: AppColors.themeText, fontSize: 15),

                  onChanged: (_) {
                    setState(() {});
                  },

                  decoration: _inputStyle(
                    hint: 'Enter account / consumer number',
                    icon: LucideIcons.hash,
                  ),

                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your consumer account number';
                    }

                    return null;
                  },
                ),

                SizedBox(height: 28),

                // ==================================================
                // AMOUNT
                // ==================================================
                Text(
                  'Payment Amount',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 12),

                TextFormField(
                  controller: _amountController,

                  keyboardType: _isKhr
                      ? TextInputType.number
                      : const TextInputType.numberWithOptions(decimal: true),

                  onChanged: (_) {
                    setState(() {});
                  },

                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),

                  decoration: _inputStyle(
                    hint: _isKhr ? '0' : '0.00',
                    icon: _isKhr
                        ? Icons.currency_exchange_rounded
                        : LucideIcons.dollarSign,
                  ),

                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the payment amount';
                    }

                    final amount = double.tryParse(value.trim());

                    if (amount == null || amount <= 0) {
                      return 'Please enter a valid amount';
                    }

                    if (amount > _selectedBalance) {
                      return 'Insufficient $_selectedCurrency wallet balance';
                    }

                    return null;
                  },
                ),

                SizedBox(height: 14),

                // ==================================================
                // QUICK AMOUNTS
                // ==================================================
                _buildQuickAmounts(),

                SizedBox(height: 12),

                // ==================================================
                // AVAILABLE BALANCE
                // ==================================================
                _buildAvailableBalance(),

                SizedBox(height: 28),

                // ==================================================
                // PAYMENT SUMMARY
                // ==================================================
                _buildPaymentSummary(),

                SizedBox(height: 24),

                // ==================================================
                // SECURITY
                // ==================================================
                _buildSecurityCard(),

                SizedBox(height: 26),

                // ==================================================
                // PAY BUTTON
                // ==================================================
                _buildPayButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CATEGORY SELECTOR
  // ============================================================

  Widget _buildCategorySelector() {
    return SizedBox(
      height: 112,

      child: ListView.separated(
        scrollDirection: Axis.horizontal,

        itemCount: _categories.length,

        separatorBuilder: (_, __) => SizedBox(width: 10),

        itemBuilder: (context, index) {
          final category = _categories[index];

          final value = category['value'].toString();

          final label = category['label'].toString();

          final selected = _selectedCategory == value;

          return GestureDetector(
            onTap: () => _selectCategory(value),

            child: AnimatedContainer(
              duration: Duration(milliseconds: 180),

              width: 92,

              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),

              decoration: BoxDecoration(
                color: selected
                    ? AppColors.royalBlue.withOpacity(0.14)
                    : AppColors.adaptiveSurface,

                borderRadius: BorderRadius.circular(18),

                border: Border.all(
                  color: selected ? AppColors.royalBlue : AppColors.themeText.withValues(alpha: 0.10),
                  width: selected ? 1.5 : 1,
                ),
              ),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Container(
                    width: 42,
                    height: 42,

                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.royalBlue.withOpacity(0.15)
                          : AppColors.themeText.withOpacity(0.05),

                      borderRadius: BorderRadius.circular(13),
                    ),

                    child: Icon(
                      category['icon'] as IconData,

                      color: selected ? AppColors.royalBlue : AppColors.themeText.withValues(alpha: 0.54),

                      size: 21,
                    ),
                  ),

                  SizedBox(height: 8),

                  Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      color: selected ? AppColors.themeText : AppColors.themeText.withValues(alpha: 0.60),
                      fontSize: 10,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // MERCHANT SELECTOR
  // ============================================================

  Widget _buildMerchantSelector() {
    if (_isLoadingMerchants) {
      return Container(
        width: double.infinity,

        padding: const EdgeInsets.all(22),

        decoration: BoxDecoration(
          color: AppColors.adaptiveSurface,

          borderRadius: BorderRadius.circular(18),

          border: Border.all(color: AppColors.themeText.withValues(alpha: 0.10)),
        ),

        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.royalBlue,
              ),
            ),

            SizedBox(width: 12),

            Text(
              'Loading merchants...',
              style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.54), fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_merchants.isEmpty) {
      return Container(
        width: double.infinity,

        padding: const EdgeInsets.all(22),

        decoration: BoxDecoration(
          color: AppColors.adaptiveSurface,

          borderRadius: BorderRadius.circular(18),

          border: Border.all(color: AppColors.themeText.withValues(alpha: 0.10)),
        ),

        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,

              decoration: BoxDecoration(
                color: AppColors.themeText.withOpacity(0.05),

                shape: BoxShape.circle,
              ),

              child: Icon(
                LucideIcons.store,
                color: AppColors.themeText.withValues(alpha: 0.38),
                size: 23,
              ),
            ),

            SizedBox(height: 12),

            Text(
              'No merchants available',
              style: TextStyle(
                color: AppColors.themeText.withValues(alpha: 0.70),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 5),

            Text(
              'There are currently no active merchants in this category.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.themeText.withValues(alpha: 0.38),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _merchants.map((merchant) {
        final selected = _selectedMerchant?['id'] == merchant['id'];

        final name = merchant['merchant_name']?.toString() ?? 'Merchant';

        final code = merchant['merchant_code']?.toString() ?? '';

        final description = merchant['description']?.toString() ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),

          child: GestureDetector(
            onTap: () => _selectMerchant(merchant),

            child: AnimatedContainer(
              duration: Duration(milliseconds: 180),

              padding: const EdgeInsets.all(15),

              decoration: BoxDecoration(
                color: selected
                    ? AppColors.royalBlue.withOpacity(0.12)
                    : AppColors.adaptiveSurface,

                borderRadius: BorderRadius.circular(18),

                border: Border.all(
                  color: selected ? AppColors.royalBlue : AppColors.themeText.withValues(alpha: 0.10),

                  width: selected ? 1.5 : 1,
                ),
              ),

              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,

                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.royalBlue.withOpacity(0.15)
                          : AppColors.themeText.withOpacity(0.05),

                      borderRadius: BorderRadius.circular(14),
                    ),

                    child: Icon(
                      Icons.storefront_rounded,

                      color: selected ? AppColors.royalBlue : AppColors.themeText.withValues(alpha: 0.54),

                      size: 23,
                    ),
                  ),

                  SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          name,

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: TextStyle(
                            color: AppColors.themeText,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        if (code.isNotEmpty) SizedBox(height: 3),

                        if (code.isNotEmpty)
                          Text(
                            code,

                            style: TextStyle(
                              color: AppColors.royalBlue,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                        if (description.isNotEmpty) ...[
                          SizedBox(height: 3),

                          Text(
                            description,

                            maxLines: 1,

                            overflow: TextOverflow.ellipsis,

                            style: TextStyle(
                              color: AppColors.themeText.withValues(alpha: 0.38),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(width: 10),

                  Container(
                    width: 22,
                    height: 22,

                    decoration: BoxDecoration(
                      shape: BoxShape.circle,

                      border: Border.all(
                        color: selected ? AppColors.royalBlue : AppColors.themeText.withValues(alpha: 0.30),

                        width: 2,
                      ),
                    ),

                    child: selected
                        ? Center(
                            child: Container(
                              width: 10,
                              height: 10,

                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.royalBlue,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // CURRENCY SELECTOR
  // ============================================================

  Widget _buildCurrencySelector() {
    return Container(
      padding: const EdgeInsets.all(5),

      decoration: BoxDecoration(
        color: AppColors.adaptiveSurface,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: AppColors.themeText.withValues(alpha: 0.10)),
      ),

      child: Row(
        children: [
          Expanded(
            child: _currencyOption(
              currency: 'USD',
              label: 'US Dollar',
              symbol: '\$',
            ),
          ),

          SizedBox(width: 5),

          Expanded(
            child: _currencyOption(
              currency: 'KHR',
              label: 'Khmer Riel',
              symbol: '៛',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CURRENCY OPTION
  // ============================================================

  Widget _currencyOption({
    required String currency,
    required String label,
    required String symbol,
  }) {
    final selected = _selectedCurrency == currency;

    WalletModel? wallet;

    for (final item in _wallets) {
      if (item.currency.toUpperCase() == currency) {
        wallet = item;
        break;
      }
    }

    final balance = wallet?.balance ?? 0.00;

    final formattedBalance = currency == 'KHR'
        ? balance.toStringAsFixed(0)
        : balance.toStringAsFixed(2);

    return GestureDetector(
      onTap: () => _selectCurrency(currency),

      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),

        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),

        decoration: BoxDecoration(
          color: selected
              ? AppColors.royalBlue.withOpacity(0.13)
              : Colors.transparent,

          borderRadius: BorderRadius.circular(12),

          border: Border.all(
            color: selected ? AppColors.royalBlue : Colors.transparent,
          ),
        ),

        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,

              decoration: BoxDecoration(
                color: selected
                    ? AppColors.royalBlue.withOpacity(0.16)
                    : AppColors.themeText.withOpacity(0.05),

                shape: BoxShape.circle,
              ),

              child: Center(
                child: Text(
                  symbol,
                  style: TextStyle(
                    color: selected ? AppColors.royalBlue : AppColors.themeText.withValues(alpha: 0.54),
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    currency,
                    style: TextStyle(
                      color: AppColors.themeText,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 2),

                  Text(
                    '$symbol$formattedBalance',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.38), fontSize: 10),
                  ),
                ],
              ),
            ),

            if (selected)
              Icon(
                LucideIcons.circleCheck,
                color: AppColors.royalBlue,
                size: 19,
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // QUICK AMOUNTS
  // ============================================================

  Widget _buildQuickAmounts() {
    return Row(
      children: _quickAmounts.map((amount) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),

            child: GestureDetector(
              onTap: () => _setAmount(amount),

              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),

                decoration: BoxDecoration(
                  color: AppColors.themeText.withOpacity(0.05),

                  borderRadius: BorderRadius.circular(12),

                  border: Border.all(color: AppColors.themeText.withValues(alpha: 0.10)),
                ),

                child: Text(
                  _formatCurrency(amount),

                  textAlign: TextAlign.center,

                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.70),
                    fontSize: 11,
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

  // ============================================================
  // AVAILABLE BALANCE
  // ============================================================

  Widget _buildAvailableBalance() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),

      decoration: BoxDecoration(
        color: AppColors.royalBlue.withOpacity(0.06),

        borderRadius: BorderRadius.circular(13),

        border: Border.all(color: AppColors.royalBlue.withOpacity(0.12)),
      ),

      child: Row(
        children: [
          Icon(
            LucideIcons.walletCards,
            color: AppColors.royalBlue,
            size: 17,
          ),

          SizedBox(width: 9),

          Expanded(
            child: Text(
              'Available Balance',
              style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.54), fontSize: 11),
            ),
          ),

          if (_isLoadingWallets)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.royalBlue,
              ),
            )
          else
            Text(
              _formatCurrency(_selectedBalance),

              style: TextStyle(
                color: AppColors.themeText,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // PAYMENT SUMMARY
  // ============================================================

  Widget _buildPaymentSummary() {
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
                'Payment Summary',
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          SizedBox(height: 18),

          _summaryRow('Category', _categoryLabel),

          SizedBox(height: 11),

          _summaryRow('Merchant', _merchantName),

          SizedBox(height: 11),

          _summaryRow(
            'Account',
            _consumerController.text.trim().isEmpty
                ? 'Not entered'
                : _consumerController.text.trim(),
          ),

          SizedBox(height: 11),

          _summaryRow('Currency', _selectedCurrency),

          SizedBox(height: 11),

          _summaryRow('Bill Amount', _formatCurrency(_amount)),

          Padding(
            padding: EdgeInsets.symmetric(vertical: 14),

            child: Divider(color: AppColors.themeText.withValues(alpha: 0.10)),
          ),

          _summaryRow(
            'Total Payment',
            _formatCurrency(_amount),
            highlight: true,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CATEGORY LABEL
  // ============================================================

  String get _categoryLabel {
    for (final category in _categories) {
      if (category['value'] == _selectedCategory) {
        return category['label'].toString();
      }
    }

    return _selectedCategory;
  }

  // ============================================================
  // SECURITY CARD
  // ============================================================

  Widget _buildSecurityCard() {
    return Container(
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: AppColors.royalBlue.withOpacity(0.08),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: AppColors.royalBlue.withOpacity(0.18)),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'Secure Payment',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  'Before payment is processed, you can verify the transaction using your Transaction PIN or device biometric.',
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.60),
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

  // ============================================================
  // PAY BUTTON
  // ============================================================

  Widget _buildPayButton() {
    final enabled =
        _selectedMerchant != null &&
        _merchantId != null &&
        _amount > 0 &&
        _consumerController.text.trim().isNotEmpty;

    return Container(
      width: double.infinity,

      decoration: BoxDecoration(
        gradient: enabled
            ? LinearGradient(
                colors: [AppColors.royalBlue, AppColors.neonPink],
              )
            : null,

        color: enabled ? null : AppColors.themeText.withValues(alpha: 0.12),

        borderRadius: BorderRadius.circular(18),
      ),

      child: ElevatedButton(
        onPressed: enabled ? _handleBillSubmit : null,

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
            Icon(LucideIcons.receipt, size: 20),

            SizedBox(width: 10),

            Text(
              'REVIEW & PAY',
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
}
