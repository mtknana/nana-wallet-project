import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';
import 'package:digital_wallet_app/core/constants/app_colors.dart';

class ReceiveMoneyScreen extends StatefulWidget {
  final String token;

  ReceiveMoneyScreen({super.key, required this.token});

  @override
  State<ReceiveMoneyScreen> createState() => _ReceiveMoneyScreenState();
}

class _ReceiveMoneyScreenState extends State<ReceiveMoneyScreen> {
  final TextEditingController _amountController = TextEditingController();

  static const double _exchangeRate = 4050.00;

  bool _isLoading = true;
  bool _isGeneratingRequest = false;
  bool _isTransferring = false;

  String _userName = 'NaNa User';
  String _userId = '';
  String _email = '';

  String _personalQrData = '';

  String _selectedMethod = 'qr';

  // Request Money
  String _requestCurrency = 'USD';

  // Wallet Transfer
  String _fromCurrency = 'USD';
  String _toCurrency = 'KHR';

  double _usdBalance = 0.00;
  double _khrBalance = 0.00;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  // ============================================================
  // DATA
  // ============================================================

  Future<void> _refreshAll() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    await Future.wait([_loadProfile(), _loadWalletBalances()]);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadProfile() async {
    try {
      final result = await WalletService.fetchProfile(token: widget.token);

      if (result['status'] != 'success') {
        return;
      }

      Map<String, dynamic>? user;

      if (result['user'] is Map) {
        user = Map<String, dynamic>.from(result['user']);
      } else if (result['data'] is Map) {
        final data = Map<String, dynamic>.from(result['data']);

        if (data['user'] is Map) {
          user = Map<String, dynamic>.from(data['user']);
        } else {
          user = data;
        }
      }

      if (user == null) {
        return;
      }

      final id = user['id']?.toString() ?? '';
      final name = user['name']?.toString() ?? 'NaNa User';
      final email = user['email']?.toString() ?? '';

      final qrPayload =
          'nana://pay'
          '?user_id=$id'
          '&name=${Uri.encodeComponent(name)}';

      if (!mounted) return;

      setState(() {
        _userId = id;
        _userName = name;
        _email = email;
        _personalQrData = qrPayload;
      });
    } catch (e) {
      debugPrint('❌ Failed to load profile: $e');
    }
  }

  Future<void> _loadWalletBalances() async {
    try {
      final wallets = await WalletService.fetchWalletBalances(widget.token);

      double usd = 0.00;
      double khr = 0.00;

      for (final wallet in wallets) {
        final currency = wallet.currency.toUpperCase();

        if (currency == 'USD') {
          usd = wallet.balance;
        } else if (currency == 'KHR') {
          khr = wallet.balance;
        }
      }

      if (!mounted) return;

      setState(() {
        _usdBalance = usd;
        _khrBalance = khr;
      });
    } catch (e) {
      debugPrint('❌ Failed to load wallet balances: $e');
    }
  }

  // ============================================================
  // CURRENCY HELPERS
  // ============================================================

  double _balanceForCurrency(String currency) {
    if (currency.toUpperCase() == 'KHR') {
      return _khrBalance;
    }

    return _usdBalance;
  }

  String _symbol(String currency) {
    return currency.toUpperCase() == 'KHR' ? '៛' : '\$';
  }

  String _currencyName(String currency) {
    return currency.toUpperCase() == 'KHR' ? 'Cambodian Riel' : 'US Dollar';
  }

  String _formatMoney(double amount, String currency, {bool decimals = true}) {
    final formatted = decimals
        ? amount.toStringAsFixed(2)
        : amount.toStringAsFixed(0);

    final parts = formatted.split('.');

    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '';

    final withCommas = integerPart.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );

    if (decimals) {
      return '${_symbol(currency)}'
          '$withCommas.$decimalPart';
    }

