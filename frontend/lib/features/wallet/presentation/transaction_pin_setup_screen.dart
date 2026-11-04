import 'package:flutter/material.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
class TransactionPinSetupScreen extends StatefulWidget {
  final String token;

  TransactionPinSetupScreen({super.key, required this.token});

  @override
  State<TransactionPinSetupScreen> createState() =>
      _TransactionPinSetupScreenState();
}

class _TransactionPinSetupScreenState extends State<TransactionPinSetupScreen> {
  final TextEditingController _pinController = TextEditingController();

  final TextEditingController _confirmPinController = TextEditingController();

  bool _loading = false;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;

  Future<void> _setupPin() async {
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      _showMessage('Please enter a valid 4-digit PIN.', isError: true);
      return;
    }

    if (pin != confirmPin) {
      _showMessage('PIN confirmation does not match.', isError: true);
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final response = await WalletService.setTransactionPin(
        token: widget.token,
        transactionPin: pin,
      );

      if (!mounted) return;

      final success = response['status']?.toString().toLowerCase() == 'success';

      if (success) {
        await _showSuccessDialog();
      } else {
        _showMessage(
          response['message']?.toString() ?? 'Failed to set transaction PIN.',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.adaptiveSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.greenAccent, size: 30),
              SizedBox(width: 10),
              Text(
                'PIN Created',
                style: TextStyle(
                  color: AppColors.themeText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Your 4-digit transaction PIN has been created successfully.',
            style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.70), height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Continue',
                style: TextStyle(
                  color: Color(0xFF4DA3FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _pinField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: TextInputType.number,
      maxLength: 4,
      style: TextStyle(
        color: AppColors.themeText,
        fontSize: 22,
        letterSpacing: 8,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        labelStyle: TextStyle(color: AppColors.themeText.withValues(alpha: 0.60)),
        prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF4DA3FF)),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.themeText.withValues(alpha: 0.54),
          ),
        ),
        filled: true,
        fillColor: AppColors.adaptiveSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Color(0xFF4DA3FF), width: 1.5),
        ),
      ),
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
        title: Text(
          'Transaction PIN',
          style: TextStyle(color: AppColors.themeText, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: AppColors.themeText),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),

              // Header icon
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFFEC4899)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF2563EB).withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    color: AppColors.themeText,
                    size: 42,
                  ),
                ),
              ),

              SizedBox(height: 28),

              Center(
                child: Text(
                  'Create Transaction PIN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              SizedBox(height: 10),

              Center(
                child: Text(
                  'Set a 4-digit PIN to protect your wallet transactions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.60),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),

              SizedBox(height: 38),

              // Security card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.adaptiveSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.themeText.withOpacity(0.06)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.security_rounded,
                      color: Colors.greenAccent,
                      size: 28,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Your PIN is securely protected and is required for sensitive wallet transactions.',
                        style: TextStyle(
                          color: AppColors.themeText.withValues(alpha: 0.70),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 28),

              _pinField(
                controller: _pinController,
                label: 'Create 4-digit PIN',
                obscureText: _obscurePin,
                onToggle: () {
                  setState(() {
                    _obscurePin = !_obscurePin;
                  });
                },
              ),

              SizedBox(height: 18),

              _pinField(
                controller: _confirmPinController,
                label: 'Confirm PIN',
                obscureText: _obscureConfirmPin,
                onToggle: () {
                  setState(() {
                    _obscureConfirmPin = !_obscureConfirmPin;
                  });
                },
              ),

              SizedBox(height: 30),

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
                    onPressed: _loading ? null : _setupPin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _loading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.themeText,
                            ),
                          )
                        : Text(
                            'Create Transaction PIN',
                            style: TextStyle(
                              color: AppColors.themeText,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),

              SizedBox(height: 20),

              Center(
                child: Text(
                  'Never share your transaction PIN with anyone.',
                  style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.38), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }
}
