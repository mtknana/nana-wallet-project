import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/core/config/api_config.dart';

class ForgotPasswordScreen extends StatefulWidget {
  ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  // ==========================================================
  // CONTROLLERS
  // ==========================================================

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _codeController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // ==========================================================
  // STATE
  // ==========================================================

  bool _isLoading = false;
  bool _showResetStep = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String _resetCode = '';

  // ==========================================================
  // API URLS
  // ==========================================================

  static const String _forgotPasswordUrl =
      '${ApiConfig.baseUrl}/forgot-password';

  static const String _resetPasswordUrl =
      '${ApiConfig.baseUrl}/reset-password';

  // ==========================================================
  // STEP 1
  // REQUEST RESET CODE
  // ==========================================================

  Future<void> _requestResetCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(_forgotPasswordUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': _emailController.text.trim()}),
      );

      debugPrint('Forgot password response: ${response.statusCode}');

      if (response.body.isEmpty) {
        _showError('Server returned an empty response.');
        return;
      }

      final dynamic decodedResponse = jsonDecode(response.body);

      if (decodedResponse is! Map<String, dynamic>) {
        _showError('Invalid response from server.');
        return;
      }

      final Map<String, dynamic> responseData = decodedResponse;

      if (response.statusCode == 200 && responseData['status'] == 'success') {
        final String code = responseData['reset_code']?.toString() ?? '';

        if (code.isEmpty) {
          _showError('The server did not return a reset code.');
          return;
        }

        if (!mounted) return;

        setState(() {
          _resetCode = code;
          _showResetStep = true;
        });

        // ------------------------------------------------------
        // DEMO MESSAGE
        // ------------------------------------------------------
        //
        // The backend currently returns the reset code because
        // this is a local school-project implementation.
        //
        // In a real production wallet, this code would be sent
        // through email/SMS instead.
        //
        _showDemoCode(code);
      } else {
        _showError(
          responseData['message']?.toString() ??
              'Unable to request password reset.',
        );
      }
    } on FormatException {
      _showError('The server returned an invalid response.');
    } catch (e) {
      debugPrint('Forgot password exception: $e');

      _showError(
        'Network error. Please check that Laravel '
        'server is running.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ==========================================================
  // STEP 2
  // RESET PASSWORD
  // ==========================================================

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(_resetPasswordUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'token': _codeController.text.trim(),
          'password': _passwordController.text,
          'password_confirmation': _confirmPasswordController.text,
        }),
      );

      debugPrint('Reset password response: ${response.statusCode}');

      if (response.body.isEmpty) {
        _showError('Server returned an empty response.');
        return;
      }

      final dynamic decodedResponse = jsonDecode(response.body);

      if (decodedResponse is! Map<String, dynamic>) {
        _showError('Invalid response from server.');
        return;
      }

      final Map<String, dynamic> responseData = decodedResponse;

      if (response.statusCode == 200 && responseData['status'] == 'success') {
        if (!mounted) return;

        await _showSuccessDialog();

        if (!mounted) return;

        // Return to LoginScreen.
        Navigator.pop(context);
      } else {
        _showError(
          responseData['message']?.toString() ?? 'Unable to reset password.',
        );
      }
    } on FormatException {
      _showError('The server returned an invalid response.');
    } catch (e) {
      debugPrint('Reset password exception: $e');

      _showError(
        'Network error. Please check that Laravel '
        'server is running.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ==========================================================
  // DEMO RESET CODE
  // ==========================================================

  void _showDemoCode(String code) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: Duration(seconds: 5),
        backgroundColor: AppColors.adaptiveSurface,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(
              LucideIcons.keyRound,
              color: AppColors.neonPink,
              size: 19,
            ),

            SizedBox(width: 10),

            Expanded(
              child: Text(
                'Demo reset code: $code',
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

  // ==========================================================
  // SUCCESS DIALOG
  // ==========================================================

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.adaptiveSurface,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          title: Row(
            children: [
              Icon(
                LucideIcons.circleCheck,
                color: Colors.greenAccent,
                size: 24,
              ),

              SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Password Reset',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          content: Text(
            'Your password has been reset successfully. '
            'Please sign in with your new password.',
            style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.60), fontSize: 13),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                'CONTINUE',
                style: TextStyle(
                  color: AppColors.royalBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // ERROR
  // ==========================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),

        backgroundColor: Colors.redAccent,

        behavior: SnackBarBehavior.floating,

        margin: const EdgeInsets.all(16),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ==========================================================
  // INPUT STYLE
  // ==========================================================

  InputDecoration _inputStyle({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,

      hintText: hint,

      labelStyle: TextStyle(
        color: AppColors.themeText.withValues(alpha: 0.54),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),

      floatingLabelStyle: TextStyle(
        color: AppColors.royalBlue,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),

      hintStyle: TextStyle(color: AppColors.themeText.withValues(alpha: 0.24), fontSize: 13),

      prefixIcon: SizedBox(
        width: 48,
        child: Center(child: Icon(icon, color: AppColors.themeText.withValues(alpha: 0.38), size: 19)),
      ),

      suffixIcon: suffixIcon,

      prefixIconConstraints: BoxConstraints(minWidth: 48, minHeight: 0),

      filled: true,

      fillColor: AppColors.adaptiveSurfaceAlt,

      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.themeText.withOpacity(0.06)),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.royalBlue, width: 1.3),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.redAccent),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.redAccent, width: 1.3),
      ),

      errorStyle: TextStyle(color: Colors.redAccent, fontSize: 10),
    );
  }

  // ==========================================================
  // LOGO
  // ==========================================================

  Widget _buildLogo() {
    return Container(
      width: 76,
      height: 76,

      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.royalBlue, AppColors.neonPink],
        ),

        borderRadius: BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color: AppColors.royalBlue.withOpacity(0.25),
            blurRadius: 28,
            spreadRadius: 2,
          ),

          BoxShadow(
            color: AppColors.neonPink.withOpacity(0.12),
            blurRadius: 35,
            spreadRadius: 1,
          ),
        ],
      ),

      child: Container(
        margin: const EdgeInsets.all(1.5),

        decoration: BoxDecoration(
          color: AppColors.adaptiveSurfaceAlt,
          borderRadius: BorderRadius.circular(22),
        ),

        child: Icon(
          LucideIcons.lockKeyhole,
          color: AppColors.themeText,
          size: 34,
        ),
      ),
    );
  }

  // ==========================================================
  // HEADER
  // ==========================================================

  Widget _buildHeader() {
    return Column(
      children: [
        _buildLogo(),

        SizedBox(height: 22),

        ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [AppColors.themeText, Color(0xFFDDE8FF), AppColors.neonPink],
            ).createShader(bounds);
          },

          child: Text(
            _showResetStep ? 'Create New Password' : 'Forgot Password',

            textAlign: TextAlign.center,

            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),

        SizedBox(height: 8),

        Text(
          _showResetStep
              ? 'Verify your code and create a new password.'
              : 'Recover your NaNa Wallet account securely.',

          textAlign: TextAlign.center,

          style: TextStyle(color: AppColors.themeText.withOpacity(0.42), fontSize: 12),
        ),
      ],
    );
  }

  // ==========================================================
  // EMAIL STEP
  // ==========================================================

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Forgot your password?',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        SizedBox(height: 6),

        Text(
          'Enter your registered email address to continue.',
          style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.38), fontSize: 11),
        ),

        SizedBox(height: 22),

        TextFormField(
          controller: _emailController,

          keyboardType: TextInputType.emailAddress,

          textInputAction: TextInputAction.done,

          style: TextStyle(color: AppColors.themeText, fontSize: 14),

          decoration: _inputStyle(
            label: 'Email Address',
            hint: 'Enter your registered email',
            icon: LucideIcons.mail,
          ),

          validator: (value) {
            final email = value?.trim() ?? '';

            if (email.isEmpty) {
              return 'Enter your email';
            }

            if (!email.contains('@') || !email.contains('.')) {
              return 'Enter a valid email address';
            }

            return null;
          },

          onFieldSubmitted: (_) {
            if (!_isLoading) {
              _requestResetCode();
            }
          },
        ),

        SizedBox(height: 22),

        _buildPrimaryButton(
          text: 'CONTINUE',
          icon: LucideIcons.arrowRight,
          onPressed: _requestResetCode,
        ),
      ],
    );
  }

  // ==========================================================
  // RESET STEP
  // ==========================================================

  Widget _buildResetStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verify & reset password',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        SizedBox(height: 6),

        Text(
          'Resetting password for ${_emailController.text.trim()}',
          style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.38), fontSize: 11),
        ),

        SizedBox(height: 22),

        // ======================================================
        // RESET CODE
        // ======================================================
        TextFormField(
          controller: _codeController,

          keyboardType: TextInputType.number,

          maxLength: 6,

          textAlign: TextAlign.center,

          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 18,
            letterSpacing: 5,
            fontWeight: FontWeight.bold,
          ),

          decoration: _inputStyle(
            label: 'Reset Code',
            hint: '000000',
            icon: LucideIcons.keyRound,
          ).copyWith(counterText: ''),

          validator: (value) {
            final code = value?.trim() ?? '';

            if (code.length != 6) {
              return 'Enter the 6-digit reset code';
            }

            if (code != _resetCode) {
              return 'Incorrect reset code';
            }

            return null;
          },
        ),

        SizedBox(height: 16),

        // ======================================================
        // NEW PASSWORD
        // ======================================================
        TextFormField(
          controller: _passwordController,

          obscureText: _obscurePassword,

          style: TextStyle(color: AppColors.themeText, fontSize: 14),

          decoration: _inputStyle(
            label: 'New Password',
            hint: 'Enter your new password',
            icon: LucideIcons.lock,

            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },

              icon: Icon(
                _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                color: AppColors.themeText.withValues(alpha: 0.38),
                size: 19,
              ),
            ),
          ),

          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Enter a new password';
            }

            if (value.length < 8) {
              return 'Password must be at least 8 characters';
            }

            return null;
          },
        ),

        SizedBox(height: 16),

        // ======================================================
        // CONFIRM PASSWORD
        // ======================================================
        TextFormField(
          controller: _confirmPasswordController,

          obscureText: _obscureConfirmPassword,

          style: TextStyle(color: AppColors.themeText, fontSize: 14),

          decoration: _inputStyle(
            label: 'Confirm Password',
            hint: 'Re-enter your new password',
            icon: LucideIcons.lockKeyhole,

            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },

              icon: Icon(
                _obscureConfirmPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                color: AppColors.themeText.withValues(alpha: 0.38),
                size: 19,
              ),
            ),
          ),

          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Confirm your password';
            }

            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }

            return null;
          },
        ),

        SizedBox(height: 22),

        _buildPrimaryButton(
          text: 'RESET PASSWORD',
          icon: LucideIcons.shieldCheck,
          onPressed: _resetPassword,
        ),

        SizedBox(height: 12),

        Center(
          child: TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    setState(() {
                      _showResetStep = false;
                      _codeController.clear();
                      _passwordController.clear();
                      _confirmPasswordController.clear();
                    });
                  },
            child: Text(
              'Use a different email',
              style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.54), fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // PRIMARY BUTTON
  // ==========================================================

  Widget _buildPrimaryButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 54,

      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.royalBlue, AppColors.neonPink],
          ),

          borderRadius: BorderRadius.circular(15),

          boxShadow: [
            BoxShadow(
              color: AppColors.royalBlue.withOpacity(0.18),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),

        child: ElevatedButton(
          onPressed: _isLoading ? null : onPressed,

          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,

            disabledBackgroundColor: Colors.transparent,

            shadowColor: Colors.transparent,

            foregroundColor: AppColors.themeText,

            disabledForegroundColor: AppColors.themeText.withValues(alpha: 0.70),

            elevation: 0,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),

          child: _isLoading
              ? SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    color: AppColors.themeText,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),

                    SizedBox(width: 9),

                    Icon(icon, size: 17),
                  ],
                ),
        ),
      ),
    );
  }

  // ==========================================================
  // SECURITY BADGE
  // ==========================================================

  Widget _buildSecurityBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),

      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.06),

        borderRadius: BorderRadius.circular(10),

        border: Border.all(color: Colors.greenAccent.withOpacity(0.10)),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(
            LucideIcons.shieldCheck,
            color: Colors.greenAccent,
            size: 14,
          ),

          SizedBox(width: 7),

          Text(
            'SECURE PASSWORD RECOVERY',
            style: TextStyle(
              color: AppColors.themeText.withOpacity(0.55),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // BACKGROUND
  // ==========================================================

  Widget _buildBackground() {
    return Stack(
      children: [
        Positioned(
          top: -150,
          left: -130,

          child: Container(
            width: 340,
            height: 340,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              gradient: RadialGradient(
                colors: [
                  AppColors.royalBlue.withOpacity(0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        Positioned(
          bottom: -180,
          right: -130,

          child: Container(
            width: 380,
            height: 380,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              gradient: RadialGradient(
                colors: [
                  AppColors.neonPink.withOpacity(0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        Positioned(
          top: 0,
          right: 0,
          left: 0,

          child: Container(
            height: 1,

            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.royalBlue.withOpacity(0.25),
                  AppColors.neonPink.withOpacity(0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    AppColors.dependOnTheme(context);
    return Scaffold(
      backgroundColor: AppColors.adaptiveSurfaceAlt,

      body: Stack(
        children: [
          Positioned.fill(child: _buildBackground()),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),

                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 28,
                ),

                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 460),

                  child: Column(
                    children: [
                      // HEADER
                      _buildHeader(),

                      SizedBox(height: 30),

                      // CARD
                      Container(
                        padding: const EdgeInsets.all(22),

                        decoration: BoxDecoration(
                          color: AppColors.adaptiveSurface.withOpacity(0.92),

                          borderRadius: BorderRadius.circular(24),

                          border: Border.all(
                            color: AppColors.themeText.withOpacity(0.07),
                          ),

                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 30,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),

                        child: Form(
                          key: _formKey,

                          child: _showResetStep
                              ? _buildResetStep()
                              : _buildEmailStep(),
                        ),
                      ),

                      SizedBox(height: 22),

                      // BACK TO LOGIN
                      TextButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.pop(context);
                              },

                        icon: Icon(LucideIcons.arrowLeft, size: 15),

                        label: Text(
                          'Back to Sign In',
                          style: TextStyle(fontSize: 12),
                        ),

                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.themeText.withValues(alpha: 0.54),
                        ),
                      ),

                      SizedBox(height: 8),

                      _buildSecurityBadge(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
