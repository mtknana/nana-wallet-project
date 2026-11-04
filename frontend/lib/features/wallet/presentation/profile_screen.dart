import 'package:flutter/material.dart';
import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';

class ProfileScreen extends StatefulWidget {
  final String token;

  ProfileScreen({super.key, required this.token});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _wallet;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (widget.token.trim().isEmpty) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError('Authentication token is missing. Please login again.');

      return;
    }

    try {
      final result = await WalletService.fetchProfile(token: widget.token);

      if (!mounted) return;

      if (result['status']?.toString().toLowerCase() == 'success') {
        setState(() {
          _user = result['user'] is Map
              ? Map<String, dynamic>.from(result['user'])
              : null;

          _wallet = result['wallet'] is Map
              ? Map<String, dynamic>.from(result['wallet'])
              : null;

          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });

        _showError(
          result['message']?.toString() ?? 'Unable to load your profile.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError('Unable to load profile. Please try again.');
    }
  }

  String _userName() {
    return _user?['name']?.toString() ?? 'NaNa User';
  }

  String _email() {
    return _user?['email']?.toString() ?? 'Not provided';
  }

  String _phone() {
    final phone = _user?['phone_number']?.toString();

    if (phone == null || phone.isEmpty) {
      return 'Not provided';
    }

    return phone;
  }

  String _role() {
    final role = _user?['role']?.toString();

    if (role == null || role.isEmpty) {
      return 'User';
    }

    return role[0].toUpperCase() + role.substring(1);
  }

  String _walletBalance() {
    final balance = _wallet?['balance'];

    if (balance == null) {
      return '0.00';
    }

    final value = double.tryParse(balance.toString());

    if (value == null) {
      return '0.00';
    }

    return value.toStringAsFixed(2);
  }

  String _walletCurrency() {
    return _wallet?['currency']?.toString() ?? 'USD';
  }

  String _walletStatus() {
    return _wallet?['status']?.toString() ?? 'active';
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.themeText.withOpacity(0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.themeText.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.royalBlue.withOpacity(0.15),
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
                    color: AppColors.themeText.withOpacity(0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        iconTheme: IconThemeData(color: AppColors.themeText),
        title: Text(
          'My Profile',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: AppColors.royalBlue),
              )
            : RefreshIndicator(
                color: AppColors.royalBlue,
                onRefresh: _loadProfile,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 35),
                  child: Column(
                    children: [
                      SizedBox(height: 10),

                      // PROFILE HEADER
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.royalBlue.withOpacity(0.22),
                              AppColors.neonPink.withOpacity(0.12),
                              AppColors.themeText.withOpacity(0.035),
                            ],
                          ),
                          border: Border.all(
                            color: AppColors.themeText.withOpacity(0.08),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.royalBlue,
                                    AppColors.neonPink,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.royalBlue.withOpacity(0.3),
                                    blurRadius: 22,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.person_rounded,
                                size: 46,
                                color: AppColors.themeText,
                              ),
                            ),

                            SizedBox(height: 16),

                            Text(
                              _userName(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.themeText,
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 6),

                            Text(
                              _email(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.themeText.withOpacity(0.6),
                                fontSize: 14,
                              ),
                            ),

                            SizedBox(height: 14),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.themeText.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_user_rounded,
                                    color: AppColors.royalBlue,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    _role(),
                                    style: TextStyle(
                                      color: AppColors.themeText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 28),

                      // ACCOUNT INFORMATION
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'ACCOUNT INFORMATION',
                          style: TextStyle(
                            color: AppColors.themeText.withOpacity(0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),

                      SizedBox(height: 12),

                      _infoCard(
                        icon: Icons.person_outline_rounded,
                        title: 'Full Name',
                        value: _userName(),
                      ),

                      _infoCard(
                        icon: Icons.email_outlined,
                        title: 'Email Address',
                        value: _email(),
                      ),

                      _infoCard(
                        icon: Icons.phone_outlined,
                        title: 'Phone Number',
                        value: _phone(),
                      ),

                      SizedBox(height: 14),

                      // WALLET INFORMATION
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'WALLET INFORMATION',
                          style: TextStyle(
                            color: AppColors.themeText.withOpacity(0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),

                      SizedBox(height: 12),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.royalBlue.withOpacity(0.18),
                              AppColors.themeText.withOpacity(0.04),
                            ],
                          ),
                          border: Border.all(
                            color: AppColors.royalBlue.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 45,
                                  height: 45,
                                  decoration: BoxDecoration(
                                    color: AppColors.royalBlue.withOpacity(
                                      0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: AppColors.royalBlue,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'NaNa Wallet',
                                    style: TextStyle(
                                      color: AppColors.themeText,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _walletStatus().toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 22),

                            Text(
                              'Available Balance',
                              style: TextStyle(
                                color: AppColors.themeText.withOpacity(0.55),
                                fontSize: 12,
                              ),
                            ),

                            SizedBox(height: 6),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _walletBalance(),
                                  style: TextStyle(
                                    color: AppColors.themeText,
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 7),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 5),
                                  child: Text(
                                    _walletCurrency(),
                                    style: TextStyle(
                                      color: AppColors.themeText.withOpacity(0.55),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 25),

                      // SECURITY NOTE
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(17),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.14),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              color: Colors.greenAccent,
                              size: 23,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Your account information is securely '
                                'protected by NaNa Wallet.',
                                style: TextStyle(
                                  color: AppColors.themeText.withOpacity(0.65),
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
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
