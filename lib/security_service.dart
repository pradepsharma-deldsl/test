import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  SecurityService._();
  static final SecurityService instance = SecurityService._();

  static const _storage = FlutterSecureStorage();
  static const _pinHashKey = 'pin_hash_v2';
  static const _pinSaltKey = 'pin_salt_v2';
  static const _dbKeyKey = 'db_key';
  static const _biometricEnabledKey = 'biometric_enabled';
  static const _powerSaverKey = 'power_saver_enabled';

  final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 210000,
    bits: 256,
  );

  Future<bool> hasPin() => _storage.containsKey(key: _pinHashKey);

  Future<void> createPin(String pin) async {
    _validatePin(pin);
    final salt = _randomBytes(16);
    final hash = await _derive(pin, salt);
    await _storage.write(key: _pinSaltKey, value: base64Encode(salt));
    await _storage.write(key: _pinHashKey, value: base64Encode(hash));

    if (!await _storage.containsKey(key: _dbKeyKey)) {
      await setDatabaseKey(base64UrlEncode(_randomBytes(32)));
    }
  }

  Future<bool> verifyPin(String pin) async {
    final saltB64 = await _storage.read(key: _pinSaltKey);
    final expectedB64 = await _storage.read(key: _pinHashKey);
    if (saltB64 == null || expectedB64 == null) return false;
    try {
      final actual = await _derive(pin, base64Decode(saltB64));
      final expected = base64Decode(expectedB64);
      if (actual.length != expected.length) return false;
      var diff = 0;
      for (var i = 0; i < actual.length; i++) {
        diff |= actual[i] ^ expected[i];
      }
      return diff == 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> changePin(String currentPin, String newPin) async {
    if (!await verifyPin(currentPin)) {
      throw StateError('Current PIN/password is incorrect.');
    }
    _validatePin(newPin);
    final salt = _randomBytes(16);
    final hash = await _derive(newPin, salt);
    await _storage.write(key: _pinSaltKey, value: base64Encode(salt));
    await _storage.write(key: _pinHashKey, value: base64Encode(hash));
  }

  Future<String?> getDatabaseKey() => _storage.read(key: _dbKeyKey);

  Future<void> setDatabaseKey(String value) async {
    if (value.isEmpty) throw ArgumentError('Database key cannot be empty.');
    await _storage.write(key: _dbKeyKey, value: value);
  }

  Future<bool> isBiometricEnabled() async =>
      (await _storage.read(key: _biometricEnabledKey)) == 'true';

  Future<void> setBiometricEnabled(bool enabled) =>
      _storage.write(key: _biometricEnabledKey, value: enabled.toString());

  Future<bool> isPowerSaverEnabled() async {
    final value = await _storage.read(key: _powerSaverKey);
    return value == null ? true : value == 'true';
  }

  Future<void> setPowerSaverEnabled(bool enabled) =>
      _storage.write(key: _powerSaverKey, value: enabled.toString());

  Future<bool> canUseBiometrics() async {
    try {
      final auth = LocalAuthentication();
      return await auth.isDeviceSupported() && await auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric() async {
    if (!await isBiometricEnabled()) return false;
    try {
      final auth = LocalAuthentication();
      return await auth.authenticate(
        localizedReason: 'Unlock your encrypted documents',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<List<int>> deriveBackupKey(String password, List<int> salt) async {
    if (password.length < 8) {
      throw ArgumentError('Backup password must be at least 8 characters.');
    }
    return _derive(password, salt);
  }

  Future<List<int>> _derive(String secret, List<int> salt) async {
    final key = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(secret)),
      nonce: salt,
    );
    return key.extractBytes();
  }

  List<int> randomBytes(int length) => _randomBytes(length);

  List<int> _randomBytes(int length) {
    final rng = Random.secure();
    return List<int>.generate(length, (_) => rng.nextInt(256));
  }

  void _validatePin(String pin) {
    if (pin.trim().length < 6) {
      throw ArgumentError('PIN/password must be at least 6 characters.');
    }
  }
}
