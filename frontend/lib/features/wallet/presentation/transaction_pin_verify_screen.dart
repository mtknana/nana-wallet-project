import 'package:flutter/material.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
class TransactionPinVerifyScreen extends StatefulWidget {
  final String token;

  TransactionPinVerifyScreen({super.key, required this.token});

  @override
  State<TransactionPinVerifyScreen> createState() =>
      _TransactionPinVerifyScreenState();
}

class _TransactionPinVerifyScreenState
    extends State<TransactionPinVerifyScreen> {
  final TextEditingController _pinController = TextEditingController();

  bool _loading = false;
  bool _obscurePin = true;

  Future<void> _verifyPin() async {
    final pin = _pinController.text.trim();

    if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      _showError('Please enter your 4-digit PIN.');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final response = await WalletService.verifyTransactionPin(
        token: widget.token,
        transactionPin: pin,
      );

      if (!mounted) return;

      final success = response['status']?.toString().toLowerCase() == 'success';

      if (success) {
        // Return true to the transaction screen.
        Navigator.pop(context, true);
      } else {
        _showError(
          response['message']?.toString() ?? 'Incorrect transaction PIN.',
        );

        _pinController.clear();
      }
    } catch (e) {
      if (!mounted) return;

      _showError('Unable to verify PIN. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _pinBox(int index) {
    final hasValue = _pinController.text.length > index;

    return AnimatedContainer(
      duration: Duration(milliseconds: 180),
      width: 58,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.adaptiveSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasValue
              ? Color(0xFF4DA3FF)
              : AppColors.themeText.withOpacity(0.08),
          width: hasValue ? 1.5 : 1,
        ),
      ),
      child: Center(
        child: hasValue
            ? Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.themeText,
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  void _addDigit(String digit) {
    if (_pinController.text.length >= 4) {
      return;
    }

    setState(() {
      _pinController.text += digit;
    });
  }

  void _removeDigit() {
    if (_pinController.text.isEmpty) {
      return;
    }

    setState(() {
      _pinController.text = _pinController.text.substring(
        0,
        _pinController.text.length - 1,
      );
    });
  }

  Widget _key(String value) {
    return SizedBox(
      width: 75,
      height: 62,
      child: Material(
        color: AppColors.adaptiveSurface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _loading
              ? null
              : () {
                  _addDigit(value);
                },
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.themeText,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _keypadRow(String first, String second, String third) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [_key(first), _key(second), _key(third)],
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOnTheme(context);
    return Scaffold(
      backgroundColor: AppColors.adaptiveSurfaceAlt,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.themeText),
        title: Text(
          'Security Verification',
          style: TextStyle(color: AppColors.themeText, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    SizedBox(height: 25),

                    // Lock icon
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFFEC4899)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF2563EB).withOpacity(0.3),
                            blurRadius: 25,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.verified_user_rounded,
                        color: AppColors.themeText,
                        size: 38,
                      ),
                    ),

                    SizedBox(height: 25),

                    Text(
                      'Enter Transaction PIN',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.themeText,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 10),

                    Text(
                      'Enter your 4-digit PIN to authorize this transaction.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.themeText.withValues(alpha: 0.60),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),

                    SizedBox(height: 30),

                    // PIN indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < 4; i++) ...[
                          _pinBox(i),
                          if (i != 3) SizedBox(width: 12),
                        ],
                      ],
                    ),

                    SizedBox(height: 35),

                    // Hidden TextField
                    SizedBox(
                      height: 0,
                      child: TextField(
                        controller: _pinController,
                        obscureText: _obscurePin,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        onChanged: (_) {
                          setState(() {});
                        },
                      ),
                    ),

                    _keypadRow('1', '2', '3'),

                    SizedBox(height: 12),

                    _keypadRow('4', '5', '6'),

                    SizedBox(height: 12),

                    _keypadRow('7', '8', '9'),

                    SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        SizedBox(width: 75, height: 62),
                        _key('0'),
                        SizedBox(
                          width: 75,
                          height: 62,
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: _loading ? null : _removeDigit,
                              child: Center(
                                child: Icon(
                                  Icons.backspace_outlined,
                                  color: AppColors.themeText.withValues(alpha: 0.70),
                                  size: 25,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFFEC4899)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ElevatedButton(
                          onPressed: _loading || _pinController.text.length != 4
                              ? null
                              : _verifyPin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: _loading
                              ? SizedBox(
                                  width: 23,
                                  height: 23,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.themeText,
                                  ),
                                )
                              : Text(
                                  'Verify & Continue',
                                  style: TextStyle(
                                    color: AppColors.themeText,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    SizedBox(height: 18),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children:  [
                        Icon(
                          Icons.lock_outline,
                          size: 15,
                          color: AppColors.themeText.withValues(alpha: 0.38),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Your PIN is securely verified',
                          style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.38), fontSize: 12),
                        ),
                      ],
                    ),

                    SizedBox(height: 25),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }
}
