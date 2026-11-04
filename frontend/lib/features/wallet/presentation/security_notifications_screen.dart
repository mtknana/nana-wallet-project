import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/core/config/api_config.dart';

class SecurityNotificationsScreen extends StatefulWidget {
  final String activeToken;

  SecurityNotificationsScreen({super.key, required this.activeToken});

  @override
  State<SecurityNotificationsScreen> createState() =>
      _SecurityNotificationsScreenState();
}

class _SecurityNotificationsScreenState
    extends State<SecurityNotificationsScreen> {
  static const String _baseUrl = ApiConfig.baseUrl;

  static Color get _background => AppColors.adaptiveSurfaceAlt;
  static Color get _card => AppColors.adaptiveSurface;

  static Color get _textPrimary => AppColors.themeText;
  static const Color _textSecondary = Color(0xFFD7E0E3);
  static const Color _textMuted = Color(0xFFB7C4C8);

  List<SecurityEvent> _events = [];

  bool _isLoading = true;
  String? _errorMessage;

  // Keeps track of the security event currently being reviewed.
  int? _reviewingEventId;

  @override
  void initState() {
    super.initState();
    _loadSecurityNotifications();
  }

  // ============================================================
  // LOAD SECURITY NOTIFICATIONS
  // ============================================================

  Future<void> _loadSecurityNotifications() async {
    final token = widget.activeToken.trim();

    if (token.isEmpty) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Your session has expired. Please log in again.';
      });

      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      debugPrint('➡️ GET: security/notifications');

      final response = await http
          .get(
            Uri.parse('$_baseUrl/security/notifications'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(Duration(seconds: 15));

      debugPrint(
        '⬅️ Response [security/notifications]: '
        '${response.statusCode}',
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);

        final dynamic rawEvents = decoded is Map<String, dynamic>
            ? decoded['events'] ?? decoded['data'] ?? []
            : [];

        final List<dynamic> eventsJson = rawEvents is List ? rawEvents : [];

        final events = eventsJson
            .whereType<Map>()
            .map(
              (event) =>
                  SecurityEvent.fromJson(Map<String, dynamic>.from(event)),
            )
            .toList();

        setState(() {
          _events = events;
          _isLoading = false;
          _errorMessage = null;
        });

        debugPrint(
          '✅ Security notifications loaded: '
          '${events.length}',
        );
      } else {
        String message = 'Unable to load security alerts.';

        try {
          final decoded = jsonDecode(response.body);

          if (decoded is Map<String, dynamic>) {
            message =
                decoded['message']?.toString() ??
                decoded['error']?.toString() ??
                message;
          }
        } catch (_) {}

        if (response.statusCode == 401) {
          message = 'Your session has expired. Please log in again.';
        } else if (response.statusCode == 404) {
          message = 'Security notification service was not found.';
        }

        setState(() {
          _isLoading = false;
          _errorMessage = message;
        });

        debugPrint(
          '❌ Security notification error: '
          '${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Security notification exception: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to connect to the server. Please try again.';
      });
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    await _loadSecurityNotifications();
  }

  // ============================================================
  // MARK SECURITY NOTIFICATION AS REVIEWED
  // ============================================================

  Future<void> _reviewSecurityNotification(SecurityEvent event) async {
    final token = widget.activeToken.trim();

    if (token.isEmpty) {
      _showMessage(
        'Your session has expired. Please log in again.',
        isError: true,
      );
      return;
    }

    if (event.id == null) {
      _showMessage('Unable to review this security alert.', isError: true);
      return;
    }

    if (event.isReviewed) {
      return;
    }

    setState(() {
      _reviewingEventId = event.id;
    });

    try {
      debugPrint(
        '➡️ PATCH: security/notifications/'
        '${event.id}/review',
      );

      final response = await http
          .patch(
            Uri.parse(
              '$_baseUrl/security/notifications/'
              '${event.id}/review',
            ),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 15));

      debugPrint(
        '⬅️ Response [security notification review]: '
        '${response.statusCode}',
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Update the event locally so the UI immediately changes
        // from NOT REVIEWED to REVIEWED.
        setState(() {
          final index = _events.indexWhere((item) => item.id == event.id);

          if (index != -1) {
            _events[index] = _events[index].copyWith(isReviewed: true);
          }

          _reviewingEventId = null;
        });

        debugPrint('✅ Security notification ${event.id} marked as reviewed.');

        _showMessage('Security alert marked as reviewed.');
      } else {
        String message = 'Unable to mark this alert as reviewed.';

        try {
          final decoded = jsonDecode(response.body);

          if (decoded is Map<String, dynamic>) {
            message =
                decoded['message']?.toString() ??
                decoded['error']?.toString() ??
                message;
          }
        } catch (_) {}

        if (response.statusCode == 401) {
          message = 'Your session has expired. Please log in again.';
        } else if (response.statusCode == 404) {
          message = 'Security notification was not found.';
        }

        setState(() {
          _reviewingEventId = null;
        });

        debugPrint(
          '❌ Review security notification error: '
          '${response.statusCode} - ${response.body}',
        );

        _showMessage(message, isError: true);
      }
    } catch (e) {
      debugPrint('❌ Review security notification exception: $e');

      if (!mounted) return;

      setState(() {
        _reviewingEventId = null;
      });

      _showMessage(
        'Unable to connect to the server. Please try again.',
        isError: true,
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        backgroundColor: _card,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isError
                ? AppColors.neonPink.withValues(alpha: 0.35)
                : Colors.greenAccent.withValues(alpha: 0.30),
          ),
        ),
        content: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isError ? AppColors.neonPink : Colors.greenAccent)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: isError ? AppColors.neonPink : Colors.greenAccent,
                size: 20,
              ),
            ),
            SizedBox(width: 11),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: AppColors.themeText,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
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
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.themeText,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Security Alerts',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _refresh,
            icon: Icon(
              Icons.refresh_rounded,
              color: _isLoading ? AppColors.themeText.withValues(alpha: 0.38) : AppColors.royalBlue,
            ),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.royalBlue,
        backgroundColor: _card,
        onRefresh: _refresh,
        child: _buildBody(),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          SizedBox(height: 100),
          Center(
            child: Column(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.royalBlue,
                  ),
                ),
                SizedBox(height: 18),
                Text(
                  'Loading security alerts...',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [SizedBox(height: 70), _buildErrorState()],
      );
    }

    if (_events.isEmpty) {
      return ListView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [SizedBox(height: 70), _buildEmptyState()],
      );
    }

    return ListView.builder(
      physics: AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        return _buildSecurityCard(_events[index]);
      },
    );
  }

  // ============================================================
  // SECURITY CARD
  // ============================================================

  Widget _buildSecurityCard(SecurityEvent event) {
    final bool isLoginSuccess =
        event.type.toLowerCase().contains('login') ||
        event.title.toLowerCase().contains('login') ||
        event.title.toLowerCase().contains('success');

    final bool isReviewed = event.isReviewed;

    final bool isReviewing = _reviewingEventId == event.id;

    final Color eventColor = isLoginSuccess
        ? Colors.greenAccent
        : AppColors.royalBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: eventColor.withValues(alpha: 0.18), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================================================
            // HEADER
            // ==================================================
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: eventColor.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: eventColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    isLoginSuccess ? Icons.login_rounded : Icons.shield_rounded,
                    color: eventColor,
                    size: 22,
                  ),
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
                              isLoginSuccess ? 'Login Success' : event.title,
                              style: TextStyle(
                                color: AppColors.themeText,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),

                          SizedBox(width: 8),

                          _buildReviewBadge(isReviewed: isReviewed),
                        ],
                      ),

                      SizedBox(height: 7),

                      // ==================================================
                      // VERY VISIBLE EVENT TYPE
                      // ==================================================
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: eventColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isLoginSuccess
                              ? 'LOGIN SUCCESS'
                              : event.type.toUpperCase(),
                          style: TextStyle(
                            color: eventColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 17),

            // ==================================================
            // DESCRIPTION
            // ==================================================
            Text(
              event.description.isNotEmpty
                  ? event.description
                  : isLoginSuccess
                  ? 'Your account was successfully logged in.'
                  : 'A security event occurred on your account.',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),

            SizedBox(height: 17),

            Container(height: 1, color: AppColors.themeText.withValues(alpha: 0.07)),

            SizedBox(height: 14),

            // ==================================================
            // DATE
            // ==================================================
            _buildInfoRow(
              icon: Icons.access_time_rounded,
              label: 'Date & Time',
              value: _formatDate(event.createdAt),
            ),

            // ==================================================
            // IP
            // ==================================================
            if (event.ipAddress.isNotEmpty) ...[
              SizedBox(height: 10),
              _buildInfoRow(
                icon: Icons.public_rounded,
                label: 'IP Address',
                value: event.ipAddress,
              ),
            ],

            // ==================================================
            // DEVICE
            // ==================================================
            if (event.device.isNotEmpty) ...[
              SizedBox(height: 10),
              _buildInfoRow(
                icon: Icons.devices_rounded,
                label: 'Device',
                value: event.device,
              ),
            ],

            // ==================================================
            // NOT REVIEWED MESSAGE
            // ==================================================
            if (!isReviewed) ...[
              SizedBox(height: 15),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orangeAccent,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:  [
                          Text(
                            'NOT REVIEWED YET',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Please review this security activity.',
                            style: TextStyle(
                              color: Color(0xFFD7E0E3),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 12),

              // ==================================================
              // MARK AS REVIEWED BUTTON
              // ==================================================
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: isReviewing
                      ? null
                      : () => _reviewSecurityNotification(event),
                  icon: isReviewing
                      ? SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.themeText,
                          ),
                        )
                      : Icon(
                          Icons.check_circle_outline_rounded,
                          size: 19,
                        ),
                  label: Text(
                    isReviewing ? 'Marking as Reviewed...' : 'Mark as Reviewed',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.royalBlue,
                    disabledBackgroundColor: AppColors.royalBlue.withValues(
                      alpha: 0.45,
                    ),
                    foregroundColor: AppColors.themeText,
                    disabledForegroundColor: AppColors.themeText.withValues(alpha: 0.70),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
  // REVIEW BADGE
  // ============================================================

  Widget _buildReviewBadge({required bool isReviewed}) {
    if (isReviewed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.35)),
        ),
        child: Text(
          'REVIEWED',
          style: TextStyle(
            color: Colors.greenAccent,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.55)),
      ),
      child: Text(
        'NOT REVIEWED',
        style: TextStyle(
          color: Colors.orangeAccent,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: _textMuted, size: 17),
        SizedBox(width: 10),
        Text(
          '$label:',
          style: TextStyle(
            color: _textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.20)),
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.neonPink.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                color: AppColors.neonPink,
                size: 28,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Unable to Load Alerts',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.themeText,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Please try again later.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.royalBlue,
                foregroundColor: AppColors.themeText,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.royalBlue.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: AppColors.royalBlue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shield_outlined,
                color: AppColors.royalBlue,
                size: 30,
              ),
            ),
            SizedBox(height: 17),
            Text(
              'No Security Alerts',
              style: TextStyle(
                color: AppColors.themeText,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'There are no security activities to review.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Unknown';
    }

    final local = date.toLocal();

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;

    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '${local.day}/${local.month}/${local.year} '
        '${twoDigits(hour)}:${twoDigits(local.minute)} $period';
  }
}

