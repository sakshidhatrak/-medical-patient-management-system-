import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/error/exceptions.dart';
import '../models/user_model.dart';

abstract interface class AuthRemoteDataSource {
  Future<UserModel> login({required String email, required String password});
  Future<UserModel> fetchUserProfile(String userId);
  Future<void> logout();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final sb.SupabaseClient _client;

  const AuthRemoteDataSourceImpl(this._client);

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) {
        throw const UnauthorizedException(
          'Login failed.',
          code: 'LOGIN_FAILED',
        );
      }
      return fetchUserProfile(response.user!.id);
    } on sb.AuthException catch (e) {
      throw UnauthorizedException(e.message, code: 'AUTH_ERROR');
    }
  }

  @override
  Future<UserModel> fetchUserProfile(String userId) async {
    try {
      final data = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      return UserModel.fromJson(data as Map<String, dynamic>);
    } on sb.PostgrestException catch (e) {
      throw ServerException(e.message, code: 'PROFILE_FETCH_ERROR');
    }
  }

  @override
  Future<void> logout() async {
    await _client.auth.signOut();
  }
}
