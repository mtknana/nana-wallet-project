import 'package:flutter/material.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';
import 'package:digital_wallet_app/features/wallet/services/biometric_service.dart';

class SecurityScreen extends StatefulWidget {
  final String token;

  SecurityScreen({super.key, required this.token});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  // ============================================================
  // TRANSACTION PIN
  // ============================================================

  bool _hasTransactionPin = false;
  bool _isLoadingPin = true;

  // ============================================================
  // TWO-FACTOR AUTHENTICATION
  // ============================================================

  bool _twoFactorEnabled = false;
  bool _isUpdating2FA = false;

  // ============================================================
  // SECURITY EVENTS
  // US-048 Security Alerts
  // ============================================================

  bool _isLoadingSecurityEvents = true;
  List<Map<String, dynamic>> _securityEvents = [];

  // ============================================================
  // BIOMETRIC
  // ============================================================

  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _hasFingerprint = false;
  bool _hasFaceId = false;
  bool _isLoadingBiometric = true;
  bool _isTestingBiometric = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadSecurityStatus();
    _loadBiometricStatus();
    _loadSecurityEvents();
  }

  // ============================================================
  // LOAD SECURITY STATUS
  // ============================================================

  Future<void> _loadSecurityStatus() async {
    await Future.wait([_loadTransactionPinStatus(), _loadTwoFactorStatus()]);
  }

  // ============================================================
  // LOAD 2FA
  // ============================================================

  Future<void> _loadTwoFactorStatus() async {
    try {
      final response = await WalletService.getTwoFactorStatus(
        token: widget.token,
      );

      if (!mounted) return;

      if (response['status'] == 'success') {
        setState(() {
          _twoFactorEnabled = response['two_factor_enabled'] == true;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load 2FA status: $e');
    }
  }

  // ============================================================
  // LOAD TRANSACTION PIN
  // ============================================================

  Future<void> _loadTransactionPinStatus() async {
    try {
      final result = await WalletService.getTransactionPinStatus(
        token: widget.token,
      );

      if (!mounted) return;

      if (result['status']?.toString().toLowerCase() == 'success') {
        setState(() {
          _hasTransactionPin = result['has_transaction_pin'] == true;
          _isLoadingPin = false;
        });
      } else {
        setState(() {
          _isLoadingPin = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load transaction PIN status: $e');

      if (!mounted) return;

      setState(() {
        _isLoadingPin = false;
      });
    }
  }

  // ============================================================
  // LOAD SECURITY EVENTS
  // US-048 Security Alerts
  // ============================================================

  Future<void> _loadSecurityEvents() async {
    if (!mounted) return;

    setState(() {
      _isLoadingSecurityEvents = true;
    });

    try {
      final events = await WalletService.fetchSecurityEvents(
        token: widget.token,
      );

      if (!mounted) return;

      setState(() {
        _securityEvents = events;
        _isLoadingSecurityEvents = false;
      });
    } catch (e) {
      debugPrint('❌ Failed to load security events: $e');

      if (!mounted) return;

      setState(() {
        _securityEvents = [];
        _isLoadingSecurityEvents = false;
      });
    }
  }

  // ============================================================
  // LOAD BIOMETRIC STATUS
  // ============================================================

  Future<void> _loadBiometricStatus() async {
    try {
      final available = await BiometricService.isAvailable();

      final biometrics = await BiometricService.getAvailableBiometrics();

      if (!mounted) return;

      setState(() {
        _biometricAvailable = available;

        _hasFingerprint = BiometricService.hasFingerprint(biometrics);

        _hasFaceId = BiometricService.hasFaceId(biometrics);

        _isLoadingBiometric = false;
      });
    } catch (e) {
      debugPrint('❌ Failed to load biometric status: $e');

      if (!mounted) return;

      setState(() {
        _biometricAvailable = false;
        _isLoadingBiometric = false;
      });
    }
  }

  // ============================================================
  // TEST / ENABLE BIOMETRIC
  // ============================================================

  Future<void> _setupBiometric() async {
    if (_isTestingBiometric) return;

    if (!_biometricAvailable) {
      _showError('Biometric authentication is not available on this device.');
      return;
    }

    setState(() {
      _isTestingBiometric = true;
    });

    try {
      final authenticated = await BiometricService.authenticate(
        reason: 'Verify your biometric identity to enable secure payments.',
      );

      if (!mounted) return;

      if (authenticated) {
        setState(() {
          _biometricEnabled = true;
        });

        final biometrics = await BiometricService.getAvailableBiometrics();

        final biometricName = BiometricService.getBiometricName(biometrics);

        _showSuccess('$biometricName enabled successfully.');
      } else {
        _showError('Biometric verification was cancelled or failed.');
      }
    } catch (e) {
      if (!mounted) return;

      _showError('Unable to enable biometric authentication.');
    } finally {
      if (mounted) {
        setState(() {
          _isTestingBiometric = false;
        });
      }
    }
  }

  // ============================================================
  // TRANSACTION PIN
  // ============================================================

  Future<void> _openTransactionPin() async {
    if (widget.token.trim().isEmpty) {
      _showError('Authentication token is missing. Please login again.');
      return;
    }

    final route = _hasTransactionPin
        ? '/transaction-pin-change'
        : '/transaction-pin-setup';

    final result = await Navigator.pushNamed(
      context,
      route,
      arguments: widget.token,
    );

    if (result == true && mounted) {
      _loadTransactionPinStatus();
      _loadSecurityEvents();
    }
  }

  // ============================================================
  // EMAIL VERIFICATION
  // ============================================================

  Future<void> _openEmailVerification() async {
    final controller = TextEditingController();

    final otp = await showDialog<String>(
      context: context,
      builder: (context) {
        return _otpDialog(
          title: 'Verify Email',
          subtitle: 'Enter the 6-digit verification code sent to your email.',
          controller: controller,
        );
      },
    );

    controller.dispose();

    if (otp == null || otp.isEmpty) return;

    try {
      final result = await WalletService.verifyEmail(
        token: widget.token,
        otpCode: otp,
      );

      if (!mounted) return;

      if (result['status']?.toString().toLowerCase() == 'success') {
        _showSuccess(
          result['message']?.toString() ?? 'Email verified successfully.',
        );

        _loadSecurityEvents();
      } else {
        _showError(
          result['message']?.toString() ?? 'Invalid verification code.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showError('Unable to verify email. Please try again.');
    }
  }

  // ============================================================
  // PHONE VERIFICATION
  // ============================================================

  Future<void> _openPhoneVerification() async {
    final controller = TextEditingController();

    final otp = await showDialog<String>(
      context: context,
      builder: (context) {
        return _otpDialog(
          title: 'Verify Phone',
          subtitle: 'Enter the 6-digit verification code for your phone.',
          controller: controller,
        );
      },
    );

    controller.dispose();

    if (otp == null || otp.isEmpty) return;

    try {
      final result = await WalletService.verifyPhone(
        token: widget.token,
        otpCode: otp,
      );

      if (!mounted) return;

      final message =
          result['message']?.toString() ?? 'Phone verification completed.';

      if (result['status']?.toString().toLowerCase() == 'success') {
        _showSuccess(message);
        _loadSecurityEvents();
      } else {
        _showError(message);
      }
    } catch (e) {
      if (!mounted) return;

      _showError('Unable to verify phone. Please try again.');
    }
  }

  // ============================================================
  // 2FA
  // ============================================================

  Future<void> _toggleTwoFactor(bool value) async {
    if (_isUpdating2FA) return;

    setState(() {
      _isUpdating2FA = true;
    });

    try {
      final response = await WalletService.toggleTwoFactor(
        token: widget.token,
        enable: value,
      );

      if (!mounted) return;

      if (response['status'] == 'success') {
        setState(() {
          _twoFactorEnabled = response['two_factor_enabled'] == true;
        });

        _showSuccess(
          response['message'] ??
              (value
                  ? '2FA enabled successfully.'
                  : '2FA disabled successfully.'),
        );

        _loadSecurityEvents();
      } else {
        _showError(response['message'] ?? 'Unable to update 2FA settings.');
      }
    } catch (e) {
      if (!mounted) return;

      _showError('Something went wrong while updating 2FA.');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating2FA = false;
        });
      }
    }
  }

  // ============================================================
  // OTP DIALOG
  // ============================================================

  Widget _otpDialog({
    required String title,
    required String subtitle,
    required TextEditingController controller,
  }) {
    return Dialog(
      backgroundColor: AppColors.adaptiveSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppColors.themeText,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 8),

            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.themeText.withOpacity(0.55),
                fontSize: 13,
                height: 1.4,
              ),
            ),

            SizedBox(height: 22),

            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: TextStyle(
                color: AppColors.themeText,
                fontSize: 20,
                letterSpacing: 6,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                hintText: '000000',
                hintStyle: TextStyle(
                  color: AppColors.themeText.withOpacity(0.2),
                  letterSpacing: 6,
                ),
                filled: true,
                fillColor: AppColors.themeText.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.themeText.withOpacity(0.6)),
                    ),
                  ),
                ),

                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final value = controller.text.trim();

                      if (value.length != 6) return;

                      Navigator.pop(context, value);
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
                      'Verify',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SECURITY ITEM
  // ============================================================

  Widget _securityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
    bool highlighted = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: highlighted
              ? AppColors.royalBlue.withOpacity(0.09)
              : AppColors.themeText.withOpacity(0.045),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: highlighted
                ? AppColors.royalBlue.withOpacity(0.18)
                : AppColors.themeText.withOpacity(0.07),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 47,
              height: 47,
              decoration: BoxDecoration(
                color: AppColors.royalBlue.withOpacity(0.13),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.royalBlue, size: 22),
            ),

            SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.themeText,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  SizedBox(height: 5),

                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.themeText.withOpacity(0.48),
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(width: 10),

            trailing,
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _statusBadge({required String text, required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? Colors.green.withOpacity(0.12)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: active ? Colors.greenAccent : Colors.orangeAccent,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================================
  // SECURITY ALERTS SECTION
  // US-048
  // ============================================================

  Widget _buildSecurityAlertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'SECURITY ALERTS',
                style: TextStyle(
                  color: AppColors.themeText.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            GestureDetector(
              onTap: _isLoadingSecurityEvents ? null : _loadSecurityEvents,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.themeText.withOpacity(0.045),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.themeText.withOpacity(0.07)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      color: AppColors.themeText.withValues(alpha: 0.54),
                      size: 14,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Refresh',
                      style: TextStyle(
                        color: AppColors.themeText.withOpacity(0.55),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.themeText.withOpacity(0.035),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.themeText.withOpacity(0.07)),
          ),
          child: _isLoadingSecurityEvents
              ? _buildSecurityEventsLoading()
              : _securityEvents.isEmpty
              ? _buildEmptySecurityEvents()
              : Column(
                  children: _securityEvents
                      .take(10)
                      .map((event) => _buildSecurityEventTile(event))
                      .toList(),
                ),
        ),
      ],
    );
  }

  // ============================================================
  // SECURITY EVENTS LOADING
  // ============================================================

  Widget _buildSecurityEventsLoading() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.royalBlue,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Loading security alerts...',
              style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.38), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY SECURITY EVENTS
  // ============================================================

  Widget _buildEmptySecurityEvents() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(Icons.shield_outlined, color: AppColors.themeText.withValues(alpha: 0.38), size: 32),

          SizedBox(height: 10),

          Text(
            'No security alerts',
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),

          SizedBox(height: 5),

          Text(
            'Your account has no recent security events.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.38), fontSize: 10, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECURITY EVENT TILE
  // ============================================================

  Widget _buildSecurityEventTile(Map<String, dynamic> event) {
    final severity = (event['severity'] ?? 'info').toString().toLowerCase();

    final eventType = (event['event_type'] ?? 'security_event').toString();

    final title = (event['title'] ?? 'Security Event').toString();

    final description = (event['description'] ?? '').toString();

    final occurredAt = (event['occurred_at'] ?? '').toString();

    IconData icon;

    switch (eventType) {
      case 'login_success':
        icon = Icons.login_rounded;
        break;

      case 'login_failed':
        icon = Icons.warning_amber_rounded;
        break;

      case 'logout':
        icon = Icons.logout_rounded;
        break;

      case 'pin_created':
      case 'pin_changed':
      case 'pin_verified':
        icon = Icons.pin_rounded;
        break;

      case 'pin_failed':
        icon = Icons.key_off_rounded;
        break;

      case 'two_factor_enabled':
        icon = Icons.verified_user_rounded;
        break;

      case 'two_factor_disabled':
        icon = Icons.shield_outlined;
        break;

      case 'password_reset_requested':
        icon = Icons.lock_reset_rounded;
        break;

      case 'password_reset_failed':
        icon = Icons.lock_outline_rounded;
        break;

      case 'password_reset_success':
        icon = Icons.lock_open_rounded;
        break;

      case 'suspicious_activity':
        icon = Icons.gpp_maybe_rounded;
        break;

      case 'fraud_detected':
        icon = Icons.report_problem_rounded;
        break;

      case 'security_alert':
        icon = Icons.notifications_active_rounded;
        break;

      default:
        icon = Icons.shield_rounded;
    }

    final Color iconColor;

    if (severity == 'danger' || severity == 'critical') {
      iconColor = Colors.redAccent;
    } else if (severity == 'warning') {
      iconColor = Colors.orangeAccent;
    } else {
      iconColor = AppColors.royalBlue;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.themeText.withOpacity(0.025),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.themeText.withOpacity(0.05)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 19),
            ),

            SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: AppColors.themeText,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),

                      SizedBox(width: 8),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          severity.toUpperCase(),
                          style: TextStyle(
                            color: iconColor,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (description.isNotEmpty) ...[
                    SizedBox(height: 5),
                    Text(
                      description,
                      style: TextStyle(
                        color: AppColors.themeText.withValues(alpha: 0.38),
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                  ],

                  if (occurredAt.isNotEmpty) ...[
                    SizedBox(height: 6),
                    Text(
                      _formatSecurityEventDate(occurredAt),
                      style: TextStyle(
                        color: AppColors.themeText.withValues(alpha: 0.24),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FORMAT SECURITY EVENT DATE
  // ============================================================

  String _formatSecurityEventDate(String value) {
    try {
      final date = DateTime.parse(value).toLocal();

      String twoDigits(int number) {
        return number.toString().padLeft(2, '0');
      }

      return '${date.day}/${date.month}/${date.year} '
          '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
    } catch (_) {
      return value;
    }
  }

  // ============================================================
  // SUCCESS
  // ============================================================

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    AppColors.dependOnTheme(context);
    final biometricTitle = _hasFaceId
        ? 'Face ID'
        : _hasFingerprint
        ? 'Fingerprint'
        : 'Biometric Authentication';

    final biometricSubtitle = !_biometricAvailable
        ? 'Biometric authentication is not available on this device.'
        : _biometricEnabled
        ? '$biometricTitle is enabled for secure payments.'
        : 'Use $biometricTitle to verify sensitive transactions.';

    return Scaffold(
      backgroundColor: AppColors.adaptiveSurfaceAlt,

      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.themeText),
        title: Text(
          'Security Center',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 35),
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
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.royalBlue.withOpacity(0.18),
                      AppColors.neonPink.withOpacity(0.08),
                      AppColors.themeText.withOpacity(0.035),
                    ],
                  ),
                  border: Border.all(color: AppColors.themeText.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.royalBlue.withOpacity(0.14),
                      ),
                      child: Icon(
                        Icons.shield_rounded,
                        color: AppColors.royalBlue,
                        size: 30,
                      ),
                    ),

                    SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Protect your account',
                            style: TextStyle(
                              color: AppColors.themeText,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 5),

                          Text(
                            'Manage authentication and transaction security for your NaNa Wallet.',
                            style: TextStyle(
                              color: AppColors.themeText.withOpacity(0.55),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 28),

              // ==================================================
              // VERIFICATION
              // ==================================================
              Text(
                'VERIFICATION',
                style: TextStyle(
                  color: AppColors.themeText.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),

              SizedBox(height: 12),

              _securityItem(
                icon: Icons.email_outlined,
                title: 'Email Verification',
                subtitle: 'Verify your email address with a 6-digit OTP.',
                trailing: _statusBadge(text: 'VERIFY', active: false),
                onTap: _openEmailVerification,
              ),

              _securityItem(
                icon: Icons.phone_outlined,
                title: 'Phone Verification',
                subtitle: 'Verify your Cambodian phone number.',
                trailing: _statusBadge(text: 'VERIFY', active: false),
                onTap: _openPhoneVerification,
              ),

              SizedBox(height: 14),

              // ==================================================
              // TRANSACTION SECURITY
              // ==================================================
              Text(
                'TRANSACTION SECURITY',
                style: TextStyle(
                  color: AppColors.themeText.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),

              SizedBox(height: 12),

              _securityItem(
                icon: Icons.pin_rounded,
                title: 'Transaction PIN',
                subtitle: _isLoadingPin
                    ? 'Checking your PIN security status...'
                    : _hasTransactionPin
                    ? 'Your 4-digit PIN is active. Tap to change it.'
                    : 'Set up a 4-digit PIN to protect transactions.',
                trailing: _isLoadingPin
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.royalBlue,
                        ),
                      )
                    : _statusBadge(
                        text: _hasTransactionPin ? 'ACTIVE' : 'SET UP',
                        active: _hasTransactionPin,
                      ),
                onTap: _openTransactionPin,
                highlighted: true,
              ),

              SizedBox(height: 14),

              // ==================================================
              // BIOMETRIC SECURITY
              // ==================================================
              Text(
                'BIOMETRIC SECURITY',
                style: TextStyle(
                  color: AppColors.themeText.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),

              SizedBox(height: 12),

              _securityItem(
                icon: _hasFaceId
                    ? Icons.face_rounded
                    : Icons.fingerprint_rounded,
                title: biometricTitle,
                subtitle: biometricSubtitle,
                trailing: _isLoadingBiometric
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.royalBlue,
                        ),
                      )
                    : _statusBadge(
                        text: _biometricEnabled
                            ? 'ACTIVE'
                            : _biometricAvailable
                            ? 'ENABLE'
                            : 'UNAVAILABLE',
                        active: _biometricEnabled,
                      ),
                onTap: _biometricAvailable ? _setupBiometric : null,
                highlighted: _biometricEnabled,
              ),

              SizedBox(height: 14),

              // ==================================================
              // ADVANCED SECURITY
              // ==================================================
              Text(
                'ADVANCED SECURITY',
                style: TextStyle(
                  color: AppColors.themeText.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),

              SizedBox(height: 12),

              _securityItem(
                icon: Icons.phonelink_lock_rounded,
                title: 'Two-Factor Authentication',
                subtitle:
                    'Add an additional authentication layer to your account.',
                trailing: Switch(
                  value: _twoFactorEnabled,
                  onChanged: _isUpdating2FA ? null : _toggleTwoFactor,
                  activeColor: AppColors.royalBlue,
                ),
              ),

              SizedBox(height: 8),

              // ==================================================
              // SECURITY ALERTS
              // US-048
              // ==================================================
              _buildSecurityAlertsSection(),

              SizedBox(height: 20),

              // ==================================================
              // SECURITY INFO
              // ==================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: Colors.green.withOpacity(0.13)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      color: Colors.greenAccent,
                      size: 23,
                    ),

                    SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        'NaNa Wallet uses secure authentication, transaction PIN protection, and biometric verification to help protect sensitive transactions.',
                        style: TextStyle(
                          color: AppColors.themeText.withOpacity(0.6),
                          fontSize: 11.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 15),

              // ==================================================
              // FOOTER
              // ==================================================
              Center(
                child: Text(
                  'NaNa Wallet • Group 8',
                  style: TextStyle(
                    color: AppColors.themeText.withOpacity(0.25),
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