// ============================================================
// SECURITY EVENT MODEL
// ============================================================

class SecurityEvent {
  final int? id;
  final String type;
  final String title;
  final String description;
  final String ipAddress;
  final String device;
  final DateTime? createdAt;
  final bool isReviewed;

  SecurityEvent({
    this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.ipAddress,
    required this.device,
    required this.createdAt,
    required this.isReviewed,
  });

  factory SecurityEvent.fromJson(Map<String, dynamic> json) {
    final dynamic rawId = json['id'] ?? json['event_id'];

    final dynamic rawType =
        json['type'] ?? json['event_type'] ?? json['action'] ?? '';

    final dynamic rawTitle =
        json['title'] ??
        json['event_name'] ??
        json['name'] ??
        json['type'] ??
        'Security Activity';

    final dynamic rawDescription =
        json['description'] ?? json['message'] ?? json['details'] ?? '';

    final dynamic rawIp =
        json['ip_address'] ?? json['ip'] ?? json['ipAddress'] ?? '';

    final dynamic rawDevice =
        json['device'] ??
        json['device_name'] ??
        json['user_agent'] ??
        json['userAgent'] ??
        '';

    final dynamic rawDate =
        json['created_at'] ??
        json['createdAt'] ??
        json['timestamp'] ??
        json['date'];

    final dynamic rawReviewed =
        json['is_reviewed'] ?? json['reviewed'] ?? json['isReviewed'] ?? false;

    return SecurityEvent(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? ''),
      type: rawType.toString(),
      title: rawTitle.toString(),
      description: rawDescription.toString(),
      ipAddress: rawIp.toString(),
      device: rawDevice.toString(),
      createdAt: _parseDate(rawDate),
      isReviewed: _parseBool(rawReviewed),
    );
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  SecurityEvent copyWith({
    int? id,
    String? type,
    String? title,
    String? description,
    String? ipAddress,
    String? device,
    DateTime? createdAt,
    bool? isReviewed,
  }) {
    return SecurityEvent(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      ipAddress: ipAddress ?? this.ipAddress,
      device: device ?? this.device,
      createdAt: createdAt ?? this.createdAt,
      isReviewed: isReviewed ?? this.isReviewed,
    );
  }

  // ============================================================
  // DATE PARSER
  // ============================================================

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  // ============================================================
  // BOOLEAN PARSER
  // ============================================================

  static bool _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text = value.toString().trim().toLowerCase();

    return text == 'true' || text == '1' || text == 'yes' || text == 'reviewed';
  }
}
