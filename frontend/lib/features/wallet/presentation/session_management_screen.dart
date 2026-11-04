import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/core/config/api_config.dart';

class SessionManagementScreen extends StatefulWidget {
  final String activeToken;

  SessionManagementScreen({super.key, required this.activeToken});

  @override
  State<SessionManagementScreen> createState() =>
      _SessionManagementScreenState();
}

class _SessionManagementScreenState extends State<SessionManagementScreen> {
  // ============================================================
  // API
  // ============================================================

  static const String _baseUrl = ApiConfig.baseUrl;

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = true;
  bool _isRevokingAll = false;

  String? _errorMessage;

  List<WalletSession> _sessions = [];

  // ============================================================
  // COLORS
  // ============================================================

  static Color get _background => AppColors.adaptiveSurfaceAlt;

  static Color get _cardColor => AppColors.adaptiveSurface;

  static Color get _cardColorLight => AppColors.adaptiveSurface;

  static const Color _successColor = Color(0xFF31D7A4);

  static const Color _warningColor = Color(0xFFFFB84D);

  static const Color _dangerColor = Color(0xFFFF5C7A);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadSessions();
  }

  // ============================================================
  // LOAD SESSIONS
  // ============================================================

  Future<void> _loadSessions() async {
    if (widget.activeToken.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Authentication token is missing. Please login again.';
      });

      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/security/sessions'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.activeToken}',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final List<dynamic> sessionData = data['sessions'] ?? [];

        setState(() {
          _sessions = sessionData
              .map((item) => WalletSession.fromJson(item))
              .toList();

          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Your session has expired. Please login again.';
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = _extractMessage(
            response.body,
            'Unable to load sessions.',
          );
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to connect to the server.';
      });
    }
  }

  // ============================================================
  // REVOKE ONE SESSION
  // ============================================================

  Future<void> _revokeSession(WalletSession session) async {
    if (session.isCurrent) {
      _showMessage('You cannot revoke your current session.', isError: true);

      return;
    }

    final confirmed = await _showRevokeDialog(session);

    if (!confirmed || !mounted) {
      return;
    }

    try {
      _showLoadingDialog('Revoking session...');

      final response = await http.delete(
        Uri.parse('$_baseUrl/security/sessions/${session.id}'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.activeToken}',
        },
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      if (response.statusCode == 200) {
        _showMessage('Session revoked successfully.');

        await _loadSessions();
      } else {
        _showMessage(
          _extractMessage(response.body, 'Unable to revoke session.'),
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop();

      _showMessage('Unable to connect to the server.', isError: true);
    }
  }

  // ============================================================
  // REVOKE ALL OTHER SESSIONS
  // ============================================================

  Future<void> _revokeAllOtherSessions() async {
    final otherSessions = _sessions
        .where((session) => !session.isCurrent)
        .toList();

    if (otherSessions.isEmpty) {
      _showMessage('There are no other active sessions.');

      return;
    }

    final confirmed = await _showRevokeAllDialog(otherSessions.length);

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _isRevokingAll = true;
    });

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/security/sessions/other'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.activeToken}',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final revokedCount = data['revoked_count'] ?? 0;

        _showMessage('$revokedCount other session(s) revoked.');

        await _loadSessions();
      } else {
        _showMessage(
          _extractMessage(response.body, 'Unable to revoke other sessions.'),
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage('Unable to connect to the server.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isRevokingAll = false;
        });
      }
    }
  }

  // ============================================================
  // REVOKE DIALOG
  // ============================================================

  Future<bool> _showRevokeDialog(WalletSession session) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Revoke Session?',
            style: TextStyle(color: AppColors.themeText, fontWeight: FontWeight.w700),
          ),
          content: Text(
            'This will sign out the selected device from your NaNa Wallet account.\n\n${session.device}',
            style: TextStyle(
              color: AppColors.themeText.withOpacity(0.72),
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.themeText.withOpacity(0.65)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _dangerColor,
                foregroundColor: AppColors.themeText,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Revoke'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ============================================================
  // REVOKE ALL DIALOG
  // ============================================================

  Future<bool> _showRevokeAllDialog(int count) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Log Out Other Sessions?',
            style: TextStyle(color: AppColors.themeText, fontWeight: FontWeight.w700),
          ),
          content: Text(
            'This will revoke $count other active session(s). Your current session will remain active.',
            style: TextStyle(
              color: AppColors.themeText.withOpacity(0.72),
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.themeText.withOpacity(0.65)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _dangerColor,
                foregroundColor: AppColors.themeText,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Log Out All'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ============================================================
  // LOADING DIALOG
  // ============================================================

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.royalBlue,
                  ),
                ),
                SizedBox(width: 18),
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
      },
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: AppColors.themeText,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: AppColors.themeText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? _dangerColor : _successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ============================================================
  // EXTRACT API MESSAGE
  // ============================================================

  String _extractMessage(String body, String fallback) {
    try {
      final data = jsonDecode(body);

      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {}

    return fallback;
  }

  // ============================================================
  // DEVICE ICON
  // ============================================================

  IconData _deviceIcon(String device) {
    final lower = device.toLowerCase();

    if (lower.contains('android')) {
      return Icons.phone_android_rounded;
    }

    if (lower.contains('iphone') || lower.contains('ipad')) {
      return Icons.phone_iphone_rounded;
    }

    if (lower.contains('desktop') || lower.contains('laptop')) {
      return Icons.laptop_mac_rounded;
    }

    return Icons.devices_rounded;
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Unknown';
    }

    final local = dateTime.toLocal();

    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;

    final minute = local.minute.toString().padLeft(2, '0');

    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '${local.day}/${local.month}/${local.year} '
        '$hour:$minute $period';
  }

  // ============================================================
  // SESSION CARD
  // ============================================================

  Widget _buildSessionCard(WalletSession session) {
    final icon = _deviceIcon(session.device);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: session.isCurrent ? _cardColorLight : _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: session.isCurrent
              ? _successColor.withOpacity(0.30)
              : AppColors.themeText.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --------------------------------------------------
            // TOP ROW
            // --------------------------------------------------
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.royalBlue.withOpacity(0.22),
                        AppColors.neonPink.withOpacity(0.16),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: AppColors.themeText, size: 25),
                ),

                SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.device,
                        style: TextStyle(
                          color: AppColors.themeText,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      SizedBox(height: 5),

                      Text(
                        session.name,
                        style: TextStyle(
                          color: AppColors.themeText.withOpacity(0.50),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                if (session.isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _successColor.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _successColor.withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 7, color: _successColor),
                        SizedBox(width: 5),
                        Text(
                          'Current',
                          style: TextStyle(
                            color: _successColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            SizedBox(height: 18),

            Divider(color: AppColors.themeText.withOpacity(0.06), height: 1),

            SizedBox(height: 15),

            // --------------------------------------------------
            // SESSION DETAILS
            // --------------------------------------------------
            _buildDetailRow(
              icon: Icons.language_rounded,
              label: 'IP Address',
              value: session.ipAddress ?? 'Unknown',
            ),

            SizedBox(height: 12),

            _buildDetailRow(
              icon: Icons.access_time_rounded,
              label: 'Last Active',
              value: _formatDate(session.lastUsedAt),
            ),

            SizedBox(height: 12),

            _buildDetailRow(
              icon: Icons.login_rounded,
              label: 'Signed In',
              value: _formatDate(session.createdAt),
            ),

            // --------------------------------------------------
            // REVOKE BUTTON
            // --------------------------------------------------
            if (!session.isCurrent) ...[
              SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () => _revokeSession(session),
                  icon: Icon(Icons.logout_rounded, size: 18),
                  label: Text('Revoke Session'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _dangerColor,
                    side: BorderSide(color: _dangerColor.withOpacity(0.35)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.themeText.withOpacity(0.42)),
        SizedBox(width: 10),
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.themeText.withOpacity(0.45),
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // INFO CARD
  // ============================================================

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.royalBlue.withOpacity(0.16),
            AppColors.neonPink.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.royalBlue.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.royalBlue.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.security_rounded,
              color: AppColors.royalBlue,
              size: 21,
            ),
          ),

          SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep your account secure',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                SizedBox(height: 6),

                Text(
                  'Review your active sessions regularly. '
                  'If you see a device you do not recognize, '
                  'revoke it immediately.',
                  style: TextStyle(
                    color: AppColors.themeText.withOpacity(0.62),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 70),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: _cardColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.themeText.withOpacity(0.07)),
              ),
              child: Icon(
                Icons.devices_rounded,
                size: 34,
                color: AppColors.themeText.withOpacity(0.45),
              ),
            ),

            SizedBox(height: 20),

            Text(
              'No Active Sessions',
              style: TextStyle(
                color: AppColors.themeText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            SizedBox(height: 8),

            Text(
              'No login sessions were found.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.themeText.withOpacity(0.50),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: _dangerColor.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                color: _dangerColor,
                size: 32,
              ),
            ),

            SizedBox(height: 18),

            Text(
              'Unable to Load Sessions',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.themeText,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),

            SizedBox(height: 8),

            Text(
              _errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.themeText.withOpacity(0.55),
                fontSize: 13,
                height: 1.4,
              ),
            ),

            SizedBox(height: 22),

            ElevatedButton.icon(
              onPressed: _loadSessions,
              icon: Icon(Icons.refresh_rounded),
              label: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.royalBlue,
                foregroundColor: AppColors.themeText,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ],
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
    final otherSessionCount = _sessions
        .where((session) => !session.isCurrent)
        .length;

    return Scaffold(
      backgroundColor: _background,

      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.themeText,
            size: 20,
          ),
        ),
        title: Text(
          'Session Management',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: _loadSessions,
        color: AppColors.royalBlue,
        backgroundColor: _cardColor,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppColors.royalBlue,
                  strokeWidth: 2.5,
                ),
              )
            : _errorMessage != null
            ? _buildErrorState()
            : ListView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 35),
                children: [
                  // ------------------------------------------------
                  // INFO
                  // ------------------------------------------------
                  _buildInfoCard(),

                  // ------------------------------------------------
                  // SESSION COUNT
                  // ------------------------------------------------
                  Row(
                    children: [
                      Text(
                        'ACTIVE SESSIONS',
                        style: TextStyle(
                          color: AppColors.themeText,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),

                      Spacer(),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.themeText.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_sessions.length}',
                          style: TextStyle(
                            color: AppColors.themeText.withOpacity(0.75),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 14),

                  // ------------------------------------------------
                  // SESSIONS
                  // ------------------------------------------------
                  if (_sessions.isEmpty)
                    _buildEmptyState()
                  else
                    ..._sessions.map(_buildSessionCard),

                  // ------------------------------------------------
                  // LOG OUT ALL OTHER SESSIONS
                  // ------------------------------------------------
                  if (otherSessionCount > 0) ...[
                    SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isRevokingAll
                            ? null
                            : _revokeAllOtherSessions,
                        icon: _isRevokingAll
                            ? SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.themeText,
                                ),
                              )
                            : Icon(Icons.logout_rounded, size: 20),
                        label: Text(
                          _isRevokingAll
                              ? 'Revoking...'
                              : 'Log Out All Other Sessions',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _dangerColor,
                          disabledBackgroundColor: _dangerColor.withOpacity(
                            0.35,
                          ),
                          foregroundColor: AppColors.themeText,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 12),

                    Center(
                      child: Text(
                        '$otherSessionCount other active session'
                        '${otherSessionCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: AppColors.themeText.withOpacity(0.40),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],

                  SizedBox(height: 10),
                ],
              ),
      ),
    );
  }
}

// ================================================================
// SESSION MODEL
// ================================================================

class WalletSession {
  final int id;
  final String name;
  final String device;
  final String? ipAddress;
  final String? userAgent;
  final DateTime? lastUsedAt;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final bool isCurrent;

  WalletSession({
    required this.id,
    required this.name,
    required this.device,
    this.ipAddress,
    this.userAgent,
    this.lastUsedAt,
    this.createdAt,
    this.expiresAt,
    required this.isCurrent,
  });

  factory WalletSession.fromJson(Map<String, dynamic> json) {
    return WalletSession(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,

      name: json['name']?.toString() ?? 'walletapptoken',

      device: json['device']?.toString() ?? 'Unknown Device',

      ipAddress: json['ip_address']?.toString(),

      userAgent: json['user_agent']?.toString(),

      lastUsedAt: _parseDate(json['last_used_at']),

      createdAt: _parseDate(json['created_at']),

      expiresAt: _parseDate(json['expires_at']),

      isCurrent: json['is_current'] == true,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }
}
