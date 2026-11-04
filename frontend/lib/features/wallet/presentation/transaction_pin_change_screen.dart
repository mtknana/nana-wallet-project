import 'package:flutter/material.dart';
import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';

class TransactionPinChangeScreen extends StatefulWidget {
  final String token;

  TransactionPinChangeScreen({super.key, required this.token});

  @override
  State<TransactionPinChangeScreen> createState() =>
      _TransactionPinChangeScreenState();
}

class _TransactionPinChangeScreenState
    extends State<TransactionPinChangeScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _isLoading = false;

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  // ============================================================
  // CHANGE PIN
  // ============================================================

  Future<void> _changePin() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (widget.token.trim().isEmpty) {
      _showError('Authentication token is missing. Please login again.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await WalletService.changeTransactionPin(
        token: widget.token,
        currentPin: _currentPinController.text.trim(),
        newPin: _newPinController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      final status = result['status']?.toString().toLowerCase();

      if (status == 'success') {
        _showSuccessDialog();
        return;
      }

      _showError(
        result['message']?.toString() ?? 'Unable to change transaction PIN.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError('Unable to change transaction PIN. Please try again.');
    }
  }

  // ============================================================
  // SUCCESS
  // ============================================================

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.adaptiveSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  Icons.check_rounded,
                  color: Colors.greenAccent,
                  size: 42,
                ),
              ),

              SizedBox(height: 20),

              Text(
                'PIN Changed Successfully',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 10),

              Text(
                'Your transaction PIN has been updated successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.themeText.withValues(alpha: 0.60),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),

              SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.pop(context, true);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ============================================================
  // PIN FIELD
  // ============================================================

  Widget _pinField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: TextInputType.number,
      maxLength: 4,
      style: TextStyle(
        color: AppColors.themeText,
        fontSize: 17,
        letterSpacing: 5,
        fontWeight: FontWeight.bold,
      ),
      validator: validator,
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AppColors.themeText.withValues(alpha: 0.60)),
        hintStyle: TextStyle(color: AppColors.themeText.withValues(alpha: 0.24), letterSpacing: 2),
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          color: AppColors.royalBlue,
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.themeText.withValues(alpha: 0.38),
          ),
        ),
        filled: true,
        fillColor: AppColors.themeText.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.themeText.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.royalBlue, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.redAccent),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.themeText),
        title: Text(
          'Change Transaction PIN',
          style: TextStyle(
            color: AppColors.themeText,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 35),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==================================================
                // HEADER
                // ==================================================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.royalBlue.withOpacity(0.20),
                        AppColors.neonPink.withOpacity(0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.themeText.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.royalBlue.withOpacity(0.15),
                          border: Border.all(
                            color: AppColors.royalBlue.withOpacity(0.30),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.pin_outlined,
                          color: AppColors.royalBlue,
                          size: 32,
                        ),
                      ),

                      SizedBox(height: 16),

                      Text(
                        'Update Your PIN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.themeText,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 7),

                      Text(
                        'Change your 4-digit transaction PIN to keep your wallet secure.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.themeText.withValues(alpha: 0.54),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 30),

                Text(
                  'CURRENT PIN',
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.54),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),

                SizedBox(height: 12),

                _pinField(
                  controller: _currentPinController,
                  label: 'Current PIN',
                  hint: '••••',
                  obscureText: _obscureCurrent,
                  onToggle: () {
                    setState(() {
                      _obscureCurrent = !_obscureCurrent;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.length != 4) {
                      return 'Enter your current 4-digit PIN';
                    }

                    if (!RegExp(r'^\d{4}$').hasMatch(value)) {
                      return 'PIN must contain only numbers';
                    }

                    return null;
                  },
                ),

                SizedBox(height: 24),

                Text(
                  'NEW PIN',
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.54),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),

                SizedBox(height: 12),

                _pinField(
                  controller: _newPinController,
                  label: 'New PIN',
                  hint: '••••',
                  obscureText: _obscureNew,
                  onToggle: () {
                    setState(() {
                      _obscureNew = !_obscureNew;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.length != 4) {
                      return 'Enter a new 4-digit PIN';
                    }

                    if (!RegExp(r'^\d{4}$').hasMatch(value)) {
                      return 'PIN must contain only numbers';
                    }

                    if (value == _currentPinController.text) {
                      return 'New PIN must be different';
                    }

                    return null;
                  },
                ),

                SizedBox(height: 16),

                _pinField(
                  controller: _confirmPinController,
                  label: 'Confirm New PIN',
                  hint: '••••',
                  obscureText: _obscureConfirm,
                  onToggle: () {
                    setState(() {
                      _obscureConfirm = !_obscureConfirm;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.length != 4) {
                      return 'Confirm your new PIN';
                    }

                    if (value != _newPinController.text) {
                      return 'PINs do not match';
                    }

                    return null;
                  },
                ),

                SizedBox(height: 28),

                // ==================================================
                // SECURITY INFO
                // ==================================================
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.green.withOpacity(0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: Colors.greenAccent,
                        size: 21,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Never share your transaction PIN with anyone. NaNa Wallet will never ask you to disclose your PIN.',
                          style: TextStyle(
                            color: AppColors.themeText.withValues(alpha: 0.54),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 25),

                // ==================================================
                // CHANGE BUTTON
                // ==================================================
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _changePin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.royalBlue,
                      foregroundColor: AppColors.themeText,
                      disabledBackgroundColor: AppColors.royalBlue.withOpacity(
                        0.35,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.themeText,
                            ),
                          )
                        : Text(
                            'CHANGE PIN',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
