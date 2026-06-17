import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AppLockService {
  static const _storage = FlutterSecureStorage();
  static final _localAuth = LocalAuthentication();
  static const _pinKey = 'app_lock_pin';

  static Future<bool> hasPinSet() async =>
      await _storage.read(key: _pinKey) != null;

  static Future<void> savePin(String pin) async =>
      _storage.write(key: _pinKey, value: pin);

  static Future<void> clearPin() async => _storage.delete(key: _pinKey);

  static Future<bool> verifyPin(String pin) async =>
      await _storage.read(key: _pinKey) == pin;

  static Future<bool> isBiometricAvailable() async =>
      await _localAuth.canCheckBiometrics;

  static Future<bool> authenticateWithBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock to open this note',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
