import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/core/config/api_config.dart';

class DeviceManagementScreen extends StatefulWidget {
  final String activeToken;

  DeviceManagementScreen({super.key, required this.activeToken});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

// ============================================================
// DEVICE MODEL
// ============================================================

class DeviceModel {
  final int id;
  final String deviceId;
  final String deviceName;
  final String platform;
  final String? ipAddress;
  final String? userAgent;
  final DateTime? lastActiveAt;
  final bool isActive;
  final DateTime? createdAt;

  DeviceModel({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    this.ipAddress,
    this.userAgent,
    this.lastActiveAt,
    required this.isActive,
    this.createdAt,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] ?? 0,
      deviceId: json['device_id'] ?? '',
      deviceName: json['device_name'] ?? 'Unknown Device',
      platform: json['platform'] ?? 'Unknown',
      ipAddress: json['ip_address'],
      userAgent: json['user_agent'],
      lastActiveAt: json['last_active_at'] != null
          ? DateTime.tryParse(json['last_active_at'].toString())
          : null,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

// ============================================================
// SCREEN
// ============================================================

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  static const String _baseUrl = ApiConfig.baseUrl;

  final List<DeviceModel> _devices = [];

  bool _isLoading = true;
  bool _isRevoking = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  // ============================================================
  // LOAD DEVICES
  // ============================================================

  Future<void> _loadDevices() async {
    if (widget.activeToken.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/security/devices'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.activeToken}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final List<dynamic> deviceData = data['devices'] ?? [];

        if (mounted) {
          setState(() {
            _devices
              ..clear()
              ..addAll(deviceData.map((item) => DeviceModel.fromJson(item)));

            _isLoading = false;
          });
        }
      } else {
        _handleError('Unable to load your devices.');
      }
    } catch (e) {
      _handleError('Could not connect to the server.');
    }
  }

  // ============================================================
  // REVOKE DEVICE
  // ============================================================

  Future<void> _revokeDevice(DeviceModel device) async {
    if (_isRevoking) return;

    final shouldRevoke = await _showRevokeConfirmation(device);

    if (!shouldRevoke) return;

    if (mounted) {
      setState(() {
        _isRevoking = true;
      });
    }

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/security/devices/${device.id}'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.activeToken}',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;

        setState(() {
          _devices.removeWhere((item) => item.id == device.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device has been revoked successfully.'),
          ),
        );
      } else {
        String message = 'Unable to revoke this device.';

        try {
          final data = jsonDecode(response.body);

          if (data['message'] != null) {
            message = data['message'].toString();
          }
        } catch (_) {}

        _handleError(message);
      }
    } catch (e) {
      _handleError('Could not connect to the server.');
    } finally {
      if (mounted) {
        setState(() {
          _isRevoking = false;
        });
      }
    }
  }

  // ============================================================
  // CONFIRMATION DIALOG
  // ============================================================

