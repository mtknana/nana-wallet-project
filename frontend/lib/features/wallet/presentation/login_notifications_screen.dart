import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/wallet/services/wallet_service.dart';

class LoginNotificationsScreen extends StatefulWidget {
  final String token;

  LoginNotificationsScreen({super.key, required this.token});

  @override
  State<LoginNotificationsScreen> createState() =>
      _LoginNotificationsScreenState();
}

class _LoginNotificationsScreenState extends State<LoginNotificationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  // ============================================================
  // LOAD LOGIN NOTIFICATIONS
  // ============================================================

  Future<void> _loadNotifications() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final notifications = await WalletService.fetchLoginNotifications(
        token: widget.token,
      );

      if (!mounted) return;

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Failed to load login notifications: $e');

      if (!mounted) return;

      setState(() {
        _notifications = [];
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // EVENT ICON
  // ============================================================

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'login_success':
        return LucideIcons.logIn;

      case 'login_failed':
        return LucideIcons.shieldAlert;

      default:
        return LucideIcons.activity;
    }
  }

  // ============================================================
  // EVENT LABEL
  // ============================================================

  String _getEventLabel(String eventType) {
    switch (eventType) {
      case 'login_success':
        return 'LOGIN SUCCESS';

      case 'login_failed':
        return 'LOGIN FAILED';

      default:
        return 'LOGIN ACTIVITY';
    }
  }

  // ============================================================
  // SEVERITY
  // ============================================================

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'danger':
      case 'critical':
        return Colors.redAccent;

      case 'warning':
        return Colors.orangeAccent;

      case 'info':
      default:
        return AppColors.royalBlue;
    }
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(dynamic value) {
    if (value == null) {
      return 'Unknown time';
    }

    try {
      final date = DateTime.parse(value.toString()).toLocal();

      final hour = date.hour == 0
          ? 12
          : date.hour > 12
          ? date.hour - 12
          : date.hour;

      final minute = date.minute.toString().padLeft(2, '0');

      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year} • '
          '$hour:$minute $period';
    } catch (_) {
      return value.toString();
    }
  }

  // ============================================================
  // DEVICE / USER AGENT
  // ============================================================

  String _formatUserAgent(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return 'Unknown device';
    }

    final userAgent = value.toString();

    // Windows + Chrome
    if (userAgent.contains('Windows') && userAgent.contains('Chrome')) {
      return 'Windows • Google Chrome';
    }

    // Windows + Edge
    if (userAgent.contains('Windows') && userAgent.contains('Edg')) {
      return 'Windows • Microsoft Edge';
    }

    // Windows + Firefox
    if (userAgent.contains('Windows') && userAgent.contains('Firefox')) {
      return 'Windows • Mozilla Firefox';
    }

    // Android + Chrome
    if (userAgent.contains('Android') && userAgent.contains('Chrome')) {
      return 'Android • Google Chrome';
    }

    // Android
    if (userAgent.contains('Android')) {
      return 'Android Device';
    }

    // iPhone / iPad
    if (userAgent.contains('iPhone')) {
      return 'iPhone';
    }

    if (userAgent.contains('iPad')) {
      return 'iPad';
    }

    // macOS
    if (userAgent.contains('Macintosh')) {
      return 'macOS';
    }

    // Linux
    if (userAgent.contains('Linux')) {
      return 'Linux Device';
    }

    return 'Unknown Device';
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

        title: Text(
          'Login Notifications',
          style: TextStyle(
            color: AppColors.themeText,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),

        centerTitle: false,

        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadNotifications,
            icon: Icon(LucideIcons.refreshCw, color: AppColors.themeText),
            tooltip: 'Refresh',
          ),

          SizedBox(width: 8),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        color: AppColors.royalBlue,
        backgroundColor: AppColors.adaptiveSurface,

        child: _buildBody(),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_notifications.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      physics: AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _buildHeaderCard(),

        SizedBox(height: 24),

        Text(
          'RECENT LOGIN ACTIVITY',
          style: TextStyle(
            color: AppColors.themeText.withValues(alpha: 0.70),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
          ),
        ),

        SizedBox(height: 12),

        ..._notifications.map(
          (notification) => _buildNotificationCard(notification),
        ),
      ],
    );
  }

  // ============================================================
  // HEADER CARD
  // ============================================================

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),

        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,

          colors: [
            AppColors.royalBlue.withOpacity(0.22),
            AppColors.adaptiveSurface,
          ],
        ),

        border: Border.all(color: AppColors.royalBlue.withOpacity(0.25)),
      ),

      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,

            decoration: BoxDecoration(
              color: AppColors.royalBlue.withOpacity(0.15),
              shape: BoxShape.circle,
            ),

            child: Icon(
              LucideIcons.shieldCheck,
              color: AppColors.royalBlue,
              size: 27,
            ),
          ),

          SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children:  [
                Text(
                  'Account Login Activity',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  'Monitor recent sign-in activity on your NaNa Wallet account.',
                  style: TextStyle(
                    color: AppColors.themeText.withValues(alpha: 0.60),
                    fontSize: 12.5,
                    height: 1.4,
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
  // NOTIFICATION CARD
  // ============================================================

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final eventType = notification['event_type']?.toString() ?? '';

    final severity = notification['severity']?.toString() ?? 'info';

    final title = notification['title']?.toString() ?? 'Login Activity';

    final description =
        notification['description']?.toString() ??
        'Login activity was detected.';

    final ipAddress = notification['ip_address']?.toString();

    final userAgent = notification['user_agent']?.toString();

    final isReviewed = notification['is_reviewed'] == true;

    final severityColor = _getSeverityColor(severity);

    final eventIcon = _getEventIcon(eventType);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),

      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: AppColors.adaptiveSurfaceAlt,
        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: AppColors.themeText.withOpacity(0.07)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // ======================================================
          // TOP ROW
          // ======================================================
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Container(
                width: 46,
                height: 46,

                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),

                child: Icon(eventIcon, color: severityColor, size: 22),
              ),

              SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: AppColors.themeText,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        if (!isReviewed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.royalBlue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'NEW',
                              style: TextStyle(
                                color: AppColors.royalBlue,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),

                    SizedBox(height: 5),

                    Text(
                      description,
                      style: TextStyle(
                        color: AppColors.themeText.withValues(alpha: 0.60),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 15),

          Divider(color: AppColors.themeText.withOpacity(0.06), height: 1),

          SizedBox(height: 14),

          // ======================================================
          // EVENT LABEL + SEVERITY
          // ======================================================
          Row(
            children: [
              _buildSmallBadge(
                icon: LucideIcons.activity,
                text: _getEventLabel(eventType),
                color: AppColors.royalBlue,
              ),

              SizedBox(width: 8),

              _buildSmallBadge(
                icon: LucideIcons.shield,
                text: severity.toUpperCase(),
                color: severityColor,
              ),
            ],
          ),

          SizedBox(height: 14),

          // ======================================================
          // IP ADDRESS
          // ======================================================
          _buildInfoRow(
            icon: LucideIcons.globe,
            label: 'IP Address',
            value: (ipAddress == null || ipAddress.trim().isEmpty)
                ? 'Not available'
                : ipAddress,
          ),

          SizedBox(height: 11),

          // ======================================================
          // DEVICE
          // ======================================================
          _buildInfoRow(
            icon: LucideIcons.monitor,
            label: 'Device',
            value: _formatUserAgent(userAgent),
          ),

          SizedBox(height: 11),

          // ======================================================
          // TIME
          // ======================================================
          _buildInfoRow(
            icon: LucideIcons.clock3,
            label: 'Time',
            value: _formatDate(notification['occurred_at']),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SMALL BADGE
  // ============================================================

  Widget _buildSmallBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),

      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(9),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),

          SizedBox(width: 5),

          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Icon(icon, size: 16, color: AppColors.themeText.withValues(alpha: 0.38)),

        SizedBox(width: 10),

        SizedBox(
          width: 82,

          child: Text(
            label,
            style: TextStyle(
              color: AppColors.themeText.withValues(alpha: 0.38),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return ListView(
      physics: AlwaysScrollableScrollPhysics(),

      padding: const EdgeInsets.all(24),

      children: [
        SizedBox(height: 90),

        Center(
          child: Container(
            width: 80,
            height: 80,

            decoration: BoxDecoration(
              color: AppColors.royalBlue.withOpacity(0.10),
              shape: BoxShape.circle,
            ),

            child: Icon(
              LucideIcons.shieldCheck,
              color: AppColors.royalBlue,
              size: 38,
            ),
          ),
        ),

        SizedBox(height: 22),

        Center(
          child: Text(
            'No Login Activity',
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        SizedBox(height: 8),

        Center(
          child: Text(
            'Your recent login activity will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.54), fontSize: 13, height: 1.5),
          ),
        ),
      ],
    );
  }
}
