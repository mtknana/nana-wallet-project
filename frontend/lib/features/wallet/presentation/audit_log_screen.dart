import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/core/config/api_config.dart';

class AuditLogScreen extends StatefulWidget {
  final String activeToken;

  AuditLogScreen({super.key, required this.activeToken});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  static const String _baseUrl = ApiConfig.baseUrl;

  List<AuditLog> _logs = [];

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
  }

  // ============================================================
  // LOAD AUDIT LOGS
  // ============================================================

  Future<void> _loadAuditLogs({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isRefreshing = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/security/audit-log'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.activeToken}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final List<dynamic> logsJson = data['logs'] ?? [];

        final logs = logsJson
            .map((item) => AuditLog.fromJson(item as Map<String, dynamic>))
            .toList();

        if (!mounted) return;

        setState(() {
          _logs = logs;
          _isLoading = false;
          _isRefreshing = false;
          _errorMessage = null;
        });
      } else {
        String message = 'Unable to load audit logs.';

        try {
          final data = jsonDecode(response.body);

          if (data['message'] != null) {
            message = data['message'].toString();
          }
        } catch (_) {}

        throw Exception(message);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = 'Unable to connect to the server.';
      });
    }
  }

  // ============================================================
  // EVENT ICON
  // ============================================================

  IconData _eventIcon(String eventType) {
    final type = eventType.toLowerCase();

    if (type.contains('login')) {
      return Icons.login_rounded;
    }

    if (type.contains('logout')) {
      return Icons.logout_rounded;
    }

    if (type.contains('password')) {
      return Icons.lock_outline_rounded;
    }

    if (type.contains('pin')) {
      return Icons.password_rounded;
    }

    if (type.contains('transfer')) {
      return Icons.swap_horiz_rounded;
    }

    if (type.contains('withdraw')) {
      return Icons.account_balance_wallet_outlined;
    }

    if (type.contains('deposit')) {
      return Icons.account_balance_wallet_rounded;
    }

    if (type.contains('fraud')) {
      return Icons.gpp_maybe_rounded;
    }

    if (type.contains('suspicious')) {
      return Icons.warning_amber_rounded;
    }

    if (type.contains('session')) {
      return Icons.devices_rounded;
    }

    if (type.contains('device')) {
      return Icons.phone_android_rounded;
    }

    if (type.contains('security')) {
      return Icons.security_rounded;
    }

    if (type.contains('account')) {
      return Icons.person_outline_rounded;
    }

    return Icons.history_rounded;
  }

  // ============================================================
  // SEVERITY COLOR
  // ============================================================

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'danger':
      case 'critical':
        return Colors.redAccent;

      case 'warning':
        return Colors.orangeAccent;

      case 'success':
        return Colors.greenAccent;

      case 'info':
      default:
        return AppColors.royalBlue;
    }
  }

  // ============================================================
  // FORMAT EVENT TYPE
  // ============================================================

  String _formatEventType(String value) {
    if (value.trim().isEmpty) {
      return 'Security Activity';
    }

    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;

          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Unknown date';
    }

    final local = dateTime.toLocal();

    final day = local.day.toString().padLeft(2, '0');

    final month = local.month.toString().padLeft(2, '0');

    final year = local.year.toString();

    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;

    final minute = local.minute.toString().padLeft(2, '0');

    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year • '
        '$hour:$minute $period';
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
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.themeText,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Audit Log',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isRefreshing
                ? null
                : () => _loadAuditLogs(refresh: true),
            icon: Icon(
              Icons.refresh_rounded,
              color: _isRefreshing ? AppColors.themeText.withValues(alpha: 0.38) : AppColors.themeText,
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_logs.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => _loadAuditLogs(refresh: true),
      child: ListView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          _buildHeaderCard(),
          SizedBox(height: 18),
          ..._logs.map(
            (log) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildAuditCard(log),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER CARD
  // ============================================================

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            AppColors.royalBlue.withOpacity(0.22),
            AppColors.neonPink.withOpacity(0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.themeText.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.royalBlue.withOpacity(0.18),
            ),
            child: Icon(
              Icons.history_rounded,
              color: AppColors.themeText,
              size: 26,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Activity',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'A record of important activity '
                  'on your NaNa Wallet account.',
                  style: TextStyle(
                    color: AppColors.themeText.withOpacity(0.65),
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
  // AUDIT CARD
  // ============================================================

  Widget _buildAuditCard(AuditLog log) {
    final severityColor = _severityColor(log.severity);

    final icon = _eventIcon(log.eventType);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.themeText.withOpacity(0.045),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.themeText.withOpacity(0.07)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: AppColors.themeText.withValues(alpha: 0.54),
          collapsedIconColor: AppColors.themeText.withValues(alpha: 0.38),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: severityColor.withOpacity(0.14),
            ),
            child: Icon(icon, color: severityColor, size: 22),
          ),
          title: Text(
            log.title.isNotEmpty ? log.title : _formatEventType(log.eventType),
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    _formatEventType(log.eventType),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: severityColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 7),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.themeText.withValues(alpha: 0.38),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 7),
                Flexible(
                  child: Text(
                    _formatDate(log.occurredAt),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.themeText.withOpacity(0.48),
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          children: [
            if (log.description.isNotEmpty)
              _detailSection(
                icon: Icons.description_outlined,
                title: 'Description',
                value: log.description,
              ),

            if (log.ipAddress != null && log.ipAddress!.isNotEmpty)
              _detailSection(
                icon: Icons.language_rounded,
                title: 'IP Address',
                value: log.ipAddress!,
              ),

            if (log.userAgent != null && log.userAgent!.isNotEmpty)
              _detailSection(
                icon: Icons.devices_other_rounded,
                title: 'Device / Browser',
                value: log.userAgent!,
              ),

            if (log.referenceType != null && log.referenceType!.isNotEmpty)
              _detailSection(
                icon: Icons.link_rounded,
                title: 'Reference',
                value: log.referenceId != null
                    ? '${log.referenceType} #${log.referenceId}'
                    : log.referenceType!,
              ),

            _detailSection(
              icon: Icons.flag_outlined,
              title: 'Severity',
              value: _formatEventType(log.severity),
              valueColor: severityColor,
            ),

            _detailSection(
              icon: Icons.verified_outlined,
              title: 'Review Status',
              value: log.isReviewed ? 'Reviewed' : 'Not Reviewed',
              valueColor: log.isReviewed
                  ? Colors.greenAccent
                  : Colors.orangeAccent,
            ),

            _detailSection(
              icon: Icons.fingerprint_rounded,
              title: 'Event ID',
              value: '#${log.id}',
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget _detailSection({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.14),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.themeText.withValues(alpha: 0.38), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.themeText.withOpacity(0.45),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? AppColors.themeText.withOpacity(0.85),
                    fontSize: 12,
                    height: 1.35,
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
    return RefreshIndicator(
      onRefresh: () => _loadAuditLogs(refresh: true),
      child: ListView(
        physics: AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Icon(
            Icons.history_toggle_off_rounded,
            color: AppColors.themeText.withOpacity(0.28),
            size: 72,
          ),
          SizedBox(height: 18),
          Center(
            child: Text(
              'No Audit Activity',
              style: TextStyle(
                color: AppColors.themeText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Your account activity will '
                'appear here when available.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.themeText.withOpacity(0.5),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
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
                shape: BoxShape.circle,
                color: Colors.redAccent.withOpacity(0.12),
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                color: Colors.redAccent,
                size: 34,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Unable to Load Audit Log',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.themeText,
                fontSize: 18,
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
                height: 1.5,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _loadAuditLogs();
              },
              icon: Icon(Icons.refresh_rounded),
              label: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.royalBlue,
                foregroundColor: AppColors.themeText,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// AUDIT LOG MODEL
// ============================================================

class AuditLog {
  final int id;
  final String eventType;
  final String severity;
  final String title;
  final String description;
  final String? ipAddress;
  final String? userAgent;
  final String? referenceType;
  final int? referenceId;
  final bool isReviewed;
  final DateTime? occurredAt;

  AuditLog({
    required this.id,
    required this.eventType,
    required this.severity,
    required this.title,
    required this.description,
    this.ipAddress,
    this.userAgent,
    this.referenceType,
    this.referenceId,
    required this.isReviewed,
    this.occurredAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: _parseInt(json['id']),
      eventType: json['event_type']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'info',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      ipAddress: json['ip_address']?.toString(),
      userAgent: json['user_agent']?.toString(),
      referenceType: json['reference_type']?.toString(),
      referenceId: json['reference_id'] != null
          ? _parseInt(json['reference_id'])
          : null,
      isReviewed: _parseBool(json['is_reviewed']),
      occurredAt: _parseDateTime(json['occurred_at']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is int) {
      return value == 1;
    }

    final text = value?.toString().toLowerCase();

    return text == 'true' || text == '1';
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}
