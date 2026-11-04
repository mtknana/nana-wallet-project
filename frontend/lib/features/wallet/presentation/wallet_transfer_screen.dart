import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';

class WalletTransferScreen extends StatefulWidget {
  final String token;

  WalletTransferScreen({super.key, required this.token});

  @override
  State<WalletTransferScreen> createState() => _WalletTransferScreenState();
}

class _WalletTransferScreenState extends State<WalletTransferScreen> {
  // ============================================================
  // CONSTANTS
  // ============================================================

  static const double exchangeRate = 4050;

  // ============================================================
  // CURRENCY
  // ============================================================

  String _fromCurrency = 'USD';
  String _toCurrency = 'KHR';

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _amountController = TextEditingController();

  // ============================================================
  // BALANCES
  // ============================================================

  double _usdBalance = 0;
  double _khrBalance = 0;

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = true;
  bool _isProcessing = false;

  // ============================================================
  // COLORS
  // ============================================================

  Color get _primaryColor => AppColors.royalBlue;

  Color get _accentColor => AppColors.neonPink;

  static Color get _background => AppColors.adaptiveSurfaceAlt;

  static Color get _card => AppColors.adaptiveSurface;

  static const Color _darkCard = Color(0xFF121E24);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD WALLETS
  // ============================================================

  Future<void> _loadWallets() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await WalletService.fetchWallets(token: widget.token);

      if (!mounted) return;

