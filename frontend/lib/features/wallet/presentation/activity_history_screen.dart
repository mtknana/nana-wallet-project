import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/core/config/api_config.dart';

class ActivityHistoryScreen extends StatefulWidget {
  final String activeToken;

  ActivityHistoryScreen({super.key, required this.activeToken});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  // ============================================================
  // API
  // ============================================================

  static const String _baseUrl = ApiConfig.baseUrl;

  static const String _activityHistoryEndpoint = '/wallet/activity-history';

  // ============================================================
  // STATE
  // ============================================================

  List<ActivityItem> _activities = [];

  bool _isLoading = true;
  bool _isRefreshing = false;

  String? _errorMessage;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  // ============================================================
  // LOAD ACTIVITY HISTORY
  // ============================================================

  Future<void> _loadActivities({bool refresh = false}) async {
    if (refresh) {
      if (mounted) {
        setState(() {
          _isRefreshing = true;
          _errorMessage = null;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }
    }

    try {
      // ----------------------------------------------------------
      // TOKEN CHECK
      // ----------------------------------------------------------

      final token = widget.activeToken.trim();

      if (token.isEmpty) {
        throw Exception(
          'Authentication token is missing. '
          'Please log in again.',
        );
      }

      // ----------------------------------------------------------
      // REQUEST
      // ----------------------------------------------------------

      final uri = Uri.parse('$_baseUrl$_activityHistoryEndpoint');

      debugPrint('➡️ GET: $uri');

      debugPrint('🔐 Activity History token available: YES');

      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(Duration(seconds: 15));

      debugPrint(
        '⬅️ Response [activity-history]: '
        '${response.statusCode}',
      );

      debugPrint('📦 Body: ${response.body}');

      // ----------------------------------------------------------
      // SUCCESS
      // ----------------------------------------------------------

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);

        if (decoded is! Map<String, dynamic>) {
          throw Exception('Invalid response received from the server.');
        }

        // Backend currently returns:
        //
        // {
        //   "status": "success",
        //   "activities": [...]
        // }
        //
        // We also support "transactions" as a fallback.

        dynamic rawActivities = decoded['activities'];

        if (rawActivities == null) {
          rawActivities = decoded['transactions'];
        }

        if (rawActivities == null) {
          rawActivities = decoded['data'];
        }

        List<dynamic> activitiesJson = [];

        if (rawActivities is List) {
          activitiesJson = rawActivities;
        } else if (rawActivities is Map<String, dynamic>) {
          final nestedActivities =
              rawActivities['activities'] ??
              rawActivities['transactions'] ??
              rawActivities['data'];

          if (nestedActivities is List) {
            activitiesJson = nestedActivities;
          }
        }

        final activities = <ActivityItem>[];

        for (final item in activitiesJson) {
          if (item is Map<String, dynamic>) {
            activities.add(ActivityItem.fromJson(item));
          }
        }

        if (!mounted) return;

        setState(() {
          _activities = activities;
          _isLoading = false;
          _isRefreshing = false;
          _errorMessage = null;
        });

        debugPrint(
          '✅ Activity History loaded: '
          '${activities.length} records',
        );

        return;
      }

      // ----------------------------------------------------------
      // API ERROR
      // ----------------------------------------------------------

      String message = 'Unable to load activity history.';

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          final serverMessage = decoded['message'] ?? decoded['error'];

          if (serverMessage != null &&
              serverMessage.toString().trim().isNotEmpty) {
            message = serverMessage.toString();
          }

          // ------------------------------------------------------
          // STATUS-SPECIFIC MESSAGE
          // ------------------------------------------------------

          if (response.statusCode == 401) {
            message =
                'Your session has expired. '
                'Please log in again.';
          } else if (response.statusCode == 404) {
            message = 'Activity History endpoint was not found.';
          } else if (response.statusCode >= 500) {
            message =
                'The server encountered an error. '
                'Please try again.';
          }
        }
      } catch (_) {
        // Keep default message.
      }

