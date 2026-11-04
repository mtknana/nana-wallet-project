import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/core/config/api_config.dart';

class RegisterScreen extends StatefulWidget {
  RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // ==========================================================
  // API URL
  // ==========================================================

  static const String _apiUrl = '${ApiConfig.baseUrl}/register';

  // ==========================================================
  // REGISTER
  // ==========================================================

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('➡️ Sending registration request...');

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
          'password_confirmation': _confirmPasswordController.text.trim(),
        }),
      );

      debugPrint('⬅️ Register response: ${response.statusCode}');

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

      // ======================================================
      // REGISTRATION SUCCESS
      // ======================================================

      if (response.statusCode == 201) {
        debugPrint('✅ Account created successfully');

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(LucideIcons.circleCheck, color: AppColors.themeText, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Account created! Welcome to NaNa Wallet.'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );

        await Future.delayed(Duration(milliseconds: 600));

        if (!mounted) return;

        Navigator.pop(context);
      } else {
        // ====================================================
        // REGISTRATION FAILED
        // ====================================================

        String message = 'Registration failed.';

        if (responseData['message'] != null) {
          message = responseData['message'].toString();
        } else if (responseData['error'] != null) {
          message = responseData['error'].toString();
        }

        // Laravel validation errors
        if (responseData['errors'] is Map) {
          final errors = responseData['errors'] as Map<String, dynamic>;

          final List<String> messages = [];

          for (final value in errors.values) {
            if (value is List && value.isNotEmpty) {
              messages.add(value.first.toString());
            }
          }

          if (messages.isNotEmpty) {
            message = messages.join('\n');
          }
        }

        _showError(message);
      }
    } on FormatException {
      _showError('The server returned an invalid response.');
    } catch (error) {
      debugPrint('❌ Registration exception: $error');

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
  // ERROR MESSAGE
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
        duration: Duration(seconds: 3),
      ),
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
          LucideIcons.walletCards,
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

        SizedBox(height: 20),

        ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [AppColors.themeText, Color(0xFFDDE8FF), AppColors.neonPink],
            ).createShader(bounds);
          },

          child: Text(
            'NaNa',

            textAlign: TextAlign.center,

            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),

        SizedBox(height: 2),

        Text(
          'WALLET',

          style: TextStyle(
            color: AppColors.themeText.withValues(alpha: 0.54),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),

        SizedBox(height: 14),

        Text(
          'Create your account',

          textAlign: TextAlign.center,

          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        SizedBox(height: 5),

        Text(
          'Join NaNa and take control of your money.',
          textAlign: TextAlign.center,

          style: TextStyle(color: AppColors.themeText.withOpacity(0.42), fontSize: 12),
        ),
      ],
    );
  }

  // ==========================================================
  // INPUT DECORATION
  // ==========================================================

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,

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

      hintText: hint,

      hintStyle: TextStyle(color: AppColors.themeText.withValues(alpha: 0.24), fontSize: 13),

      prefixIcon: Container(
        width: 48,

        alignment: Alignment.center,

        child: Icon(icon, color: AppColors.themeText.withValues(alpha: 0.38), size: 19),
      ),

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
            'YOUR DATA IS SECURE',
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
  // REGISTER CARD
  // ==========================================================

  Widget _buildRegisterCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),

      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),

        child: Container(
          padding: const EdgeInsets.all(22),

          decoration: BoxDecoration(
            color: AppColors.adaptiveSurface.withOpacity(0.92),

            borderRadius: BorderRadius.circular(24),

            border: Border.all(color: AppColors.themeText.withOpacity(0.07)),

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

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [
                // ==================================================
                // CARD TITLE
                // ==================================================
                Text(
                  'Create your account',

                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  'Fill in your details to get started.',
                  style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.38), fontSize: 11),
                ),

                SizedBox(height: 22),

                // ==================================================
                // FULL NAME
                // ==================================================
                TextFormField(
                  controller: _nameController,

                  textCapitalization: TextCapitalization.words,

                  textInputAction: TextInputAction.next,

                  style: TextStyle(color: AppColors.themeText, fontSize: 14),

                  decoration: _inputDecoration(
                    label: 'Full Name',
                    hint: 'Enter your full name',
                    icon: LucideIcons.user,
                  ),

                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your name';
                    }

                    if (value.trim().length < 2) {
                      return 'Name is too short';
                    }

                    return null;
                  },
                ),

                SizedBox(height: 16),

                // ==================================================
                // EMAIL
                // ==================================================
                TextFormField(
                  controller: _emailController,

                  keyboardType: TextInputType.emailAddress,

                  textInputAction: TextInputAction.next,

                  style: TextStyle(color: AppColors.themeText, fontSize: 14),

                  decoration: _inputDecoration(
                    label: 'Email Address',
                    hint: 'Enter your email',
                    icon: LucideIcons.mail,
                  ),

                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your email';
                    }

                    final email = value.trim();

                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

                    if (!emailRegex.hasMatch(email)) {
                      return 'Enter a valid email address';
                    }

                    return null;
                  },
                ),

                SizedBox(height: 16),

                // ==================================================
                // PASSWORD
                // ==================================================
                TextFormField(
                  controller: _passwordController,

                  obscureText: _obscurePassword,

                  textInputAction: TextInputAction.next,

                  style: TextStyle(color: AppColors.themeText, fontSize: 14),

                  decoration:
                      _inputDecoration(
                        label: 'Password',
                        hint: 'Create a password',
                        icon: LucideIcons.lock,
                      ).copyWith(
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },

                          icon: Icon(
                            _obscurePassword
                                ? LucideIcons.eyeOff
                                : LucideIcons.eye,

                            color: AppColors.themeText.withValues(alpha: 0.38),

                            size: 19,
                          ),
                        ),
                      ),

                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter a password';
                    }

                    if (value.length < 8) {
                      return 'Minimum 8 characters required';
                    }

                    return null;
                  },
                ),

                SizedBox(height: 16),

                // ==================================================
                // CONFIRM PASSWORD
                // ==================================================
                TextFormField(
                  controller: _confirmPasswordController,

                  obscureText: _obscureConfirmPassword,

                  textInputAction: TextInputAction.done,

                  style: TextStyle(color: AppColors.themeText, fontSize: 14),

                  decoration:
                      _inputDecoration(
                        label: 'Confirm Password',
                        hint: 'Re-enter your password',
                        icon: LucideIcons.lockKeyhole,
                      ).copyWith(
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },

                          icon: Icon(
                            _obscureConfirmPassword
                                ? LucideIcons.eyeOff
                                : LucideIcons.eye,

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

                  onFieldSubmitted: (_) {
                    if (!_isLoading) {
                      _handleRegister();
                    }
                  },
                ),

                SizedBox(height: 22),

                // ==================================================
                // CREATE ACCOUNT BUTTON
                // ==================================================
                SizedBox(
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
                      onPressed: _isLoading ? null : _handleRegister,

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,

                        disabledBackgroundColor: Colors.transparent,

                        foregroundColor: AppColors.themeText,

                        disabledForegroundColor: AppColors.themeText.withValues(alpha: 0.70),

                        shadowColor: Colors.transparent,

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
                                  'CREATE ACCOUNT',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),

                                SizedBox(width: 9),

                                Icon(LucideIcons.arrowRight, size: 17),
                              ],
                            ),
                    ),
                  ),
                ),

                SizedBox(height: 18),

                // ==================================================
                // SECURITY
                // ==================================================
                Center(child: _buildSecurityBadge()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // BACKGROUND
  // ==========================================================

  Widget _buildBackground() {
    return Stack(
      children: [
        // Blue glow
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

        // Pink glow
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

        // Top accent line
        Positioned(
          top: 0,
          left: 0,
          right: 0,

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
  // ALREADY HAVE ACCOUNT
  // ==========================================================

  Widget _buildSignInSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.themeText.withOpacity(0.07))),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),

              child: Text(
                'ALREADY A MEMBER?',
                style: TextStyle(
                  color: AppColors.themeText.withValues(alpha: 0.24),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),

            Expanded(child: Divider(color: AppColors.themeText.withOpacity(0.07))),
          ],
        ),

        SizedBox(height: 16),

        GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },

          child: Container(
            width: double.infinity,

            padding: const EdgeInsets.symmetric(vertical: 15),

            decoration: BoxDecoration(
              color: AppColors.themeText.withOpacity(0.035),

              borderRadius: BorderRadius.circular(14),

              border: Border.all(color: AppColors.themeText.withOpacity(0.07)),
            ),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                Text(
                  'Back to Sign In',
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.70),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                SizedBox(width: 8),

                Icon(
                  LucideIcons.arrowUpRight,
                  color: AppColors.neonPink,
                  size: 16,
                ),
              ],
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  // ==========================================================
  // UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    AppColors.dependOnTheme(context);
    return Scaffold(
      backgroundColor: AppColors.adaptiveSurfaceAlt,

      body: Stack(
        children: [
          // ====================================================
          // BACKGROUND
          // ====================================================
          Positioned.fill(child: _buildBackground()),

          // ====================================================
          // CONTENT
          // ====================================================
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
                      // ==================================================
                      // HEADER
                      // ==================================================
                      _buildHeader(),

                      SizedBox(height: 30),

                      // ==================================================
                      // REGISTER CARD
                      // ==================================================
                      _buildRegisterCard(),

                      SizedBox(height: 22),

                      // ==================================================
                      // SIGN IN
                      // ==================================================
                      _buildSignInSection(),

                      SizedBox(height: 25),

                      // ==================================================
                      // FOOTER
                      // ==================================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          Icon(
                            LucideIcons.shieldCheck,
                            color: AppColors.themeText.withValues(alpha: 0.24),
                            size: 12,
                          ),

                          SizedBox(width: 5),

                          Text(
                            'Protected by NaNa Wallet Security',
                            style: TextStyle(
                              color: AppColors.themeText.withOpacity(0.22),

                              fontSize: 9,

                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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
