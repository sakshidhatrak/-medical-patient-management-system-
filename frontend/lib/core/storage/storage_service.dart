import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class StorageService {
  Future<void> write({required String key, required String? value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
  Future<void> deleteAll();
}

/// Native (iOS/Android) — values encrypted via Keychain / EncryptedSharedPrefs.
class SecureStorageService implements StorageService {
  final FlutterSecureStorage _s;
  const SecureStorageService(this._s);

  @override
  Future<void> write({required String key, required String? value}) =>
      _s.write(key: key, value: value);

  @override
  Future<String?> read({required String key}) => _s.read(key: key);

  @override
  Future<void> delete({required String key}) => _s.delete(key: key);

  @override
  Future<void> deleteAll() => _s.deleteAll();
}

/// Web — values stored in SharedPreferences (backed by localStorage).
/// Prefixed with [_ns] to avoid colliding with other SharedPreferences keys.
class WebStorageService implements StorageService {
  final SharedPreferences _p;
  static const _ns = '_app_storage_';

  const WebStorageService(this._p);

  @override
  Future<void> write({required String key, required String? value}) async {
    if (value == null) {
      await _p.remove(_ns + key);
    } else {
      await _p.setString(_ns + key, value);
    }
  }

  @override
  Future<String?> read({required String key}) async =>
      _p.getString(_ns + key);

  @override
  Future<void> delete({required String key}) async =>
      _p.remove(_ns + key);

  @override
  Future<void> deleteAll() async {
    final dead = _p.getKeys().where((k) => k.startsWith(_ns)).toList();
    for (final k in dead) {
      await _p.remove(k);
    }
  }
}