      throw Exception(
        '$message '
        '(HTTP ${response.statusCode})',
      );
    } on FormatException {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = 'The server returned an invalid response.';
      });

      debugPrint('❌ Activity History: Invalid JSON response.');
    } catch (e) {
      if (!mounted) return;

      final errorText = e.toString();

      debugPrint('❌ Activity History Error: $errorText');

      String userMessage;

      if (errorText.contains('TimeoutException')) {
        userMessage = 'The server took too long to respond.';
      } else if (errorText.contains('Failed host lookup')) {
        userMessage = 'Unable to reach the server.';
      } else if (errorText.contains('Connection refused')) {
        userMessage = 'The Laravel server is not running.';
      } else if (errorText.contains('Authentication token is missing')) {
        userMessage =
            'Authentication token is missing. '
            'Please log in again.';
      } else if (errorText.startsWith('Exception: ')) {
        userMessage = errorText.substring('Exception: '.length);
      } else {
        userMessage = 'Unable to load activity history.';
      }

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = userMessage;
      });
    }
  }

  // ============================================================
  // ACTIVITY ICON
  // ============================================================

  IconData _activityIcon(String type) {
    final value = type.toLowerCase();

    if (value.contains('transfer') || value.contains('p2p')) {
      return Icons.swap_horiz_rounded;
    }

    if (value.contains('withdraw')) {
      return Icons.south_west_rounded;
    }

    if (value.contains('deposit')) {
      return Icons.north_east_rounded;
    }

    if (value.contains('payment')) {
      return Icons.receipt_long_rounded;
    }

    if (value.contains('qr')) {
      return Icons.qr_code_rounded;
    }

    if (value.contains('topup') ||
        value.contains('top_up') ||
        value.contains('mobile')) {
      return Icons.phone_android_rounded;
    }

    if (value.contains('bill')) {
      return Icons.receipt_rounded;
    }

    if (value.contains('split')) {
      return Icons.call_split_rounded;
    }

    if (value.contains('scheduled')) {
      return Icons.schedule_rounded;
    }

    if (value.contains('fee')) {
      return Icons.account_balance_wallet_outlined;
    }

    return Icons.account_balance_wallet_rounded;
  }

  // ============================================================
  // ACTIVITY COLOR
  // ============================================================

  Color _activityColor(String type) {
    final value = type.toLowerCase();

    if (value.contains('withdraw') || value.contains('payment')) {
      return Colors.orangeAccent;
    }

    if (value.contains('transfer') || value.contains('p2p')) {
      return AppColors.neonPink;
    }

    if (value.contains('deposit')) {
      return Colors.greenAccent;
    }

    if (value.contains('qr')) {
      return Colors.cyanAccent;
    }

    if (value.contains('topup') ||
        value.contains('top_up') ||
        value.contains('mobile')) {
      return Colors.lightBlueAccent;
    }

    if (value.contains('bill')) {
      return Colors.orangeAccent;
    }

    if (value.contains('split')) {
      return AppColors.neonPink;
    }

    return AppColors.royalBlue;
  }

  // ============================================================
  // FORMAT TYPE
  // ============================================================

  String _formatType(String value) {
    if (value.trim().isEmpty) {
      return 'Wallet Activity';
    }

    return value
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) {
            return word;
          }

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
  // CURRENCY SYMBOL
  // ============================================================

  String _currencySymbol(String currency) {
    if (currency.toUpperCase() == 'KHR') {
      return '៛';
    }

    return '\$';
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
      case 'successful':
        return Colors.greenAccent;

      case 'pending':
      case 'processing':
        return Colors.orangeAccent;

      case 'failed':
      case 'cancelled':
      case 'canceled':
        return Colors.redAccent;

      default:
        return AppColors.themeText.withValues(alpha: 0.54);
    }
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
          'Activity History',
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
                : () => _loadActivities(refresh: true),
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
      return Center(
        child: CircularProgressIndicator(color: AppColors.royalBlue),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_activities.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: AppColors.royalBlue,
      backgroundColor: AppColors.adaptiveSurface,
      onRefresh: () => _loadActivities(refresh: true),
      child: ListView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          _buildSummaryCard(),

          SizedBox(height: 18),

          ..._activities.map(
            (activity) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildActivityCard(activity),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget _buildSummaryCard() {
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
              Icons.receipt_long_rounded,
              color: AppColors.themeText,
              size: 25,
            ),
          ),

          SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wallet Activity',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  '${_activities.length} recent '
                  'activity record'
                  '${_activities.length == 1 ? '' : 's'}',

                  style: TextStyle(
                    color: AppColors.themeText.withOpacity(0.62),
                    fontSize: 12.5,
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
  // ACTIVITY CARD
  // ============================================================

  Widget _buildActivityCard(ActivityItem activity) {
    final color = _activityColor(activity.type);

    final icon = _activityIcon(activity.type);

    final statusColor = _statusColor(activity.status);

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
              color: color.withOpacity(0.14),
            ),

            child: Icon(icon, color: color, size: 22),
          ),

          title: Text(
            activity.description.isNotEmpty
                ? activity.description
                : _formatType(activity.type),

            maxLines: 2,
            overflow: TextOverflow.ellipsis,

            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),

          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),

            child: Row(
              children: [
                Flexible(
                  child: Text(
                    _formatType(activity.type),
                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      color: color,
                      fontSize: 11,
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
                    _formatDate(activity.createdAt),

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

          trailing: null,

          children: [
            // --------------------------------------------------
            // AMOUNT
            // --------------------------------------------------
            _detailRow(
              icon: Icons.payments_outlined,
              title: 'Amount',
              value:
                  '${_currencySymbol(activity.currency)}'
                  '${activity.amount.toStringAsFixed(2)} '
                  '${activity.currency.toUpperCase()}',
              valueColor: color,
            ),

            // --------------------------------------------------
            // STATUS
            // --------------------------------------------------
            _detailRow(
              icon: Icons.verified_outlined,
              title: 'Status',
              value: _formatType(activity.status),
              valueColor: statusColor,
            ),

            // --------------------------------------------------
            // REFERENCE
            // --------------------------------------------------
            if (activity.reference != null && activity.reference!.isNotEmpty)
              _detailRow(
                icon: Icons.tag_rounded,
                title: 'Reference',
                value: activity.reference!,
              ),

            // --------------------------------------------------
            // FEE
            // --------------------------------------------------
            if (activity.feeCharged > 0)
              _detailRow(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Service Fee',
                value:
                    '${_currencySymbol(activity.currency)}'
                    '${activity.feeCharged.toStringAsFixed(2)} '
                    '${activity.currency.toUpperCase()}',
                valueColor: Colors.orangeAccent,
              ),

            // --------------------------------------------------
            // DESCRIPTION
            // --------------------------------------------------
            if (activity.description.isNotEmpty)
              _detailRow(
                icon: Icons.description_outlined,
                title: 'Description',
                value: activity.description,
              ),

            // --------------------------------------------------
            // DATE
            // --------------------------------------------------
            _detailRow(
              icon: Icons.calendar_today_outlined,
              title: 'Date & Time',
              value: _formatDate(activity.createdAt),
            ),

            // --------------------------------------------------
            // TRANSACTION ID
            // --------------------------------------------------
            _detailRow(
              icon: Icons.fingerprint_rounded,
              title: 'Transaction ID',
              value: '#${activity.id}',
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget _detailRow({
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
      color: AppColors.royalBlue,
      backgroundColor: AppColors.adaptiveSurface,

      onRefresh: () => _loadActivities(refresh: true),

      child: ListView(
        physics: AlwaysScrollableScrollPhysics(),

        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),

          Icon(
            Icons.receipt_long_outlined,
            color: AppColors.themeText.withOpacity(0.28),
            size: 72,
          ),

          SizedBox(height: 18),

          Center(
            child: Text(
              'No Activity Yet',
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
                'Your wallet activity will '
                'appear here when you make '
                'a transaction.',

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
              'Unable to Load Activity',
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
              onPressed: _isRefreshing
                  ? null
                  : () {
                      _loadActivities();
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
// ACTIVITY MODEL
// ============================================================

class ActivityItem {
  final int id;
  final String type;
  final double amount;
  final String description;
  final String? reference;
  final String status;
  final String currency;
  final double feeCharged;
  final DateTime? createdAt;

  ActivityItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.reference,
    required this.status,
    required this.currency,
    required this.feeCharged,
    required this.createdAt,
  });

  // ============================================================
  // JSON
  // ============================================================

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      id: _parseInt(json['id']),

      type: json['type']?.toString() ?? '',

      amount: _parseDouble(json['amount']),

      description: json['description']?.toString() ?? '',

      // --------------------------------------------------------
      // IMPORTANT:
      // Laravel Transaction uses reference_id.
      // reference is kept as fallback for compatibility.
      // --------------------------------------------------------
      reference:
          json['reference_id']?.toString() ??
          json['referenceId']?.toString() ??
          json['reference']?.toString(),

      status: json['status']?.toString() ?? 'unknown',

      currency: json['currency']?.toString() ?? 'USD',

      feeCharged: _parseDouble(json['fee_charged'] ?? json['feeCharged']),

      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),
    );
  }

  // ============================================================
  // INTEGER
  // ============================================================

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  // ============================================================
  // DOUBLE
  // ============================================================

  static double _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  // ============================================================
  // DATE
  // ============================================================

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }
}