  Future<bool> _showRevokeConfirmation(DeviceModel device) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.adaptiveSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Revoke Device?',
            style: TextStyle(color: AppColors.themeText, fontWeight: FontWeight.w700),
          ),
          content: Text(
            'You will no longer be able to use '
            '${device.deviceName} to access your NaNa Wallet account.',
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
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                'Revoke',
                style: TextStyle(
                  color: AppColors.neonPink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _handleError(String message) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ============================================================
  // DEVICE ICON
  // ============================================================

  IconData _deviceIcon(String platform) {
    final value = platform.toLowerCase();

    if (value.contains('android')) {
      return Icons.phone_android_rounded;
    }

    if (value.contains('ios') || value.contains('iphone')) {
      return Icons.phone_iphone_rounded;
    }

    if (value.contains('windows')) {
      return Icons.desktop_windows_rounded;
    }

    if (value.contains('mac')) {
      return Icons.laptop_mac_rounded;
    }

    if (value.contains('web') || value.contains('browser')) {
      return Icons.language_rounded;
    }

    return Icons.devices_rounded;
  }

  // ============================================================
  // DEVICE TYPE
  // ============================================================

  String _deviceType(DeviceModel device) {
    final platform = device.platform.toLowerCase();

    if (platform.contains('android')) {
      return 'Android';
    }

    if (platform.contains('ios') || platform.contains('iphone')) {
      return 'iOS';
    }

    if (platform.contains('windows')) {
      return 'Windows';
    }

    if (platform.contains('mac')) {
      return 'macOS';
    }

    if (platform.contains('web') || platform.contains('browser')) {
      return 'Web Browser';
    }

    return device.platform;
  }

  // ============================================================
  // LAST ACTIVE
  // ============================================================

  String _lastActiveText(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Activity unavailable';
    }

    final difference = DateTime.now().difference(dateTime.toLocal());

    if (difference.inSeconds < 60) {
      return 'Active just now';
    }

    if (difference.inMinutes < 60) {
      return 'Active ${difference.inMinutes} '
          '${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    }

    if (difference.inHours < 24) {
      return 'Active ${difference.inHours} '
          '${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    }

    if (difference.inDays < 7) {
      return 'Active ${difference.inDays} '
          '${difference.inDays == 1 ? 'day' : 'days'} ago';
    }

    return 'Last active '
        '${dateTime.day.toString().padLeft(2, '0')}/'
        '${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.year}';
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
          'Device Management',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDevices,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: AppColors.royalBlue),
              )
            : _devices.isEmpty
            ? _buildEmptyState()
            : _buildDeviceList(),
      ),
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
        SizedBox(height: 100),
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.royalBlue.withOpacity(0.12),
          ),
          child: Icon(
            Icons.devices_other_rounded,
            size: 40,
            color: AppColors.royalBlue,
          ),
        ),
        SizedBox(height: 24),
        Text(
          'No Active Devices',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Devices that sign in to your NaNa Wallet '
          'account will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.themeText.withOpacity(0.60),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DEVICE LIST
  // ============================================================

  Widget _buildDeviceList() {
    return ListView(
      physics: AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      children: [
        _buildHeaderCard(),

        SizedBox(height: 24),

        Text(
          'YOUR DEVICES',
          style: TextStyle(
            color: AppColors.themeText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),

        SizedBox(height: 12),

        ..._devices.map(
          (device) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildDeviceCard(device),
          ),
        ),

        SizedBox(height: 8),

        _buildSecurityInfo(),
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
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.royalBlue.withOpacity(0.22),
            AppColors.neonPink.withOpacity(0.10),
          ],
        ),
        border: Border.all(color: AppColors.themeText.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.royalBlue.withOpacity(0.18),
            ),
            child: Icon(
              Icons.security_rounded,
              color: AppColors.royalBlue,
              size: 28,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep your account secure',
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Review devices that have access '
                  'to your NaNa Wallet account.',
                  style: TextStyle(
                    color: AppColors.themeText.withOpacity(0.62),
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
  // DEVICE CARD
  // ============================================================

  Widget _buildDeviceCard(DeviceModel device) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.adaptiveSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.themeText.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 8),
            color: Colors.black.withOpacity(0.18),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.royalBlue.withOpacity(0.12),
                ),
                child: Icon(
                  _deviceIcon(device.platform),
                  color: AppColors.royalBlue,
                  size: 27,
                ),
              ),

              SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            device.deviceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.themeText,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        if (device.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: AppColors.royalBlue.withOpacity(0.12),
                            ),
                            child: Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: AppColors.royalBlue,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ),
                      ],
                    ),

                    SizedBox(height: 5),

                    Text(
                      _deviceType(device),
                      style: TextStyle(
                        color: AppColors.themeText.withOpacity(0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                _infoRow(
                  Icons.access_time_rounded,
                  'Last active',
                  _lastActiveText(device.lastActiveAt),
                ),

                if (device.ipAddress != null) ...[
                  SizedBox(height: 10),
                  _infoRow(
                    Icons.language_rounded,
                    'IP address',
                    device.ipAddress!,
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _isRevoking ? null : () => _revokeDevice(device),
              icon: _isRevoking
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.neonPink,
                      ),
                    )
                  : Icon(Icons.logout_rounded, size: 18),
              label: Text(_isRevoking ? 'Revoking...' : 'Revoke Device'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.neonPink,
                side: BorderSide(color: AppColors.neonPink.withOpacity(0.45)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.themeText.withOpacity(0.45)),
        SizedBox(width: 9),
        Text(
          label,
          style: TextStyle(
            color: AppColors.themeText.withOpacity(0.48),
            fontSize: 11.5,
          ),
        ),
        Spacer(),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.themeText,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SECURITY INFO
  // ============================================================

  Widget _buildSecurityInfo() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.themeText.withOpacity(0.035),
        border: Border.all(color: AppColors.themeText.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.themeText.withOpacity(0.45),
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'If you do not recognize a device, '
              'revoke it immediately and change '
              'your password.',
              style: TextStyle(
                color: AppColors.themeText.withOpacity(0.55),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
