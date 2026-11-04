import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/core/theme/app_theme_controller.dart';
import 'package:digital_wallet_app/features/auth/presentation/forgot_password_screen.dart';
import 'package:digital_wallet_app/features/auth/presentation/register_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/account_recovery_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/wallet_dashboard_screen.dart';
import 'package:digital_wallet_app/core/config/api_config.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  // ==========================================================
  // API URL
  // ==========================================================
  //
  // Flutter Web / Chrome:
  // http://localhost:8000/api/login
  //
  // Android Emulator:
  // http://10.0.2.2:8000/api/login
  //
  // Physical Android Phone:
  // http://YOUR_PC_IP:8000/api/login
  //
  // ==========================================================

  // static const String _apiUrl = 'http://localhost:8000/api/login';
  final String _apiUrl = '${ApiConfig.baseUrl}/login';
  // ==========================================================
  // LOGIN
  // ==========================================================

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('➡️ Sending login request...');

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      debugPrint('⬅️ Login response: ${response.statusCode}');

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
      // LOGIN SUCCESS
      // ======================================================

      if (response.statusCode == 200) {
        String token = '';

        // ----------------------------------------------------
        // Direct access_token
        // ----------------------------------------------------

        if (responseData['access_token'] != null) {
          token = responseData['access_token'].toString().trim();
        }

        // ----------------------------------------------------
        // Direct token
        // ----------------------------------------------------

        if (token.isEmpty && responseData['token'] != null) {
          token = responseData['token'].toString().trim();
        }

        // ----------------------------------------------------
        // Nested data
        // ----------------------------------------------------

        if (token.isEmpty && responseData['data'] is Map) {
          final data = responseData['data'] as Map<String, dynamic>;

          if (data['access_token'] != null) {
            token = data['access_token'].toString().trim();
          }

          if (token.isEmpty && data['token'] != null) {
            token = data['token'].toString().trim();
          }
        }

        debugPrint('🔐 Login successful');

        debugPrint(
          '🔑 Authentication token received: '
          '${token.isNotEmpty ? "YES" : "NO"}',
        );

        // ====================================================
        // NEVER NAVIGATE WITH EMPTY TOKEN
        // ====================================================

        if (token.isEmpty) {
          _showError(
            'Login succeeded, but the server did not return '
            'an authentication token.',
          );
          return;
        }

        if (!mounted) return;

        // ====================================================
        // PASS TOKEN TO DASHBOARD
        // ====================================================

        ScaffoldMessenger.of(context).clearSnackBars();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            settings: RouteSettings(name: '/dashboard', arguments: token),
            builder: (_) => WalletDashboardScreen(activeToken: token),
          ),
        );
      } else {
        // ======================================================
        // LOGIN FAILED
        // ======================================================

        String message = 'Invalid credentials.';

        if (responseData['message'] != null) {
          message = responseData['message'].toString();
        } else if (responseData['error'] != null) {
          message = responseData['error'].toString();
        }

        _showError(message);
      }
    } on FormatException {
      _showError('The server returned an invalid response.');
    } catch (e) {
      debugPrint('❌ Login exception: $e');

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
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ==========================================================
  // INPUT DECORATION
  // ==========================================================

  InputDecoration _inputStyle({
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

      hintStyle: TextStyle(
        color: AppColors.themeText.withValues(alpha: 0.24),
        fontSize: 13,
      ),

      prefixIcon: Container(
        width: 48,
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: AppColors.themeText.withValues(alpha: 0.38),
          size: 19,
        ),
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
  // BRAND HEADER
  // ==========================================================

  Widget _buildHeader() {
    return Column(
      children: [
        _buildLogo(),

        SizedBox(height: 22),

        ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                AppColors.themeText,
                Color(0xFFDDE8FF),
                AppColors.neonPink,
              ],
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
          textAlign: TextAlign.center,

          style: TextStyle(
            color: AppColors.themeText.withValues(alpha: 0.54),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),

        SizedBox(height: 14),

        Text(
          'Welcome back',
          textAlign: TextAlign.center,

          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        SizedBox(height: 5),

        Text(
          'Sign in to manage your money securely.',
          textAlign: TextAlign.center,

          style: TextStyle(
            color: AppColors.themeText.withOpacity(0.42),
            fontSize: 12,
          ),
        ),
      ],
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
          Icon(LucideIcons.shieldCheck, color: Colors.greenAccent, size: 14),

          SizedBox(width: 7),

          Text(
            'SECURE WALLET ACCESS',
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
  // LOGIN CARD
  // ==========================================================

  Widget _buildLoginCard() {
    return Container(
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
            Text(
              'Sign in',

              style: TextStyle(
                color: AppColors.themeText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 5),

            Text(
              'Enter your account details below.',
              style: TextStyle(
                color: AppColors.themeText.withValues(alpha: 0.38),
                fontSize: 11,
              ),
            ),

            SizedBox(height: 22),

            // ==================================================
            // EMAIL
            // ==================================================
            TextFormField(
              controller: _emailController,

              keyboardType: TextInputType.emailAddress,

              textInputAction: TextInputAction.next,

              style: TextStyle(color: AppColors.themeText, fontSize: 14),

              decoration: _inputStyle(
                label: 'Email Address',
                hint: 'Enter your email',
                icon: LucideIcons.mail,
              ),

              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your email';
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

              textInputAction: TextInputAction.done,

              style: TextStyle(color: AppColors.themeText, fontSize: 14),

              decoration:
                  _inputStyle(
                    label: 'Password',
                    hint: 'Enter your password',
                    icon: LucideIcons.lock,
                  ).copyWith(
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
                  return 'Enter your password';
                }

                return null;
              },

              onFieldSubmitted: (_) {
                if (!_isLoading) {
                  _handleLogin();
                }
              },
            ),

            SizedBox(height: 22),

            // ==================================================
            // LOGIN BUTTON
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
                  onPressed: _isLoading ? null : _handleLogin,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,

                    disabledBackgroundColor: Colors.transparent,

                    shadowColor: Colors.transparent,

                    foregroundColor: AppColors.themeText,

                    disabledForegroundColor: AppColors.themeText.withValues(
                      alpha: 0.70,
                    ),

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
                              'SIGN IN',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),

                            SizedBox(width: 9),

                            Icon(LucideIcons.arrowRight, size: 17),
                          ],
                        ),
                ),
              ),
            ),

            // ==================================================
            // FORGOT PASSWORD
            // ==================================================
            Align(
              alignment: Alignment.centerRight,

              child: TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AccountRecoveryScreen(),
                          ),
                        );
                      },

                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),

                  foregroundColor: AppColors.royalBlue,
                ),

                child: Text(
                  'Forgot Password?',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
    );
  }

  // ==========================================================
  // REGISTER SECTION
  // ==========================================================

  Widget _buildRegisterSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(color: AppColors.themeText.withOpacity(0.07)),
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),

              child: Text(
                'NEW TO NANA?',
                style: TextStyle(
                  color: AppColors.themeText.withValues(alpha: 0.24),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),

            Expanded(
              child: Divider(color: AppColors.themeText.withOpacity(0.07)),
            ),
          ],
        ),

        SizedBox(height: 16),

        GestureDetector(
          onTap: () {
            Navigator.push(
              context,

              MaterialPageRoute(builder: (context) => RegisterScreen()),
            );
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
                  'Create a new account',
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
  // BACKGROUND DECORATION
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
    _passwordController.dispose();

    super.dispose();
  }

  // ==========================================================
  // UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    AppColors.dependOnTheme(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      body: Stack(
        children: [
          // ====================================================
          // BACKGROUND
          // ====================================================
          Positioned.fill(child: _buildBackground()),

          Positioned(
            top: 2,
            right: 12,
            child: SafeArea(
              child: AnimatedBuilder(
                animation: AppThemeController.instance,
                builder: (context, _) => IconButton(
                  tooltip: AppThemeController.instance.isDark
                      ? 'Switch to bright mode'
                      : 'Switch to dark mode',
                  onPressed: () => AppThemeController.instance.setDarkMode(
                    !AppThemeController.instance.isDark,
                  ),
                  icon: Icon(
                    AppThemeController.instance.isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),

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
                      // LOGIN CARD
                      // ==================================================
                      _buildLoginCard(),

                      SizedBox(height: 22),

                      // ==================================================
                      // REGISTER
                      // ==================================================
                      _buildRegisterSection(),

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
