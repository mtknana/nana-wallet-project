import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
import 'package:digital_wallet_app/features/wallet/services/biometric_service.dart';

enum TransactionVerificationMethod { pin, biometric, cancelled }

class TransactionVerificationDialog extends StatefulWidget {
  final String token;

  TransactionVerificationDialog({super.key, required this.token});

  @override
  State<TransactionVerificationDialog> createState() =>
      _TransactionVerificationDialogState();
}

class _TransactionVerificationDialogState
    extends State<TransactionVerificationDialog> {
  bool _checkingBiometric = true;
  bool _biometricAvailable = false;
  String _biometricName = 'Biometric Authentication';

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    try {
      final available = await BiometricService.isAvailable();

      if (!available) {
        if (!mounted) return;

        setState(() {
          _checkingBiometric = false;
          _biometricAvailable = false;
        });

        return;
      }

      final biometrics = await BiometricService.getAvailableBiometrics();

      final name = BiometricService.getBiometricName(biometrics);

      if (!mounted) return;

      setState(() {
        _checkingBiometric = false;
        _biometricAvailable = true;
        _biometricName = name;
      });
    } catch (e) {
      debugPrint('⚠️ Biometric availability check failed: $e');

      if (!mounted) return;

      setState(() {
        _checkingBiometric = false;
        _biometricAvailable = false;
      });
    }
  }

  void _selectPin() {
    Navigator.pop(context, TransactionVerificationMethod.pin);
  }

  Future<void> _selectBiometric() async {
    if (_checkingBiometric || !_biometricAvailable) {
      return;
    }

    final verified = await BiometricService.authenticate(
      reason: 'Verify your identity to authorize this transaction.',
    );

    if (!mounted) return;

    if (verified) {
      Navigator.pop(context, TransactionVerificationMethod.biometric);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Biometric verification failed or was cancelled.'),
        ),
      );
    }
  }

  void _cancel() {
    Navigator.pop(context, TransactionVerificationMethod.cancelled);
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOnTheme(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Color(0xFF101827),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.themeText.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 35,
              offset: Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ----------------------------------------------------
            // ICON
            // ----------------------------------------------------
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.20),
                    blurRadius: 22,
                  ),
                ],
              ),
              child: Icon(
                LucideIcons.shieldCheck,
                color: AppColors.themeText,
                size: 30,
              ),
            ),

            SizedBox(height: 18),

            // ----------------------------------------------------
            // TITLE
            // ----------------------------------------------------
            Text(
              'Verify Payment',
              style: TextStyle(
                color: AppColors.themeText,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),

            SizedBox(height: 7),

            Text(
              'Choose how you would like to authorize this transaction.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.themeText.withValues(alpha: 0.54),
                fontSize: 12,
                height: 1.4,
              ),
            ),

            SizedBox(height: 22),

            // ----------------------------------------------------
            // PIN
            // ----------------------------------------------------
            _buildMethodButton(
              icon: LucideIcons.keyRound,
              title: 'Transaction PIN',
              subtitle: 'Enter your secure transaction PIN',
              onTap: _selectPin,
            ),

            // ----------------------------------------------------
            // BIOMETRIC
            // ----------------------------------------------------
            if (_checkingBiometric)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppColors.themeText.withOpacity(0.035),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: AppColors.themeText.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.themeText.withValues(alpha: 0.54),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Checking biometric availability...',
                        style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.54), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              )
            else if (_biometricAvailable)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _buildMethodButton(
                  icon: _biometricName == 'Face ID'
                      ? LucideIcons.scanFace
                      : LucideIcons.fingerprint,
                  title: _biometricName,
                  subtitle: 'Verify using your device biometric',
                  onTap: _selectBiometric,
                ),
              ),

            SizedBox(height: 18),

            // ----------------------------------------------------
            // SECURITY MESSAGE
            // ----------------------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.lockKeyhole,
                  size: 13,
                  color: AppColors.royalBlue,
                ),
                SizedBox(width: 6),
                Text(
                  'Your transaction is protected',
                  style: TextStyle(color: AppColors.themeText.withValues(alpha: 0.38), fontSize: 10),
                ),
              ],
            ),

            SizedBox(height: 10),

            TextButton(
              onPressed: _cancel,
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.themeText.withValues(alpha: 0.54),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // METHOD BUTTON
  // ============================================================

  Widget _buildMethodButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.themeText.withOpacity(0.035),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.themeText.withOpacity(0.07)),
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: AppColors.royalBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.royalBlue, size: 21),
              ),

              SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.themeText,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.themeText.withValues(alpha: 0.38),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                LucideIcons.chevronRight,
                color: AppColors.themeText.withValues(alpha: 0.30),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