      if (result['status']?.toString().toLowerCase() == 'success') {
        final wallets = result['wallets'];

        if (wallets is List) {
          double usd = 0;
          double khr = 0;

          for (final wallet in wallets) {
            if (wallet is Map) {
              final currency = wallet['currency']?.toString().toUpperCase();

              final balance =
                  double.tryParse(wallet['balance']?.toString() ?? '0') ?? 0;

              if (currency == 'USD') {
                usd = balance;
              } else if (currency == 'KHR') {
                khr = balance;
              }
            }
          }

          setState(() {
            _usdBalance = usd;
            _khrBalance = khr;
          });

          debugPrint('💰 USD Balance: $_usdBalance');

          debugPrint('💰 KHR Balance: $_khrBalance');
        }
      } else {
        _showError(result['message']?.toString() ?? 'Unable to load wallets.');
      }
    } catch (e) {
      if (!mounted) return;

      debugPrint('❌ Load Wallets Error: $e');

      _showError('Unable to load wallet balances.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // CURRENCY SWITCH
  // ============================================================

  void _switchWallets() {
    if (_isProcessing) return;

    setState(() {
      final oldFrom = _fromCurrency;

      _fromCurrency = _toCurrency;
      _toCurrency = oldFrom;

      _amountController.clear();
    });
  }

  // ============================================================
  // BALANCE
  // ============================================================

  double get _sourceBalance {
    return _fromCurrency == 'USD' ? _usdBalance : _khrBalance;
  }

  double get _destinationBalance {
    return _toCurrency == 'USD' ? _usdBalance : _khrBalance;
  }

  // ============================================================
  // AMOUNT
  // ============================================================

  double get _amount {
    return double.tryParse(_amountController.text.trim()) ?? 0;
  }

  // ============================================================
  // CONVERSION
  // ============================================================

  double get _convertedAmount {
    if (_amount <= 0) {
      return 0;
    }

    if (_fromCurrency == 'USD' && _toCurrency == 'KHR') {
      return _amount * exchangeRate;
    }

    if (_fromCurrency == 'KHR' && _toCurrency == 'USD') {
      return _amount / exchangeRate;
    }

    return 0;
  }

  // ============================================================
  // FORMATTING
  // ============================================================

  String _formatAmount(double value) {
    if (_toCurrency == 'KHR') {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }

  String _currencySymbol(String currency) {
    return currency == 'USD' ? '\$' : '៛';
  }

  // ============================================================
  // TRANSFER
  // ============================================================

  Future<void> _handleTransfer() async {
    if (_isProcessing) return;

    FocusScope.of(context).unfocus();

    if (_amount <= 0) {
      _showError('Please enter a valid amount.');
      return;
    }

    if (_amount > _sourceBalance) {
      _showError('Insufficient $_fromCurrency wallet balance.');
      return;
    }

    await _showConfirmation();
  }

  // ============================================================
  // CONFIRMATION
  // ============================================================

  Future<void> _showConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Confirm Wallet Transfer',
            style: TextStyle(color: AppColors.themeText, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _confirmationRow(
                'From',
                '${_currencySymbol(_fromCurrency)} '
                    '${_amount.toStringAsFixed(_fromCurrency == 'USD' ? 2 : 0)} '
                    '$_fromCurrency',
              ),

              SizedBox(height: 12),

              _confirmationRow(
                'To',
                '${_currencySymbol(_toCurrency)} '
                    '${_formatAmount(_convertedAmount)} '
                    '$_toCurrency',
              ),

              SizedBox(height: 12),

              _confirmationRow('Rate', '1 USD = 4,050 KHR'),

              SizedBox(height: 12),

              _confirmationRow('Fee', 'FREE'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(
                'CANCEL',
                style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.54)),
              ),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: AppColors.themeText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'CONFIRM',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (confirmed == true) {
      await _verifyPin();
    }
  }

  // ============================================================
  // CONFIRMATION ROW
  // ============================================================

  Widget _confirmationRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.54))),

        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.themeText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PIN VERIFICATION
  //
  // IMPORTANT:
  // We now use the existing NaNa transaction PIN
  // verification screen instead of creating another
  // PIN dialog here.
  // ============================================================

  Future<void> _verifyPin() async {
    if (!mounted) return;

    debugPrint('🔐 Opening transaction PIN verification...');

    final result = await Navigator.pushNamed(
      context,
      '/transaction-pin-verify',
      arguments: widget.token,
    );

    if (!mounted) return;

    if (result == true) {
      debugPrint('✅ Wallet Transfer Transaction PIN verified.');

      await _executeTransfer();
    } else {
      debugPrint(
        '❌ Wallet Transfer Transaction PIN verification failed/cancelled.',
      );
    }
  }

  // ============================================================
  // EXECUTE TRANSFER
  // ============================================================

  Future<void> _executeTransfer() async {
    if (_isProcessing) return;

    if (_amount <= 0) {
      _showError('Please enter a valid amount.');
      return;
    }

    if (_amount > _sourceBalance) {
      _showError('Insufficient $_fromCurrency wallet balance.');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final idempotencyKey = 'WALLET-${DateTime.now().millisecondsSinceEpoch}';

      debugPrint('================================================');

      debugPrint('➡️ Starting Wallet Currency Transfer');

      debugPrint('From Currency: $_fromCurrency');

      debugPrint('To Currency: $_toCurrency');

      debugPrint('Amount: $_amount');

      debugPrint('Expected Converted Amount: $_convertedAmount');

      debugPrint('Idempotency Key: $idempotencyKey');

      debugPrint('================================================');

      final result = await WalletService.executeWalletTransfer(
        token: widget.token,
        fromCurrency: _fromCurrency,
        toCurrency: _toCurrency,
        amount: _amount,
        idempotencyKey: idempotencyKey,
      );

      if (!mounted) return;

      debugPrint('⬅️ Wallet Transfer Result: $result');

      final status = result['status']?.toString().toLowerCase();

      if (status == 'success') {
        // Update dashboard notification badge.
        addTransactionNotification();

        await _showSuccess(result);
      } else {
        _showError(result['message']?.toString() ?? 'Wallet transfer failed.');
      }
    } catch (e) {
      if (!mounted) return;

      debugPrint('❌ Wallet Transfer Error: $e');

      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // ============================================================
  // SUCCESS
  // ============================================================

  Future<void> _showSuccess(Map<String, dynamic> result) async {
    // Backend returns:
    //
    // "converted_amount"
    //
    // Not "amount_received".

    final received =
        double.tryParse(
          result['converted_amount']?.toString() ??
              result['amount_received']?.toString() ??
              '0',
        ) ??
        0;

    // Backend returns:
    //
    // "reference"
    //
    // Keep reference_id as fallback.

    final reference =
        result['reference_id']?.toString() ??
        result['reference']?.toString() ??
        '-';

    debugPrint('✅ Transfer Successful');

    debugPrint('Received: $received $_toCurrency');

    debugPrint('Reference: $reference');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _card,
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
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withOpacity(0.15),
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.greenAccent,
                  size: 40,
                ),
              ),

              SizedBox(height: 20),

              // --------------------------------------------------
              // TITLE
              // --------------------------------------------------
              Text(
                'Transfer Successful',
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 10),

              // --------------------------------------------------
              // RECEIVED AMOUNT
              // --------------------------------------------------
              Text(
                '${_currencySymbol(_toCurrency)} '
                '${_formatAmount(received)} '
                '$_toCurrency',
                style: TextStyle(
                  color: _accentColor,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 8),

              Text(
                'has been added to your wallet.',
                style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.54)),
              ),

              SizedBox(height: 20),

              // --------------------------------------------------
              // REFERENCE
              // --------------------------------------------------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.themeText.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    Text(
                      'REFERENCE',
                      style: TextStyle(
                        color: AppColors.themeText.withValues(alpha: 0.38),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),

                    SizedBox(height: 5),

                    Text(
                      reference,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.themeText.withValues(alpha: 0.70),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // --------------------------------------------------
              // DONE
              // --------------------------------------------------
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: AppColors.themeText,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'DONE',
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

    if (!mounted) return;

    // Return to Wallet Dashboard.
    Navigator.pop(context, true);
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _card,
        duration: Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(LucideIcons.circleAlert, color: _accentColor, size: 20),

            SizedBox(width: 12),

            Expanded(
              child: Text(
                message,
                style: TextStyle(color: AppColors.themeText, fontSize: 13),
              ),
            ),
          ],
        ),
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

      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Wallet Transfer',
          style: TextStyle(color: AppColors.themeText, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: AppColors.themeText),
      ),

      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : Stack(
              children: [
                SafeArea(
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),

                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        _buildHeader(),

                        SizedBox(height: 25),

                        _buildWalletCard(
                          title: 'FROM',
                          currency: _fromCurrency,
                          balance: _sourceBalance,
                          isSource: true,
                        ),

                        SizedBox(height: 10),

                        // ------------------------------------------------
                        // SWITCH BUTTON
                        // ------------------------------------------------
                        Center(
                          child: GestureDetector(
                            onTap: _switchWallets,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.adaptiveSurface,
                                border: Border.all(
                                  color: _primaryColor.withOpacity(0.5),
                                ),
                              ),
                              child: Icon(
                                LucideIcons.arrowUpDown,
                                color: _primaryColor,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 10),

                        _buildWalletCard(
                          title: 'TO',
                          currency: _toCurrency,
                          balance: _destinationBalance,
                          isSource: false,
                        ),

                        SizedBox(height: 28),

                        Text(
                          'TRANSFER AMOUNT',
                          style: TextStyle(
                            color: AppColors.themeText.withValues(alpha: 0.54),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),

                        SizedBox(height: 10),

                        _buildAmountField(),

                        SizedBox(height: 20),

                        _buildConversionCard(),

                        SizedBox(height: 28),

                        // ------------------------------------------------
                        // TRANSFER BUTTON
                        // ------------------------------------------------
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isProcessing ? null : _handleTransfer,

                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentColor,
                              disabledBackgroundColor: AppColors.themeText.withValues(alpha: 0.12),
                              foregroundColor: AppColors.themeText,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),

                            child: _isProcessing
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.themeText,
                                    ),
                                  )
                                : Text(
                                    'TRANSFER NOW',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ----------------------------------------------------------
                // PROCESSING OVERLAY
                // ----------------------------------------------------------
                if (_isProcessing) Container(color: Colors.black26),
              ],
            ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),

        gradient: LinearGradient(
          colors: [AppColors.adaptiveSurface, AppColors.adaptiveSurface],
        ),

        border: Border.all(color: AppColors.themeText.withOpacity(0.06)),
      ),

      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),

              color: _primaryColor.withOpacity(0.15),
            ),

            child: Icon(
              LucideIcons.arrowLeftRight,
              color: _primaryColor,
              size: 28,
            ),
          ),

          SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'Move Money Easily',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  'Transfer between your USD and KHR wallets.',
                  style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.54), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WALLET CARD
  // ============================================================

  Widget _buildWalletCard({
    required String title,
    required String currency,
    required double balance,
    required bool isSource,
  }) {
    final isUsd = currency == 'USD';

    final currencyColor = isUsd ? _primaryColor : _accentColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),

        color: _card,

        border: Border.all(
          color: isSource
              ? _primaryColor.withOpacity(0.35)
              : _accentColor.withOpacity(0.25),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              color: currencyColor.withOpacity(0.15),
            ),

            child: Center(
              child: Text(
                isUsd ? '\$' : '៛',

                style: TextStyle(
                  color: currencyColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.38),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  '$currency Wallet',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  'Balance: '
                  '${isUsd ? '\$' : '៛'} '
                  '${isUsd ? balance.toStringAsFixed(2) : balance.toStringAsFixed(0)}',

                  style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.54), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AMOUNT FIELD
  // ============================================================

  Widget _buildAmountField() {
    final symbol = _currencySymbol(_fromCurrency);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),

        color: _card,

        border: Border.all(color: AppColors.themeText.withOpacity(0.07)),
      ),

      child: TextField(
        controller: _amountController,

        enabled: !_isProcessing,

        keyboardType: const TextInputType.numberWithOptions(decimal: true),

        style: TextStyle(
          color: AppColors.themeText,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),

        onChanged: (_) {
          if (mounted) {
            setState(() {});
          }
        },

        decoration: InputDecoration(
          prefixText: '$symbol ',

          prefixStyle: TextStyle(
            color: _fromCurrency == 'USD' ? _primaryColor : _accentColor,

            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),

          hintText: _fromCurrency == 'USD' ? '0.00' : '0',

          hintStyle: TextStyle(color: AppColors.themeText.withValues(alpha: 0.24)),

          border: InputBorder.none,

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONVERSION CARD
  // ============================================================

  Widget _buildConversionCard() {
    final received = _convertedAmount;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),

        color: _darkCard,

        border: Border.all(color: _primaryColor.withOpacity(0.18)),
      ),

      child: Column(
        children: [
          // ------------------------------------------------------
          // RATE
          // ------------------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              Text(
                'Exchange Rate',
                style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.54)),
              ),

              Text(
                '1 USD = 4,050 KHR',
                style: TextStyle(
                  color: AppColors.themeText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          Padding(
            padding: EdgeInsets.symmetric(vertical: 15),

            child: Divider(color: AppColors.themeText.withValues(alpha: 0.10)),
          ),

          // ------------------------------------------------------
          // RECEIVED
          // ------------------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            crossAxisAlignment: CrossAxisAlignment.end,

            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    'YOU RECEIVE',
                    style: TextStyle(
                      color: AppColors.themeText.withValues(alpha: 0.38),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),

                  SizedBox(height: 5),
                ],
              ),

              Flexible(
                child: Text(
                  '${_currencySymbol(_toCurrency)} '
                  '${_formatAmount(received)}',

                  textAlign: TextAlign.right,

                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 5),

          Align(
            alignment: Alignment.centerRight,

            child: Text(
              _toCurrency,

              style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.38), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
