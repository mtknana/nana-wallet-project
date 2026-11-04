import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  // ============================================================
  // CHECK BIOMETRIC AVAILABILITY
  // ============================================================

  static Future<bool> isAvailable() async {
    try {
      final bool canCheckBiometrics = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();

      return canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // GET AVAILABLE BIOMETRICS
  // ============================================================

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // FINGERPRINT DETECTION
  // ============================================================

  static bool hasFingerprint(List<BiometricType> biometrics) {
    return biometrics.contains(BiometricType.fingerprint);
  }

  // ============================================================
  // FACE ID / FACE BIOMETRIC DETECTION
  // ============================================================

  static bool hasFaceId(List<BiometricType> biometrics) {
    return biometrics.contains(BiometricType.face);
  }

  // ============================================================
  // BIOMETRIC NAME
  // ============================================================

  static String getBiometricName(List<BiometricType> biometrics) {
    if (hasFaceId(biometrics)) {
      return 'Face ID';
    }

    if (hasFingerprint(biometrics)) {
      return 'Fingerprint';
    }

    if (biometrics.isNotEmpty) {
      return 'Biometric Authentication';
    }

    return 'Not Available';
  }

  // ============================================================
  // AUTHENTICATE
  // ============================================================

  static Future<bool> authenticate({
    String reason = 'Verify your identity to continue.',
  }) async {
    try {
      final bool available = await isAvailable();

      if (!available) {
        return false;
      }

      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      return false;
    }
  }
}
