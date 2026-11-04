import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/core/config/api_config.dart';

class AccountRecoveryScreen extends StatefulWidget {
  AccountRecoveryScreen({super.key});

  @override
  State<AccountRecoveryScreen> createState() => _AccountRecoveryScreenState();
}

class _AccountRecoveryScreenState extends State<AccountRecoveryScreen> {
  static const String _baseUrl = ApiConfig.baseUrl;

  final PageController _pageController = PageController();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _codeController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  int _currentStep = 0;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _errorMessage;

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ============================================================
  // REQUEST RECOVERY CODE
  // ============================================================

  Future<void> _requestRecoveryCode() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showError('Please enter your email address.');
      return;
    }

    if (!email.contains('@')) {
      _showError('Please enter a valid email address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/account-recovery/request'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _currentStep = 1;
        });

        _pageController.animateToPage(
          1,
          duration: Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );

        // School-project implementation:
        // The backend returns the generated code.
        if (data['code'] != null) {
          _showInfo('Recovery code: ${data['code']}');
        }

        return;
      }

      throw Exception(data['message'] ?? 'Unable to request recovery code.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ============================================================
  // VERIFY CODE
  // ============================================================

  Future<void> _verifyRecoveryCode() async {
    final code = _codeController.text.trim();

    if (code.length != 6) {
      _showError('Please enter the 6-digit recovery code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/account-recovery/verify'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': _emailController.text.trim(), 'code': code}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _currentStep = 2;
        });

        _pageController.animateToPage(
          2,
          duration: Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );

        return;
      }

      throw Exception(data['message'] ?? 'Invalid recovery code.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ============================================================
  // COMPLETE RECOVERY
  // ============================================================

  Future<void> _completeRecovery() async {
    final password = _passwordController.text;

    final confirmPassword = _confirmPasswordController.text;

    if (password.isEmpty || confirmPassword.isEmpty) {
      _showError('Please enter and confirm your new password.');
      return;
    }

    if (password.length < 8) {
      _showError('Password must be at least 8 characters.');
      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/account-recovery/complete'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'code': _codeController.text.trim(),
          'password': password,
          'password_confirmation': confirmPassword,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        await _showSuccessDialog();

        if (!mounted) return;

        Navigator.pop(context);
        return;
      }

      throw Exception(data['message'] ?? 'Unable to recover account.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ============================================================
  // SUCCESS DIALOG
  // ============================================================

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.adaptiveSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.greenAccent.withOpacity(0.12),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Colors.greenAccent,
                    size: 42,
                  ),
                ),
                SizedBox(height: 18),
                Text(
                  'Account Recovered',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Your password has been reset successfully. '
                  'Please login again with your new password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.themeText.withOpacity(0.62),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
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
                      'Continue',
                      style: TextStyle(fontWeight: FontWeight.w700),
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
  // NAVIGATION
  // ============================================================

  void _goBack() {
    if (_currentStep == 0) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _currentStep--;
    });

    _pageController.animateToPage(
      _currentStep,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
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
        leading: IconButton(
          onPressed: _isLoading ? null : _goBack,
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.themeText,
          ),
        ),
        title: Text(
          'Account Recovery',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: NeverScrollableScrollPhysics(),
                children: [
                  _buildEmailStep(),
                  _buildCodeStep(),
                  _buildPasswordStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PROGRESS INDICATOR
  // ============================================================

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 14),
      child: Row(
        children: [
          _progressCircle(number: '1', active: _currentStep >= 0),
          _progressLine(active: _currentStep >= 1),
          _progressCircle(number: '2', active: _currentStep >= 1),
          _progressLine(active: _currentStep >= 2),
          _progressCircle(number: '3', active: _currentStep >= 2),
        ],
      ),
    );
  }

  Widget _progressCircle({required String number, required bool active}) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 250),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.royalBlue : AppColors.themeText.withOpacity(0.08),
        border: Border.all(
          color: active ? AppColors.royalBlue : AppColors.themeText.withOpacity(0.15),
        ),
      ),
      child: Center(
        child: Text(
          number,
          style: TextStyle(
            color: active ? AppColors.themeText : AppColors.themeText.withValues(alpha: 0.38),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _progressLine({required bool active}) {
    return Expanded(
      child: AnimatedContainer(
        duration: Duration(milliseconds: 250),
        height: 2,
        color: active ? AppColors.royalBlue : AppColors.themeText.withOpacity(0.1),
      ),
    );
  }

  // ============================================================
  // STEP 1 — EMAIL
  // ============================================================

  Widget _buildEmailStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroIcon(Icons.lock_reset_rounded),
          SizedBox(height: 22),
          Text(
            'Recover Your Account',
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 9),
          Text(
            'Enter the email address linked '
            'to your NaNa Wallet account. '
            'We will generate a recovery code '
            'for verification.',
            style: TextStyle(
              color: AppColors.themeText.withOpacity(0.58),
              fontSize: 14,
              height: 1.55,
            ),
          ),
          SizedBox(height: 30),
          _buildLabel('Email Address'),
          SizedBox(height: 9),
          _buildTextField(
            controller: _emailController,
            hint: 'Enter your email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 26),
          _buildSecurityInfo(
            'For your security, you must verify '
            'your identity before creating a new password.',
          ),
          SizedBox(height: 28),
          _buildPrimaryButton(
            text: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: _requestRecoveryCode,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 2 — CODE
  // ============================================================

  Widget _buildCodeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroIcon(Icons.verified_user_outlined),
          SizedBox(height: 22),
          Text(
            'Verify Recovery Code',
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 9),
          Text(
            'Enter the 6-digit recovery code '
            'generated for:',
            style: TextStyle(
              color: AppColors.themeText.withOpacity(0.58),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          SizedBox(height: 6),
          Text(
            _emailController.text.trim(),
            style: TextStyle(
              color: AppColors.neonPink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 30),
          _buildLabel('Recovery Code'),
          SizedBox(height: 9),
          _buildTextField(
            controller: _codeController,
            hint: 'Enter 6-digit code',
            icon: Icons.password_rounded,
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          SizedBox(height: 20),
          _buildSecurityInfo(
            'The recovery code is valid for '
            '15 minutes.',
          ),
          SizedBox(height: 28),
          _buildPrimaryButton(
            text: 'Verify Code',
            icon: Icons.verified_rounded,
            onPressed: _verifyRecoveryCode,
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _isLoading ? null : _requestRecoveryCode,
              child: Text(
                'Generate New Code',
                style: TextStyle(
                  color: AppColors.royalBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 3 — NEW PASSWORD
  // ============================================================

  Widget _buildPasswordStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroIcon(Icons.lock_outline_rounded),
          SizedBox(height: 22),
          Text(
            'Create New Password',
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 9),
          Text(
            'Choose a strong password for '
            'your NaNa Wallet account.',
            style: TextStyle(
              color: AppColors.themeText.withOpacity(0.58),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          SizedBox(height: 30),
          _buildLabel('New Password'),
          SizedBox(height: 9),
          _buildTextField(
            controller: _passwordController,
            hint: 'Enter new password',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.themeText.withValues(alpha: 0.54),
              ),
            ),
          ),
          SizedBox(height: 18),
          _buildLabel('Confirm Password'),
          SizedBox(height: 9),
          _buildTextField(
            controller: _confirmPasswordController,
            hint: 'Confirm new password',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.themeText.withValues(alpha: 0.54),
              ),
            ),
          ),
          SizedBox(height: 20),
          _buildPasswordRequirements(),
          SizedBox(height: 28),
          _buildPrimaryButton(
            text: 'Recover Account',
            icon: Icons.security_rounded,
            onPressed: _completeRecovery,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HERO ICON
  // ============================================================

  Widget _buildHeroIcon(IconData icon) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.royalBlue.withOpacity(0.22),
            AppColors.neonPink.withOpacity(0.14),
          ],
        ),
        border: Border.all(color: AppColors.themeText.withOpacity(0.08)),
      ),
      child: Icon(icon, color: AppColors.themeText, size: 36),
    );
  }

  // ============================================================
  // LABEL
  // ============================================================

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.themeText.withOpacity(0.72),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      style: TextStyle(color: AppColors.themeText, fontSize: 14),
      cursorColor: AppColors.royalBlue,
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.themeText.withOpacity(0.28),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: AppColors.themeText.withValues(alpha: 0.54), size: 21),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.themeText.withOpacity(0.045),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.themeText.withOpacity(0.07)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.themeText.withOpacity(0.07)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.royalBlue.withOpacity(0.8),
            width: 1.2,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECURITY INFO
  // ============================================================

  Widget _buildSecurityInfo(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.royalBlue.withOpacity(0.07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.royalBlue.withOpacity(0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.royalBlue,
            size: 19,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.themeText.withOpacity(0.58),
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PASSWORD REQUIREMENTS
  // ============================================================

  Widget _buildPasswordRequirements() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.themeText.withOpacity(0.035),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.themeText.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password Requirements',
            style: TextStyle(
              color: AppColors.themeText.withOpacity(0.72),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10),
          _requirement('At least 8 characters'),
          _requirement('Use a combination of letters and numbers'),
          _requirement('Do not share your password with anyone'),
        ],
      ),
    );
  }

  Widget _requirement(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.greenAccent.withOpacity(0.8),
            size: 15,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.themeText.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PRIMARY BUTTON
  // ============================================================

  Widget _buildPrimaryButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: _isLoading
            ? SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.themeText,
                ),
              )
            : Icon(icon),
        label: Text(
          _isLoading ? 'Please wait...' : text,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.royalBlue,
          disabledBackgroundColor: AppColors.royalBlue.withOpacity(0.45),
          foregroundColor: AppColors.themeText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Color(0xFF2A171B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Expanded(
              child: Text(message, style: TextStyle(color: AppColors.themeText)),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INFO
  // ============================================================

  void _showInfo(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: Duration(seconds: 10),
        backgroundColor: AppColors.adaptiveSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_rounded, color: Colors.greenAccent),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: AppColors.themeText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
