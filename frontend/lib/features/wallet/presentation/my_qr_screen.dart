import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';

class MyQrScreen extends StatefulWidget {
  MyQrScreen({super.key, required this.token});

  final String token;

  @override
  State<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends State<MyQrScreen> {
  bool _isLoading = true;
  bool _isSharing = false;

  String _userName = 'User';
  String _userId = '';
  String _email = '';

  String _qrData = '';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // ==========================================================
  // LOAD USER PROFILE
  // ==========================================================

  Future<void> _loadUserProfile() async {
    if (widget.token.trim().isEmpty) {
      _showError('Authentication token is missing.');
      return;
    }

    try {
      debugPrint('📱 Loading profile for My QR...');

      final result = await WalletService.fetchProfile(token: widget.token);

      if (!mounted) return;

      if (result['status'] != 'success') {
        setState(() {
          _isLoading = false;
        });

        _showError(
          result['message']?.toString() ?? 'Unable to load your profile.',
        );

        return;
      }

      final user = result['user'];

      if (user is! Map<String, dynamic>) {
        setState(() {
          _isLoading = false;
        });

        _showError('Invalid user information received.');
        return;
      }

      final id = user['id']?.toString() ?? '';
      final name = user['name']?.toString() ?? 'User';
      final email = user['email']?.toString() ?? '';

      if (id.isEmpty) {
        setState(() {
          _isLoading = false;
        });

        _showError('Unable to identify your wallet account.');
        return;
      }

      // ========================================================
      // NANA QR PAYMENT PAYLOAD
      // ========================================================

      final qrPayload =
          'nana://pay?user_id=$id&name=${Uri.encodeComponent(name)}';

      setState(() {
        _userId = id;
        _userName = name;
        _email = email;
        _qrData = qrPayload;
        _isLoading = false;
      });

      debugPrint('✅ My QR generated');
      debugPrint('👤 User ID: $_userId');
      debugPrint('🔗 QR Payload: $_qrData');
    } catch (e) {
      debugPrint('❌ My QR loading error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError('Unable to load your QR code.');
    }
  }

  // ==========================================================
  // SHARE
  // ==========================================================

  Future<void> _shareQr() async {
    if (_qrData.isEmpty) {
      _showError('QR code is not ready yet.');
      return;
    }

    setState(() {
      _isSharing = true;
    });

    await Future.delayed(Duration(milliseconds: 500));

    if (!mounted) return;

    setState(() {
      _isSharing = false;
    });

    _showInfo('QR sharing will be connected to the sharing service next.');
  }

  // ==========================================================
  // COPY ACCOUNT ID
  // ==========================================================

  void _copyAccountId() {
    // Clipboard integration can be added next.
    _showInfo('Account ID: $_userId');
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
      ),
    );
  }

  // ==========================================================
  // INFO
  // ==========================================================

  void _showInfo(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.royalBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================================
  // UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    AppColors.dependOnTheme(context);
    return Scaffold(
      backgroundColor: AppColors.adaptiveSurfaceAlt,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,

        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(LucideIcons.arrowLeft, color: AppColors.themeText),
        ),

        title: Text(
          'MY QR',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),

      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.neonPink),
            )
          : RefreshIndicator(
              color: AppColors.neonPink,
              backgroundColor: AppColors.adaptiveSurface,
              onRefresh: _loadUserProfile,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 35),
                child: Column(
                  children: [
                    // ==================================================
                    // HEADER
                    // ==================================================
                    Text(
                      'Receive Money',
                      style: TextStyle(
                        color: AppColors.themeText,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 8),

                    Text(
                      'Let someone scan your QR code\nto send money to your NaNa Wallet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.themeText.withValues(alpha: 0.54),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),

                    SizedBox(height: 30),

                    // ==================================================
                    // QR CARD
                    // ==================================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.adaptiveSurface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: AppColors.themeText.withOpacity(0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.royalBlue.withOpacity(0.12),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // ------------------------------------------------
                          // PROFILE
                          // ------------------------------------------------
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.royalBlue,
                                  AppColors.neonPink,
                                ],
                              ),
                            ),
                            child: Icon(
                              LucideIcons.user,
                              color: AppColors.themeText,
                              size: 27,
                            ),
                          ),

                          SizedBox(height: 12),

                          Text(
                            _userName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.themeText,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 4),

                          Text(
                            _email,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.themeText.withValues(alpha: 0.38),
                              fontSize: 11,
                            ),
                          ),

                          SizedBox(height: 25),

                          // ------------------------------------------------
                          // QR CODE
                          // ------------------------------------------------
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.themeText,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: QrImageView(
                              data: _qrData,
                              version: QrVersions.auto,
                              size: 230,
                              backgroundColor: AppColors.themeText,
                              eyeStyle: QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Colors.black,
                              ),
                              dataModuleStyle: QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Colors.black,
                              ),
                            ),
                          ),

                          SizedBox(height: 22),

                          // ------------------------------------------------
                          // NANA BRAND
                          // ------------------------------------------------
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: AppColors.royalBlue,
                                  shape: BoxShape.circle,
                                ),
                              ),

                              SizedBox(width: 7),

                              Text(
                                'NaNa Wallet',
                                style: TextStyle(
                                  color: AppColors.themeText.withValues(alpha: 0.70),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),

                              SizedBox(width: 7),

                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: AppColors.neonPink,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 22),

                    // ==================================================
                    // ACCOUNT INFORMATION
                    // ==================================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.adaptiveSurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.themeText.withOpacity(0.05),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: AppColors.royalBlue.withOpacity(0.10),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  LucideIcons.badge,
                                  color: AppColors.royalBlue,
                                  size: 18,
                                ),
                              ),

                              SizedBox(width: 12),

                              Expanded(
                                child: Text(
                                  'NaNa Account ID',
                                  style: TextStyle(
                                    color: AppColors.themeText.withValues(alpha: 0.54),
                                    fontSize: 12,
                                  ),
                                ),
                              ),

                              Text(
                                '#$_userId',
                                style: TextStyle(
                                  color: AppColors.themeText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              SizedBox(width: 6),

                              IconButton(
                                onPressed: _copyAccountId,
                                icon: Icon(
                                  LucideIcons.copy,
                                  color: AppColors.themeText.withValues(alpha: 0.54),
                                  size: 17,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 18),

                    // ==================================================
                    // ACTION BUTTONS
                    // ==================================================
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: LucideIcons.share2,
                            title: 'Share QR',
                            loading: _isSharing,
                            onTap: _shareQr,
                          ),
                        ),

                        SizedBox(width: 12),

                        Expanded(
                          child: _buildActionButton(
                            icon: LucideIcons.download,
                            title: 'Save QR',
                            loading: false,
                            onTap: () {
                              _showInfo('QR saving will be connected next.');
                            },
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 22),

                    // ==================================================
                    // SECURITY MESSAGE
                    // ==================================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.royalBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.royalBlue.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            LucideIcons.shieldCheck,
                            color: AppColors.royalBlue,
                            size: 20,
                          ),

                          SizedBox(width: 12),

                          Expanded(
                            child: Text(
                              'Only share this QR code with people you trust. '
                              'Never share your transaction PIN.',
                              style: TextStyle(
                                color: AppColors.themeText.withValues(alpha: 0.60),
                                fontSize: 11,
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
    );
  }

  // ==========================================================
  // ACTION BUTTON
  // ==========================================================

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.adaptiveSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.themeText.withOpacity(0.06)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.neonPink,
                  ),
                )
              else
                Icon(icon, color: AppColors.neonPink, size: 18),

              SizedBox(width: 8),

              Text(
                title,
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
