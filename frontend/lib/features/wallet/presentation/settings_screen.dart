import 'package:flutter/material.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/core/theme/app_theme_controller.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';
import 'package:digital_wallet_app/features/wallet/presentation/login_notifications_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/transaction_notifications_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/security_notifications_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/device_management_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/session_management_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/audit_log_screen.dart';
import 'package:digital_wallet_app/features/wallet/presentation/activity_history_screen.dart';

class SettingsScreen extends StatefulWidget {
  SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _token = '';

  bool _hasTransactionPin = false;
  bool _isCheckingPinStatus = false;
  bool _isLoggingOut = false;

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_token.isEmpty) {
      final arguments = ModalRoute.of(context)?.settings.arguments;

      if (arguments is String) {
        _token = arguments.trim();

        if (_token.isNotEmpty) {
          _loadTransactionPinStatus();
        }
      }
    }
  }

  // ============================================================
  // TRANSACTION PIN STATUS
  // ============================================================

  Future<void> _loadTransactionPinStatus() async {
    if (_token.isEmpty || _isCheckingPinStatus) {
      return;
    }

    setState(() {
      _isCheckingPinStatus = true;
    });

    try {
      final result = await WalletService.getTransactionPinStatus(token: _token);

      if (!mounted) return;

      final status = result['status']?.toString().toLowerCase();

      if (status == 'success') {
        setState(() {
          _hasTransactionPin = result['has_transaction_pin'] == true;
          _isCheckingPinStatus = false;
        });
      } else {
        setState(() {
          _isCheckingPinStatus = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load transaction PIN status: $e');

      if (!mounted) return;

      setState(() {
        _isCheckingPinStatus = false;
      });
    }
  }

  // ============================================================
  // TRANSACTION PIN
  // ============================================================

  Future<void> _openTransactionPin() async {
    if (_token.isEmpty) {
      _showError('Authentication token is missing. Please login again.');
      return;
    }

    if (_isCheckingPinStatus) {
      return;
    }

    if (_hasTransactionPin) {
      final result = await Navigator.pushNamed(
        context,
        '/transaction-pin-change',
        arguments: _token,
      );

      if (result == true && mounted) {
        _loadTransactionPinStatus();
      }

      return;
    }

    final result = await Navigator.pushNamed(
      context,
      '/transaction-pin-setup',
      arguments: _token,
    );

    if (result == true && mounted) {
      _loadTransactionPinStatus();
    }
  }

  // ============================================================
  // PASSWORD
  // ============================================================

  Future<void> _openPassword() async {
    if (_token.isEmpty) {
      _showError('Authentication token is missing. Please login again.');
      return;
    }

    await Navigator.pushNamed(context, '/change-password', arguments: _token);
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Future<void> _openProfile() async {
    if (_token.isEmpty) {
      _showError('Authentication token is missing. Please login again.');
      return;
    }

    await Navigator.pushNamed(context, '/profile', arguments: _token);
  }

  // ============================================================
  // SECURITY
  // ============================================================

  Future<void> _openSecurity() async {
    if (_token.isEmpty) {
      _showError('Authentication token is missing. Please login again.');
      return;
    }

    await Navigator.pushNamed(context, '/security', arguments: _token);
  }

  // ============================================================
  // LOGIN NOTIFICATIONS
  // US-049 Login Notification
  // ============================================================

  Future<void> _openLoginNotifications() async {
    if (_token.isEmpty) {
      _showError('Authentication token is missing. Please login again.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginNotificationsScreen(token: _token),
      ),
    );
  }

  // ============================================================
  // TRANSACTION NOTIFICATIONS
  // US-050 Transaction Notification
  // ============================================================

  Future<void> _openTransactionNotifications() async {
    if (_token.isEmpty) {
      _showError('Authentication token is missing. Please login again.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionNotificationsScreen(token: _token),
      ),
    );
  }

  // ============================================================
  // SECURITY NOTIFICATIONS
  // US-052 Suspicious Activity Alert
  // ============================================================

  Future<void> _openSecurityNotifications() async {
    if (_token.isEmpty) {
      _showError('Authentication token is missing. Please login again.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SecurityNotificationsScreen(activeToken: _token),
      ),
    );
  }

  // ============================================================
  // DEVICE MANAGEMENT
  // US-053 Device Management
  // ============================================================

  Future<void> _openDeviceManagement() async {
    if (_token.isEmpty) {
      _showError('Authentication token is missing. Please login again.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceManagementScreen(activeToken: _token),
      ),
    );
  }

  // ============================================================
  // SESSION MANAGEMENT
  // US-054 Session Management
  // ============================================================

  Future<void> _openSessionManagement() async {
    if (_token.isEmpty) {
      _showError('Authentication token is missing. Please login again.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionManagementScreen(activeToken: _token),
      ),
    );
  }

  // ============================================================
  // AUDIT LOG
  // US-055 Audit Log
  // ============================================================

  Future<void> _openAuditLog() async {
    if (_token.isEmpty) {
      _showError('Authentication token is missing. Please login again.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AuditLogScreen(activeToken: _token)),
    );
  }

  // ============================================================
  // ACTIVITY HISTORY
  // US-056 Activity History
  // ============================================================

  Future<void> _openActivityHistory() async {
    if (_token.isEmpty) {
      _showError('Authentication token is missing. Please login again.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityHistoryScreen(activeToken: _token),
      ),
    );
  }
  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    if (_token.trim().isEmpty) {
      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);

      return;
    }

    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.adaptiveSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          actionsPadding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          title: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.logout_rounded,
                  color: Colors.redAccent,
                  size: 23,
                ),
              ),
              SizedBox(width: 13),
              Expanded(
                child: Text(
                  'Log Out',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to log out of your NaNa Wallet account?',
            style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.70), fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.themeText.withValues(alpha: 0.60),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: AppColors.themeText,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Text(
                'Log Out',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await WalletService.logout(token: _token.trim());
    } catch (_) {
      // Continue local logout even if server request fails.
    }

    if (!mounted) return;

    _token = '';

    setState(() {
      _isLoggingOut = false;
    });

    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  // ============================================================
  // ERROR MESSAGE
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
  // SUCCESS MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.royalBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ============================================================
  // SETTINGS ITEM
  // ============================================================

  Widget _settingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: highlighted
              ? colors.primary.withValues(alpha: 0.10)
              : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: highlighted
                ? colors.primary.withValues(alpha: 0.25)
                : colors.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: highlighted
                    ? colors.primary.withValues(alpha: 0.15)
                    : colors.surfaceContainerHighest,
              ),
              child: Icon(
                icon,
                color: highlighted ? colors.primary : colors.onSurfaceVariant,
                size: 25,
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
                      color: colors.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.onSurfaceVariant,
              size: 25,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOGOUT ITEM
  // ============================================================

  Widget _logoutItem() {
    return GestureDetector(
      onTap: _isLoggingOut ? null : _logout,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _isLoggingOut
                  ? Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.redAccent,
                      ),
                    )
                  : Icon(
                      Icons.logout_rounded,
                      color: Colors.redAccent,
                      size: 25,
                    ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isLoggingOut ? 'Logging Out...' : 'Log Out',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    _isLoggingOut
                        ? 'Please wait while we securely sign you out.'
                        : 'Sign out of your NaNa Wallet account.',
                    style: TextStyle(
                      color: AppColors.themeText.withValues(alpha: 0.54),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (!_isLoggingOut)
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.redAccent,
                size: 25,
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(String title) {
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Text(
      title,
      style: TextStyle(
        color: textColor,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 21,
          ),
        ),
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 35),
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
                      AppColors.royalBlue.withValues(alpha: 0.22),
                      AppColors.neonPink.withValues(alpha: 0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.themeText.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.royalBlue, AppColors.neonPink],
                        ),
                      ),
                      child: Icon(
                        Icons.settings_rounded,
                        color: AppColors.themeText,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account & Security',
                            style: TextStyle(
                              color: AppColors.themeText,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Manage your NaNa Wallet account and security.',
                            style: TextStyle(
                              color: AppColors.themeText.withValues(alpha: 0.60),
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

              SizedBox(height: 30),

              // ==================================================
              // ACCOUNT
              // ==================================================
              _sectionTitle('ACCOUNT'),

              SizedBox(height: 12),

              _settingsItem(
                icon: Icons.person_outline_rounded,
                title: 'My Profile',
                subtitle: 'View and manage your personal information.',
                onTap: _openProfile,
              ),

              SizedBox(height: 14),

              _sectionTitle('APPEARANCE'),

              SizedBox(height: 12),

              AnimatedBuilder(
                animation: AppThemeController.instance,
                builder: (context, _) {
                  final isDark = AppThemeController.instance.isDark;
                  final colors = Theme.of(context).colorScheme;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                    child: SwitchListTile.adaptive(
                      value: isDark,
                      onChanged: AppThemeController.instance.setDarkMode,
                      secondary: Icon(
                        isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                        color: colors.primary,
                      ),
                      title: Text(
                        isDark ? 'Dark mode' : 'Bright mode',
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'Use ${isDark ? 'a dark' : 'a bright'} appearance throughout the app.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      activeColor: colors.primary,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                },
              ),

              // ==================================================
              // SECURITY
              // ==================================================
              _sectionTitle('SECURITY'),

              SizedBox(height: 12),

              // TRANSACTION PIN
              _settingsItem(
                icon: Icons.pin_outlined,
                title: 'Transaction PIN',
                subtitle: _isCheckingPinStatus
                    ? 'Checking PIN security status...'
                    : _hasTransactionPin
                    ? 'Change your 4-digit transaction PIN.'
                    : 'Set up your 4-digit transaction PIN.',
                onTap: _openTransactionPin,
                highlighted: true,
              ),

              // PASSWORD
              _settingsItem(
                icon: Icons.lock_outline_rounded,
                title: 'Password',
                subtitle: 'Change your account login password.',
                onTap: _openPassword,
              ),

              // SECURITY SETTINGS
              _settingsItem(
                icon: Icons.security_outlined,
                title: 'Security',
                subtitle: 'Manage additional account security settings.',
                onTap: _openSecurity,
              ),

              // LOGIN NOTIFICATIONS
              _settingsItem(
                icon: Icons.notifications_none_rounded,
                title: 'Login Notifications',
                subtitle: 'View your recent login activity and alerts.',
                onTap: _openLoginNotifications,
              ),

              // TRANSACTION NOTIFICATIONS
              _settingsItem(
                icon: Icons.receipt_long_rounded,
                title: 'Transaction Notifications',
                subtitle: 'View your recent transaction activity and alerts.',
                onTap: _openTransactionNotifications,
              ),

              // SECURITY ALERTS
              _settingsItem(
                icon: Icons.gpp_maybe_outlined,
                title: 'Security Alerts',
                subtitle: 'View suspicious activity and fraud security alerts.',
                onTap: _openSecurityNotifications,
              ),

              // DEVICE MANAGEMENT
              _settingsItem(
                icon: Icons.devices_other_outlined,
                title: 'Device Management',
                subtitle: 'View and manage devices signed in to your account.',
                onTap: _openDeviceManagement,
              ),

              // SESSION MANAGEMENT
              _settingsItem(
                icon: Icons.manage_accounts_outlined,
                title: 'Session Management',
                subtitle: 'View and manage active login sessions.',
                onTap: _openSessionManagement,
              ),

              // AUDIT LOG
              _settingsItem(
                icon: Icons.history_rounded,
                title: 'Audit Log',
                subtitle: 'Review your account and security activity.',
                onTap: _openAuditLog,
              ),

              // ACTIVITY HISTORY
              _settingsItem(
                icon: Icons.receipt_long_rounded,
                title: 'Activity History',
                subtitle: 'Review your wallet transactions and activity.',
                onTap: _openActivityHistory,
              ),

              SizedBox(height: 20),
              // ==================================================
              // TRANSACTION SECURITY INFO
              // ==================================================
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.verified_user_outlined,
                        color: Colors.greenAccent,
                        size: 21,
                      ),
                    ),
                    SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transaction Security',
                            style: TextStyle(
                              color: AppColors.themeText,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Your transaction PIN helps protect sensitive wallet operations such as withdrawals, transfers, and deposits.',
                            style: TextStyle(
                              color: AppColors.themeText.withValues(alpha: 0.54),
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 25),

              // ==================================================
              // ACCOUNT ACTION
              // ==================================================
              _sectionTitle('ACCOUNT ACTION'),

              SizedBox(height: 12),

              _logoutItem(),

              SizedBox(height: 25),

              // ==================================================
              // APP INFO
              // ==================================================
              Center(
                child: Column(
                  children: [
                    Text(
                      'NaNa Wallet',
                      style: TextStyle(
                        color: AppColors.themeText.withValues(alpha: 0.38),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Group 8 • Digital Wallet',
                      style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.24), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
