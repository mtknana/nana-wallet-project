import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';
import 'package:digital_wallet_app/features/wallet/presentation/payment_confirmation_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/transaction_verification_dialog.dart';

class P2pTransferScreen extends StatefulWidget {
  P2pTransferScreen({super.key});

  @override
  State<P2pTransferScreen> createState() => _P2pTransferScreenState();
}

class _P2pTransferScreenState extends State<P2pTransferScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  String _activeToken = '';
  String _selectedCurrency = 'USD';

  bool _isInitialized = false;
  bool _isLoadingWallets = false;

  double _usdBalance = 0.0;
  double _khrBalance = 0.0;

  double _selectedAmount = 5.00;

  static const List<double> _usdQuickAmounts = [
    5.00,
    10.00,
    20.00,
    50.00,
    100.00,
  ];

  static const List<double> _khrQuickAmounts = [
    10000,
    20000,
    50000,
    100000,
    200000,
  ];

  bool get _isKhr => _selectedCurrency == 'KHR';

  String get _currencySymbol => _isKhr ? '៛' : '\$';

  int get _currencyDecimals => _isKhr ? 0 : 2;

  double get _selectedWalletBalance => _isKhr ? _khrBalance : _usdBalance;

  List<double> get _quickAmounts =>
      _isKhr ? _khrQuickAmounts : _usdQuickAmounts;

  String _formatAmount(double amount) =>
      amount.toStringAsFixed(_currencyDecimals);

  String _formatCurrency(double amount) =>
      '$_currencySymbol${_formatAmount(amount)}';

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInitialized) {
      final arguments = ModalRoute.of(context)?.settings.arguments;

      if (arguments is String && arguments.trim().isNotEmpty) {
        _activeToken = arguments.trim();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadWalletBalances();
          }
        });
      }

      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // ============================================================
  // CURRENCY / WALLET HELPERS
  // ============================================================

  Future<void> _loadWalletBalances() async {
    if (_activeToken.isEmpty || _isLoadingWallets) {
      return;
    }

    setState(() {
      _isLoadingWallets = true;
    });

    try {
      final result = await WalletService.fetchWallets(token: _activeToken);

      if (!mounted) return;

      if (result['status'] == 'success') {
        final wallets = result['wallets'];

        double usd = 0.0;
        double khr = 0.0;

        if (wallets is List) {
          for (final item in wallets) {
            if (item is WalletModel) {
              if (item.currency.toUpperCase() == 'USD') {
                usd = item.balance;
              }

              if (item.currency.toUpperCase() == 'KHR') {
                khr = item.balance;
              }
            } else if (item is Map) {
              final currency = item['currency']?.toString().toUpperCase();

              final balance =
                  double.tryParse(item['balance']?.toString() ?? '') ?? 0.0;

              if (currency == 'USD') {
                usd = balance;
              }

              if (currency == 'KHR') {
                khr = balance;
              }
            }
          }
        }

        setState(() {
          _usdBalance = usd;
          _khrBalance = khr;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load wallet balances: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingWallets = false;
        });
      }
    }
  }

  void _selectCurrency(String currency) {
    if (currency == _selectedCurrency) {
      return;
    }

    setState(() {
      _selectedCurrency = currency;

      _selectedAmount = currency == 'KHR' ? 10000 : 5.00;

      _amountController.text = _selectedAmount.toStringAsFixed(
        currency == 'KHR' ? 0 : 2,
      );
    });
  }

  // ============================================================
  // HELPERS
  // ============================================================

  double get _amount {
    return double.tryParse(_amountController.text.trim()) ?? 0.00;
  }

  bool get _canSubmit {
    return _emailController.text.trim().isNotEmpty && _amount > 0;
  }

  // ============================================================
  // AMOUNT
  // ============================================================

  void _setAmount(double amount) {
    setState(() {
      _selectedAmount = amount;

      _amountController.text = amount.toStringAsFixed(_currencyDecimals);
    });
  }

  // ============================================================
  // US-036
  // OPEN PAYMENT CONFIRMATION
  // ============================================================

  Future<void> _submitP2pTransfer() async {
    FocusScope.of(context).unfocus();

    // ----------------------------------------------------------
    // TOKEN CHECK
    // ----------------------------------------------------------

    if (_activeToken.isEmpty) {
      _showError('Authentication token is missing. Please login again.');
      return;
    }

    // ----------------------------------------------------------
    // FORM VALIDATION
    // ----------------------------------------------------------

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // ----------------------------------------------------------
    // AMOUNT
    // ----------------------------------------------------------

    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      _showError('Please enter a valid transfer amount.');
      return;
    }

    if (amount > _selectedWalletBalance) {
      _showError('Insufficient $_selectedCurrency wallet balance.');
      return;
    }

    // ----------------------------------------------------------
    // SAVE VALUES BEFORE NAVIGATION
    // ----------------------------------------------------------

    final recipient = _emailController.text.trim();

    final currency = _selectedCurrency;

    final description = _descController.text.trim();

    // ----------------------------------------------------------
    // US-036 PAYMENT CONFIRMATION
    // ----------------------------------------------------------

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return PaymentConfirmationScreen(
            token: _activeToken,
            paymentType: 'transfer',
            recipient: recipient,
            amount: amount,
            currency: currency,
            description: description,

            // --------------------------------------------------
            // CONFIRM & PAY
            // --------------------------------------------------
            onConfirm: () async {
              // ==================================================
              // TRANSACTION VERIFICATION
              // ==================================================

              final verificationMethod =
                  await showDialog<TransactionVerificationMethod>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) {
                      return TransactionVerificationDialog(token: _activeToken);
                    },
                  );

              // ------------------------------------------------
              // USER CANCELLED VERIFICATION
              // ------------------------------------------------

              if (verificationMethod == null ||
                  verificationMethod ==
                      TransactionVerificationMethod.cancelled) {
                return {
                  'status': 'error',
                  'message': 'Transaction verification was cancelled.',
                };
              }

              // ==================================================
              // PIN SELECTED
              // ==================================================

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

                debugPrint('✅ Transaction PIN verified.');
              }

              // ==================================================
              // BIOMETRIC SELECTED
              // ==================================================

              if (verificationMethod ==
                  TransactionVerificationMethod.biometric) {
                debugPrint('✅ Biometric transaction verification successful.');
              }

              // ==================================================
              // CREATE IDEMPOTENCY KEY
              // ==================================================

              final uniqueIdempotencyKey =
                  'P2P-${DateTime.now().millisecondsSinceEpoch}';

              try {
                // ==================================================
                // EXECUTE P2P TRANSFER
                // ==================================================

                final transferResult = await WalletService.executeP2pTransfer(
                  token: _activeToken,
                  email: recipient,
                  amount: amount,
                  idempotencyKey: uniqueIdempotencyKey,
                  description: description,
                  currency: currency,
                );

                return transferResult;
              } catch (e) {
                debugPrint('❌ P2P Transfer Error: $e');

                return {
                  'status': 'error',
                  'message': 'Unable to process transfer. Please try again.',
                };
              }
            },
          );
        },
      ),
    );

    // ----------------------------------------------------------
    // PAYMENT COMPLETED
    // ----------------------------------------------------------

    if (!mounted) return;

    if (result == true) {
      // --------------------------------------------------------
      // SHOW IMMEDIATE SUCCESS POPUP
      // --------------------------------------------------------

      await _showTransferSuccessDialog(
        recipient: recipient,
        amount: amount,
        currency: currency,
      );

      if (!mounted) return;

      // --------------------------------------------------------
      // CLEAR FORM
      // --------------------------------------------------------

      _clearForm();

      // --------------------------------------------------------
      // REFRESH BALANCES
      // --------------------------------------------------------

      await _loadWalletBalances();
    }
  }

  // ============================================================
  // SUCCESS NOTIFICATION POPUP
  // ============================================================

  Future<void> _showTransferSuccessDialog({
    required String recipient,
    required double amount,
    required String currency,
  }) async {
    final symbol = currency == 'KHR' ? '៛' : '\$';

    final formattedAmount = currency == 'KHR'
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 24,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            decoration: BoxDecoration(
              color: AppColors.adaptiveSurface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.royalBlue.withOpacity(0.28),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.royalBlue.withOpacity(0.12),
                  blurRadius: 30,
                  spreadRadius: 2,
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
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.royalBlue.withOpacity(0.20),
                        AppColors.neonPink.withOpacity(0.14),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.royalBlue.withOpacity(0.45),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    LucideIcons.circleCheck,
                    color: AppColors.royalBlue,
                    size: 40,
                  ),
                ),

                SizedBox(height: 18),

                // ==================================================
                // TITLE
                // ==================================================
                Text(
                  'Transfer Successful',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),

                SizedBox(height: 7),

                Text(
                  'Your money has been sent successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.54),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),

                SizedBox(height: 22),

                // ==================================================
                // AMOUNT CARD
                // ==================================================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 17,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.themeText.withOpacity(0.045),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.themeText.withValues(alpha: 0.10)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Amount Sent',
                        style: TextStyle(color: AppColors.themeText, fontSize: 11),
                      ),

                      SizedBox(height: 6),

                      Text(
                        '$symbol$formattedAmount',
                        style: TextStyle(
                          color: AppColors.themeText,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 4),

                      Text(
                        currency,
                        style: TextStyle(
                          color: AppColors.royalBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 15),

                // ==================================================
                // RECIPIENT
                // ==================================================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.royalBlue.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          LucideIcons.userRound,
                          color: AppColors.royalBlue,
                          size: 18,
                        ),
                      ),

                      SizedBox(width: 11),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recipient',
                              style: TextStyle(
                                color: AppColors.themeText.withValues(alpha: 0.38),
                                fontSize: 10,
                              ),
                            ),

                            SizedBox(height: 3),

                            Text(
                              recipient,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.themeText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 22),

                // ==================================================
                // DONE BUTTON
                // ==================================================
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.royalBlue, AppColors.neonPink],
                      ),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppColors.themeText,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: Text(
                        'DONE',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // CLEAR FORM
  // ============================================================

  void _clearForm() {
    _emailController.clear();
    _amountController.clear();
    _descController.clear();

    setState(() {
      _selectedAmount = 5.00;
    });
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
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    String? suffixText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.themeText.withValues(alpha: 0.30), fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.royalBlue, size: 20),
      suffixText: suffixText,
      suffixStyle: TextStyle(
        color: AppColors.themeText.withValues(alpha: 0.54),
        fontWeight: FontWeight.bold,
      ),
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
        borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  // ============================================================
  // SUMMARY ROW
  // ============================================================

  Widget _summaryRow(
    String title,
    String value, {
    bool highlight = false,
    bool cyan = false,
  }) {
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
            style: TextStyle(
              color: highlight
                  ? AppColors.neonPink
                  : cyan
                  ? Colors.cyanAccent
                  : AppColors.themeText,
              fontSize: highlight ? 16 : 12,
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

        actions: [
          IconButton(
            onPressed: _isLoadingWallets ? null : _loadWalletBalances,
            icon: Icon(
              LucideIcons.refreshCw,
              color: _isLoadingWallets ? AppColors.themeText.withValues(alpha: 0.24) : AppColors.themeText.withValues(alpha: 0.70),
              size: 20,
            ),
          ),
          SizedBox(width: 6),
        ],

        title: Text(
          'Send Money',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(),

                SizedBox(height: 24),

                _buildCurrencySelector(),

                SizedBox(height: 26),

                Text(
                  'Recipient',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 12),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: AppColors.themeText, fontSize: 15),
                  onChanged: (_) {
                    setState(() {});
                  },
                  decoration: _inputDecoration(
                    hint: 'Enter recipient email',
                    icon: LucideIcons.mail,
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';

                    if (email.isEmpty) {
                      return 'Please enter the recipient email';
                    }

                    if (!email.contains('@') || !email.contains('.')) {
                      return 'Please enter a valid email address';
                    }

                    return null;
                  },
                ),

                SizedBox(height: 26),

                Text(
                  'Transfer Amount',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 12),

                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  onChanged: (value) {
                    final parsed = double.tryParse(value);

                    setState(() {
                      if (parsed != null) {
                        _selectedAmount = parsed;
                      }
                    });
                  },
                  decoration: _inputDecoration(
                    hint: _isKhr ? '0' : '0.00',
                    icon: _isKhr ? LucideIcons.coins : LucideIcons.dollarSign,
                    suffixText: _selectedCurrency,
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');

                    if (amount == null || amount <= 0) {
                      return 'Please enter a positive amount';
                    }

                    if (amount > _selectedWalletBalance) {
                      return 'Insufficient $_selectedCurrency wallet balance';
                    }

                    return null;
                  },
                ),

                SizedBox(height: 14),

                Text(
                  'Quick Amount',
                  style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.54), fontSize: 12),
                ),

                SizedBox(height: 9),

                _buildQuickAmounts(),

                SizedBox(height: 26),

                Text(
                  'Message',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 12),

                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(color: AppColors.themeText, fontSize: 14),
                  decoration: _inputDecoration(
                    hint: 'Add a note (optional)',
                    icon: LucideIcons.messageSquare,
                  ),
                ),

                SizedBox(height: 28),

                _buildSummary(),

                SizedBox(height: 22),

                _buildSecurityInfo(),

                SizedBox(height: 24),

                _buildTransferButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _buildHero() {
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.royalBlue.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.royalBlue.withOpacity(0.16),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              LucideIcons.send,
              color: AppColors.royalBlue,
              size: 27,
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Send money instantly',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Transfer funds securely to another NaNa Wallet user.',
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

  // ============================================================
  // USD / KHR SELECTOR
  // ============================================================

  Widget _buildCurrencySelector() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.themeText.withOpacity(0.045),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.themeText.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCurrencyCard(
              'USD',
              _usdBalance,
              LucideIcons.dollarSign,
            ),
          ),
          SizedBox(width: 6),
          Expanded(
            child: _buildCurrencyCard('KHR', _khrBalance, LucideIcons.coins),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyCard(String currency, double balance, IconData icon) {
    final selected = _selectedCurrency == currency;

    final isUsd = currency == 'USD';

    return GestureDetector(
      onTap: () => _selectCurrency(currency),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.royalBlue.withOpacity(0.22),
                    AppColors.neonPink.withOpacity(0.10),
                  ],
                )
              : null,
          color: selected ? null : AppColors.adaptiveSurface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected
                ? AppColors.royalBlue.withOpacity(0.75)
                : AppColors.themeText.withValues(alpha: 0.10),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.royalBlue.withOpacity(0.18)
                    : AppColors.themeText.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: selected ? AppColors.royalBlue : AppColors.themeText.withValues(alpha: 0.54),
                size: 19,
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
                      color: selected ? AppColors.themeText : AppColors.themeText.withValues(alpha: 0.60),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    _isLoadingWallets
                        ? 'Loading...'
                        : '${isUsd ? '\$' : '៛'}${isUsd ? balance.toStringAsFixed(2) : balance.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: selected ? AppColors.themeText.withValues(alpha: 0.70) : AppColors.themeText.withValues(alpha: 0.38),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
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
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _quickAmounts.length,
        separatorBuilder: (_, __) => SizedBox(width: 9),
        itemBuilder: (context, index) {
          final amount = _quickAmounts[index];

          final selected = _selectedAmount == amount;

          return GestureDetector(
            onTap: () => _setAmount(amount),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 17),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.royalBlue.withOpacity(0.14)
                    : AppColors.adaptiveSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppColors.royalBlue : AppColors.themeText.withValues(alpha: 0.10),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Text(
                _formatCurrency(amount),
                style: TextStyle(
                  color: selected ? AppColors.themeText : AppColors.themeText.withValues(alpha: 0.60),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummary() {
    final amount = _amount;

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
                'Transfer Summary',
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          SizedBox(height: 18),

          _summaryRow(
            'Recipient',
            _emailController.text.trim().isEmpty
                ? 'Not entered'
                : _emailController.text.trim(),
          ),

          SizedBox(height: 11),

          _summaryRow('Transfer Amount', _formatCurrency(amount)),

          SizedBox(height: 11),

          _summaryRow(
            'Wallet Balance',
            _formatCurrency(_selectedWalletBalance),
            cyan: true,
          ),

          Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: AppColors.themeText.withValues(alpha: 0.10)),
          ),

          _summaryRow('Amount Sent', _formatCurrency(amount), highlight: true),
        ],
      ),
    );
  }

  // ============================================================
  // SECURITY INFO
  // ============================================================

  Widget _buildSecurityInfo() {
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
          Icon(LucideIcons.shieldCheck, color: AppColors.royalBlue, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Transfers are securely processed through NaNa Wallet. You can authorize each transaction using your Transaction PIN or biometric authentication.',
              style: TextStyle(
                color: AppColors.themeText.withValues(alpha: 0.60),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TRANSFER BUTTON
  // ============================================================

  Widget _buildTransferButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: _canSubmit
            ? LinearGradient(
                colors: [AppColors.royalBlue, AppColors.neonPink],
              )
            : null,
        color: _canSubmit ? null : AppColors.themeText.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ElevatedButton(
        onPressed: _canSubmit ? _submitP2pTransfer : null,
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
            Icon(LucideIcons.send, size: 19),
            SizedBox(width: 10),
            Text(
              'REVIEW & SEND $_selectedCurrency',
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
}