    return '${_symbol(currency)}$withCommas';
  }

  double _calculateConvertedAmount(double amount) {
    if (_fromCurrency == _toCurrency) {
      return amount;
    }

    if (_fromCurrency == 'USD' && _toCurrency == 'KHR') {
      return amount * _exchangeRate;
    }

    if (_fromCurrency == 'KHR' && _toCurrency == 'USD') {
      return amount / _exchangeRate;
    }

    return 0.00;
  }

  double get _enteredAmount {
    return double.tryParse(_amountController.text.replaceAll(',', '').trim()) ??
        0.00;
  }

  double get _convertedAmount {
    return _calculateConvertedAmount(_enteredAmount);
  }

  // ============================================================
  // METHOD SELECTION
  // ============================================================

  void _selectMethod(String method) {
    setState(() {
      _selectedMethod = method;

      if (method != 'request') {
        _amountController.clear();
      }
    });
  }

  void _selectRequestCurrency(String currency) {
    setState(() {
      _requestCurrency = currency;
      _amountController.clear();
    });
  }

  // ============================================================
  // WALLET TRANSFER CURRENCY SELECTION
  // ============================================================

  void _selectFromCurrency(String currency) {
    if (currency == _toCurrency) {
      _showError(
        'Your source and destination wallets must use different currencies.',
      );
      return;
    }

    setState(() {
      _fromCurrency = currency;
    });
  }

  void _selectToCurrency(String currency) {
    if (currency == _fromCurrency) {
      _showError(
        'Your source and destination wallets must use different currencies.',
      );
      return;
    }

    setState(() {
      _toCurrency = currency;
    });
  }

  void _swapTransferCurrencies() {
    setState(() {
      final oldFrom = _fromCurrency;

      _fromCurrency = _toCurrency;
      _toCurrency = oldFrom;
    });
  }

  // ============================================================
  // REQUEST MONEY
  // ============================================================

  Future<void> _generateRequestQr() async {
    final amount = _enteredAmount;

    if (amount <= 0) {
      _showError('Please enter a valid amount to request.');
      return;
    }

    setState(() {
      _isGeneratingRequest = true;
    });

    await Future.delayed(Duration(milliseconds: 350));

    final requestQr =
        'nana://request'
        '?user_id=$_userId'
        '&name=${Uri.encodeComponent(_userName)}'
        '&currency=$_requestCurrency'
        '&amount=${amount.toStringAsFixed(2)}';

    if (!mounted) return;

    setState(() {
      _isGeneratingRequest = false;
    });

    _showRequestQrDialog(requestQr, amount);
  }

  void _showRequestQrDialog(String qrData, double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.adaptiveSurface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.themeText.withOpacity(0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _iconContainer(
                      Icons.qr_code_2_rounded,
                      AppColors.royalBlue,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'REQUEST MONEY',
                        style: TextStyle(
                          color: AppColors.themeText,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.themeText.withValues(alpha: 0.70),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 22),

                Text(
                  'Requesting',
                  style: TextStyle(
                    color: AppColors.themeText.withOpacity(0.55),
                    fontSize: 13,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  _formatMoney(amount, _requestCurrency),
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.themeText,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: AppColors.themeText,
                  ),
                ),

                SizedBox(height: 18),

                Text(
                  'Ask the sender to scan this QR code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.themeText.withOpacity(0.65),
                    fontSize: 13,
                  ),
                ),

                SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: qrData));

                      if (!mounted) return;

                      _showInfo('Request QR data copied.');
                    },
                    icon: Icon(Icons.copy_rounded, size: 18),
                    label: Text('COPY QR DATA'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.themeText,
                      side: BorderSide(color: AppColors.themeText.withOpacity(0.12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
  // OWN WALLET TRANSFER
  // ============================================================

  Future<void> _showOwnAccountTransfer() async {
    final amount = _enteredAmount;

    if (amount <= 0) {
      _showError('Please enter a valid amount.');
      return;
    }

    final availableBalance = _balanceForCurrency(_fromCurrency);

    if (amount > availableBalance) {
      _showError('Insufficient $_fromCurrency wallet balance.');
      return;
    }

    final convertedAmount = _calculateConvertedAmount(amount);

    if (convertedAmount <= 0) {
      _showError('Unable to calculate the conversion.');
      return;
    }

    await _showTransferConfirmation(
      amount: amount,
      convertedAmount: convertedAmount,
    );
  }

  Future<void> _showTransferConfirmation({
    required double amount,
    required double convertedAmount,
  }) async {
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 22,
              ),
              decoration: BoxDecoration(
                color: AppColors.adaptiveSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.themeText.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),

                    SizedBox(height: 24),

                    _iconContainer(
                      Icons.swap_horiz_rounded,
                      AppColors.royalBlue,
                      size: 58,
                    ),

                    SizedBox(height: 14),

                    Text(
                      'CONFIRM WALLET TRANSFER',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.themeText,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),

                    SizedBox(height: 7),

                    Text(
                      'Move money between your NaNa wallets',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.themeText.withOpacity(0.55),
                        fontSize: 13,
                      ),
                    ),

                    SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.royalBlue.withOpacity(0.14),
                            AppColors.neonPink.withOpacity(0.10),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.themeText.withOpacity(0.07),
                        ),
                      ),
                      child: Column(
                        children: [
                          _transferSummaryRow(
                            'From',
                            _formatMoney(amount, _fromCurrency),
                            _fromCurrency,
                          ),

                          SizedBox(height: 14),

                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.themeText.withOpacity(0.07),
                              ),
                              child: Icon(
                                Icons.arrow_downward_rounded,
                                color: AppColors.themeText.withValues(alpha: 0.70),
                                size: 18,
                              ),
                            ),
                          ),

                          SizedBox(height: 14),

                          _transferSummaryRow(
                            'To',
                            _formatMoney(convertedAmount, _toCurrency),
                            _toCurrency,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.currency_exchange_rounded,
                            color: AppColors.themeText.withValues(alpha: 0.54),
                            size: 18,
                          ),
                          SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              '1 USD = 4,050 KHR',
                              style: TextStyle(
                                color: AppColors.themeText.withOpacity(0.65),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            'No fee',
                            style: TextStyle(
                              color: Colors.greenAccent.withOpacity(0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: submitting
                                ? null
                                : () {
                                    Navigator.pop(sheetContext);
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.themeText,
                              side: BorderSide(
                                color: AppColors.themeText.withOpacity(0.12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: Text(
                              'CANCEL',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(width: 12),

                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: submitting
                                ? null
                                : () async {
                                    setSheetState(() {
                                      submitting = true;
                                    });

                                    final result = await _performWalletTransfer(
                                      amount: amount,
                                    );

                                    if (!mounted) {
                                      return;
                                    }

                                    if (result == null ||
                                        result['status'] != 'success') {
                                      setSheetState(() {
                                        submitting = false;
                                      });
                                      return;
                                    }

                                    Navigator.pop(sheetContext);

                                    final received =
                                        double.tryParse(
                                          result['amount_received']
                                                  ?.toString() ??
                                              '',
                                        ) ??
                                        convertedAmount;

                                    final reference =
                                        result['reference_id']?.toString() ??
                                        '';

                                    _amountController.clear();

                                    await _loadWalletBalances();

                                    if (!mounted) {
                                      return;
                                    }

                                    _showTransferSuccessDialog(
                                      amount: amount,
                                      convertedAmount: received,
                                      referenceId: reference,
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.royalBlue,
                              foregroundColor: AppColors.themeText,
                              disabledBackgroundColor: AppColors.royalBlue
                                  .withOpacity(0.35),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: submitting
                                ? SizedBox(
                                    width: 21,
                                    height: 21,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.3,
                                      color: AppColors.themeText,
                                    ),
                                  )
                                : Text(
                                    'CONFIRM TRANSFER',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _performWalletTransfer({
    required double amount,
  }) async {
    if (_isTransferring) {
      return null;
    }

    setState(() {
      _isTransferring = true;
    });

    final idempotencyKey =
        'WLT-${DateTime.now().millisecondsSinceEpoch}-'
        '${DateTime.now().microsecond}';

    try {
      debugPrint(
        '💱 Wallet transfer: '
        '$_fromCurrency → $_toCurrency',
      );

      final result = await WalletService.executeWalletTransfer(
        token: widget.token,
        fromCurrency: _fromCurrency,
        toCurrency: _toCurrency,
        amount: amount,
        idempotencyKey: idempotencyKey,
      );

      if (!mounted) {
        return result;
      }

      if (result['status'] != 'success') {
        _showError(result['message']?.toString() ?? 'Wallet transfer failed.');

        return result;
      }

      return result;
    } catch (e) {
      debugPrint('❌ Wallet transfer error: $e');

      if (mounted) {
        _showError('Transfer failed. Please try again.');
      }

      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isTransferring = false;
        });
      }
    }
  }

  // ============================================================
  // SUCCESS DIALOG
  // ============================================================

  void _showTransferSuccessDialog({
    required double amount,
    required double convertedAmount,
    required String referenceId,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.adaptiveSurface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.themeText.withOpacity(0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.greenAccent.withOpacity(0.25),
                        AppColors.royalBlue.withOpacity(0.25),
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.greenAccent,
                    size: 38,
                  ),
                ),

                SizedBox(height: 18),

                Text(
                  'TRANSFER SUCCESSFUL',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),

                SizedBox(height: 8),

                Text(
                  'Your money has been transferred successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.themeText.withOpacity(0.55),
                    fontSize: 13,
                  ),
                ),

                SizedBox(height: 22),

                Container(
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      _successAmountRow(
                        'Sent',
                        _formatMoney(amount, _fromCurrency),
                      ),
                      SizedBox(height: 12),
                      _successAmountRow(
                        'Received',
                        _formatMoney(convertedAmount, _toCurrency),
                      ),
                      SizedBox(height: 12),
                      _successAmountRow(
                        'Rate',
                        _fromCurrency == 'USD'
                            ? '1 USD = 4,050 KHR'
                            : '1 USD = 4,050 KHR',
                      ),
                    ],
                  ),
                ),

                if (referenceId.isNotEmpty) ...[
                  SizedBox(height: 15),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.themeText.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Ref: $referenceId',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.themeText.withOpacity(0.55),
                              fontSize: 11,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: referenceId),
                            );

                            if (!mounted) {
                              return;
                            }

                            _showInfo('Reference ID copied.');
                          },
                          icon: Icon(
                            Icons.copy_rounded,
                            size: 17,
                            color: AppColors.themeText.withValues(alpha: 0.54),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.royalBlue,
                      foregroundColor: AppColors.themeText,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      'DONE',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
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
  // UI
  // ============================================================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.royalBlue.withOpacity(0.18),
            AppColors.neonPink.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.themeText.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.royalBlue, AppColors.neonPink],
              ),
            ),
            child: Center(
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'N',
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),

          SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receive money securely',
                  style: TextStyle(
                    color: AppColors.themeText.withOpacity(0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          _iconContainer(Icons.shield_outlined, Colors.greenAccent, size: 43),
        ],
      ),
    );
  }

  Widget _buildMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHOOSE A METHOD',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
          ),
        ),

        SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _methodCard(
                id: 'own',
                icon: Icons.account_balance_wallet_outlined,
                title: 'My Account',
                subtitle: 'Move between wallets',
              ),
            ),

            SizedBox(width: 9),

            Expanded(
              child: _methodCard(
                id: 'qr',
                icon: Icons.qr_code_2_rounded,
                title: 'My QR',
                subtitle: 'Show your QR',
              ),
            ),

            SizedBox(width: 9),

            Expanded(
              child: _methodCard(
                id: 'request',
                icon: Icons.request_page_outlined,
                title: 'Request',
                subtitle: 'Request money',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _methodCard({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _selectedMethod == id;

    return GestureDetector(
      onTap: () => _selectMethod(id),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 220),
        padding: const EdgeInsets.all(13),
        constraints: BoxConstraints(minHeight: 108),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.royalBlue.withOpacity(0.28),
                    AppColors.neonPink.withOpacity(0.12),
                  ],
                )
              : null,
          color: selected ? null : AppColors.adaptiveSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.royalBlue.withOpacity(0.55)
                : AppColors.themeText.withOpacity(0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.themeText : AppColors.themeText.withValues(alpha: 0.54),
              size: 23,
            ),

            // IMPORTANT:
            // Do not use Spacer() here.
            // The card is inside a scroll view and
            // therefore has unbounded height.
            SizedBox(height: 15),

            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? AppColors.themeText : AppColors.themeText.withValues(alpha: 0.70),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),

            SizedBox(height: 3),

            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? AppColors.themeText.withOpacity(0.65)
                    : AppColors.themeText.withOpacity(0.38),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedMethod() {
    switch (_selectedMethod) {
      case 'own':
        return _buildOwnWalletTransfer();

      case 'request':
        return _buildRequestMoney();

      case 'qr':
      default:
        return _buildPersonalQr();
    }
  }

  // ============================================================
  // OWN WALLET TRANSFER UI
  // ============================================================

  Widget _buildOwnWalletTransfer() {
    final amount = _enteredAmount;

    final convertedAmount = _calculateConvertedAmount(amount);

    return Column(
      key: ValueKey('own-wallet'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'TRANSFER BETWEEN MY WALLETS',
          'Convert USD ↔ KHR instantly',
        ),

        SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: _buildWalletBalanceCard(
                currency: 'USD',
                balance: _usdBalance,
                selected: _fromCurrency == 'USD',
                label: 'FROM',
                onTap: () {
                  _selectFromCurrency('USD');
                },
              ),
            ),

            SizedBox(width: 10),

            GestureDetector(
              onTap: _swapTransferCurrencies,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.royalBlue, AppColors.neonPink],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.royalBlue.withOpacity(0.20),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.themeText,
                  size: 23,
                ),
              ),
            ),

            SizedBox(width: 10),

            Expanded(
              child: _buildWalletBalanceCard(
                currency: 'KHR',
                balance: _khrBalance,
                selected: _fromCurrency == 'KHR',
                label: 'FROM',
                onTap: () {
                  _selectFromCurrency('KHR');
                },
              ),
            ),
          ],
        ),

        SizedBox(height: 14),

        _buildDirectionCard(),

        SizedBox(height: 16),

        _buildAmountInput(
          currency: _fromCurrency,
          label: 'AMOUNT TO TRANSFER',
          hint: _fromCurrency == 'USD' ? '0.00' : '0',
          onChanged: (_) {
            setState(() {});
          },
        ),

        SizedBox(height: 15),

        _buildLiveConversionCard(
          amount: amount,
          convertedAmount: convertedAmount,
        ),

        SizedBox(height: 17),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isTransferring ? null : _showOwnAccountTransfer,
            icon: Icon(Icons.arrow_forward_rounded, size: 19),
            label: Text('TRANSFER TO $_toCurrency'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.royalBlue,
              foregroundColor: AppColors.themeText,
              disabledBackgroundColor: AppColors.royalBlue.withOpacity(0.35),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWalletBalanceCard({
    required String currency,
    required double balance,
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 220),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.royalBlue.withOpacity(0.22),
                    AppColors.neonPink.withOpacity(0.08),
                  ],
                )
              : null,
          color: selected ? null : AppColors.adaptiveSurface,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: selected
                ? AppColors.royalBlue.withOpacity(0.55)
                : AppColors.themeText.withOpacity(0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? AppColors.royalBlue : AppColors.themeText.withValues(alpha: 0.38),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                Spacer(),
                if (selected)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.royalBlue,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.royalBlue.withOpacity(0.5),
                          blurRadius: 7,
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            SizedBox(height: 9),

            Text(
              currency,
              style: TextStyle(
                color: AppColors.themeText,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),

            SizedBox(height: 4),

            Text(
              _formatMoney(balance, currency, decimals: currency == 'USD'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.themeText.withOpacity(0.62),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIRECTION
  // ============================================================

  Widget _buildDirectionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.themeText.withOpacity(0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.themeText.withOpacity(0.055)),
      ),
      child: Row(
        children: [
          _currencyMiniBadge(_fromCurrency),

          SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONVERTING',
                  style: TextStyle(
                    color: AppColors.themeText.withOpacity(0.35),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '$_fromCurrency → $_toCurrency',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          _currencyMiniBadge(_toCurrency),
        ],
      ),
    );
  }

  Widget _buildLiveConversionCard({
    required double amount,
    required double convertedAmount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.royalBlue.withOpacity(0.11),
            AppColors.neonPink.withOpacity(0.07),
          ],
        ),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.themeText.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.currency_exchange_rounded,
                color: AppColors.themeText.withValues(alpha: 0.54),
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'LIVE CONVERSION',
                style: TextStyle(
                  color: AppColors.themeText.withOpacity(0.55),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),

          SizedBox(height: 13),

          if (amount > 0)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatMoney(amount, _fromCurrency),
                    style: TextStyle(
                      color: AppColors.themeText,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),

                Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.themeText.withValues(alpha: 0.38),
                  size: 18,
                ),

                SizedBox(width: 8),

                Expanded(
                  child: Text(
                    _formatMoney(convertedAmount, _toCurrency),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppColors.themeText,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Enter an amount to see the conversion',
                style: TextStyle(
                  color: AppColors.themeText.withOpacity(0.38),
                  fontSize: 12,
                ),
              ),
            ),

          SizedBox(height: 11),

          Divider(color: AppColors.themeText.withOpacity(0.06), height: 1),

          SizedBox(height: 10),

          Row(
            children: [
              Text(
                'Exchange rate',
                style: TextStyle(
                  color: AppColors.themeText.withOpacity(0.4),
                  fontSize: 10,
                ),
              ),
              Spacer(),
              Text(
                '1 USD = 4,050 KHR',
                style: TextStyle(
                  color: AppColors.themeText.withOpacity(0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PERSONAL QR
  // ============================================================

  Widget _buildPersonalQr() {
    return Column(
      key: ValueKey('personal-qr'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('YOUR NANA QR', 'Let someone scan to send you money'),

        SizedBox(height: 14),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.adaptiveSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.themeText.withOpacity(0.06)),
          ),
          child: Column(
            children: [
              Text(
                _userName,
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),

              if (_email.isNotEmpty) ...[
                SizedBox(height: 4),
                Text(
                  _email,
                  style: TextStyle(
                    color: AppColors.themeText.withOpacity(0.42),
                    fontSize: 11,
                  ),
                ),
              ],

              SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.themeText,
                  borderRadius: BorderRadius.circular(23),
                ),
                child: _personalQrData.isEmpty
                    ? SizedBox(
                        width: 220,
                        height: 220,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.royalBlue,
                          ),
                        ),
                      )
                    : QrImageView(
                        data: _personalQrData,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: AppColors.themeText,
                      ),
              ),

              SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.themeText.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      color: AppColors.themeText.withValues(alpha: 0.38),
                      size: 17,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Account ID: $_userId',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.themeText.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _copyAccountId,
                      icon: Icon(
                        Icons.copy_rounded,
                        color: AppColors.themeText.withValues(alpha: 0.54),
                        size: 17,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // REQUEST MONEY
  // ============================================================

  Widget _buildRequestMoney() {
    final amount = _enteredAmount;

    return Column(
      key: ValueKey('request-money'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('REQUEST MONEY', 'Create a QR with a specific amount'),

        SizedBox(height: 14),

        _buildCurrencySelector(
          selectedCurrency: _requestCurrency,
          onChanged: _selectRequestCurrency,
        ),

        SizedBox(height: 14),

        _buildAmountInput(
          currency: _requestCurrency,
          label: 'REQUEST AMOUNT',
          hint: _requestCurrency == 'USD' ? '0.00' : '0',
          onChanged: (_) {
            setState(() {});
          },
        ),

        SizedBox(height: 15),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: AppColors.adaptiveSurface,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: AppColors.themeText.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              _iconContainer(Icons.qr_code_2_rounded, AppColors.neonPink),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REQUEST PREVIEW',
                      style: TextStyle(
                        color: AppColors.themeText,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      amount > 0
                          ? _formatMoney(amount, _requestCurrency)
                          : 'Enter an amount',
                      style: TextStyle(
                        color: amount > 0 ? AppColors.themeText : AppColors.themeText.withValues(alpha: 0.38),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isGeneratingRequest ? null : _generateRequestQr,
            icon: _isGeneratingRequest
                ? SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.themeText,
                    ),
                  )
                : Icon(Icons.qr_code_2_rounded, size: 20),
            label: Text(
              _isGeneratingRequest ? 'GENERATING...' : 'GENERATE REQUEST QR',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.royalBlue,
              foregroundColor: AppColors.themeText,
              disabledBackgroundColor: AppColors.royalBlue.withOpacity(0.35),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // COMMON INPUTS
  // ============================================================

  Widget _buildCurrencySelector({
    required String selectedCurrency,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: _currencyChoice(
            currency: 'USD',
            selected: selectedCurrency == 'USD',
            onTap: () => onChanged('USD'),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _currencyChoice(
            currency: 'KHR',
            selected: selectedCurrency == 'KHR',
            onTap: () => onChanged('KHR'),
          ),
        ),
      ],
    );
  }

  Widget _currencyChoice({
    required String currency,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.royalBlue.withOpacity(0.14)
              : AppColors.adaptiveSurface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected
                ? AppColors.royalBlue.withOpacity(0.5)
                : AppColors.themeText.withOpacity(0.06),
          ),
        ),
        child: Row(
          children: [
            _currencyMiniBadge(currency),
            SizedBox(width: 9),
            Text(
              currency,
              style: TextStyle(
                color: selected ? AppColors.themeText : AppColors.themeText.withValues(alpha: 0.54),
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            Spacer(),
            if (selected)
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.royalBlue,
                size: 17,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountInput({
    required String currency,
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
      decoration: BoxDecoration(
        color: AppColors.adaptiveSurface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.themeText.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.themeText.withOpacity(0.38),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
            ),
          ),

          SizedBox(height: 6),

          Row(
            children: [
              Text(
                _symbol(currency),
                style: TextStyle(
                  color: AppColors.royalBlue,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),

              SizedBox(width: 8),

              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  onChanged: onChanged,
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: AppColors.themeText.withOpacity(0.16),
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),

              Text(
                currency,
                style: TextStyle(
                  color: AppColors.themeText.withOpacity(0.35),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECURITY
  // ============================================================

  Widget _buildSecurityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.themeText.withOpacity(0.025),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.themeText.withOpacity(0.045)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            color: Colors.greenAccent,
            size: 19,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'For your security, never share your transaction PIN, password, or authentication token with anyone.',
              style: TextStyle(
                color: AppColors.themeText.withOpacity(0.42),
                fontSize: 10,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SMALL UI HELPERS
  // ============================================================

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: AppColors.themeText.withOpacity(0.4), fontSize: 11),
        ),
      ],
    );
  }

  Widget _currencyMiniBadge(String currency) {
    final isKhr = currency == 'KHR';

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isKhr
            ? AppColors.neonPink.withOpacity(0.12)
            : AppColors.royalBlue.withOpacity(0.12),
        border: Border.all(
          color: isKhr
              ? AppColors.neonPink.withOpacity(0.22)
              : AppColors.royalBlue.withOpacity(0.22),
        ),
      ),
      child: Center(
        child: Text(
          isKhr ? '៛' : '\$',
          style: TextStyle(
            color: isKhr ? AppColors.neonPink : AppColors.royalBlue,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _iconContainer(IconData icon, Color color, {double size = 43}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Icon(icon, color: color, size: size * 0.46),
    );
  }

  Widget _transferSummaryRow(String label, String value, String currency) {
    return Row(
      children: [
        _currencyMiniBadge(currency),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.themeText.withOpacity(0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _successAmountRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.themeText.withOpacity(0.42), fontSize: 11),
        ),
        Spacer(),
        Text(
          value,
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _copyAccountId() async {
    if (_userId.isEmpty) {
      _showError('Account ID is not available.');
      return;
    }

    await Clipboard.setData(ClipboardData(text: _userId));

    if (!mounted) return;

    _showInfo('Account ID copied.');
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Color(0xFF2A171B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.redAccent),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  void _showInfo(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.adaptiveSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.greenAccent,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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
      backgroundColor: AppColors.adaptiveSurfaceAlt,

      appBar: AppBar(
        backgroundColor: AppColors.adaptiveSurfaceAlt,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'RECEIVE MONEY',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _refreshAll,
            icon: Icon(Icons.refresh_rounded, color: AppColors.themeText.withValues(alpha: 0.70)),
          ),
          SizedBox(width: 6),
        ],
      ),

      // ========================================================
      // IMPORTANT RENDER FIX
      //
      // RefreshIndicator must always receive a scrollable child.
      // Previously the loading state returned Center(), while
      // the loaded state returned SingleChildScrollView().
      //
      // On Flutter Web this could produce:
      //
      // RenderStack
      // RenderRepaintBoundary
      // size: MISSING
      //
      // Now the scroll view exists in BOTH states.
      // ========================================================
      body: RefreshIndicator(
        color: AppColors.royalBlue,
        backgroundColor: AppColors.adaptiveSurface,
        onRefresh: _refreshAll,

        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),

          padding: const EdgeInsets.fromLTRB(18, 8, 18, 35),

          child: _isLoading
              ? SizedBox(
                  width: double.infinity,

                  // Give the loading state a finite height.
                  // This prevents unbounded layout issues
                  // inside SingleChildScrollView.
                  height:
                      MediaQuery.of(context).size.height -
                      kToolbarHeight -
                      MediaQuery.of(context).padding.top -
                      20,

                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.royalBlue,
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),

                    SizedBox(height: 22),

                    _buildMethodSelector(),

                    SizedBox(height: 18),

                    // Directly render the selected
                    // method instead of AnimatedSwitcher.
                    //
                    // AnimatedSwitcher internally uses
                    // a Stack. Removing it makes this screen
                    // more stable inside the scroll view.
                    _buildSelectedMethod(),

                    SizedBox(height: 20),

                    _buildSecurityCard(),
                  ],
                ),
        ),
      ),
    );
  }
}
