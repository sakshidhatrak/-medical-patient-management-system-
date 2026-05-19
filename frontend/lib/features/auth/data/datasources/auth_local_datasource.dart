import 'dart:convert';

import '../../../../core/error/exceptions.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/config/app_config.dart';
import '../models/user_model.dart';

abstract interface class AuthLocalDataSource {
  Future<void> saveToken({
    required String token,
    required String refreshToken,
  });

  Future<void> saveUser(UserModel user);

  Future<UserModel?> getUser();

  Future<void> clearAll();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final StorageService _storage;

  const AuthLocalDataSourceImpl(this._storage);

  @override
  Future<void> saveToken({
    required String token,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: AppConfig.tokenKey, value: token),
      _storage.write(key: AppConfig.refreshTokenKey, value: refreshToken),
    ]);
  }

  @override
  Future<void> saveUser(UserModel user) async {
    await _storage.write(
      key: AppConfig.userKey,
      value: jsonEncode(user.toJson()),
    );
  }

  @override
  Future<UserModel?> getUser() async {
    try {
      final json = await _storage.read(key: AppConfig.userKey);
      if (json == null) return null;
      return UserModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      throw const CacheException(
        'Failed to read cached user.',
        code: 'CACHE_READ_ERROR',
      );
    }
  }

  @override
  Future<void> clearAll() => _storage.deleteAll();
}
