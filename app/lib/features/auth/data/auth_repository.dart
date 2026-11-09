import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/storage/token_store.dart';
import '../domain/user.dart';

/// An interface so tests can fake the backend. Endpoints and shapes: docs/api-contract.md.
abstract interface class AuthRepository {
  Future<void> register({
    required String fullName,
    required String studentId,
    required String email,
    required String password,
  });

  /// Marks the email verified. Returns no session (R1): call [login] afterwards.
  Future<void> verifyOtp({required String email, required String code});

  /// Returns the seconds until another code may be requested.
  Future<int> resendOtp({required String email, required String purpose});

  Future<AuthSession> login({required String email, required String password});
  Future<AuthTokens> refresh(String refreshToken);
  Future<void> logout();
  Future<User> me();
  Future<int> forgotPassword(String email);
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api);

  final ApiClient _api;

  /// Unwraps `{ "success": true, "data": {...} }`.
  Map<String, dynamic> _data(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    throw const BadResponseException();
  }

  AuthTokens _tokens(Map<String, dynamic> session) => AuthTokens.fromJson(session);

  @override
  Future<void> register({
    required String fullName,
    required String studentId,
    required String email,
    required String password,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/api/auth/register',
      data: {
        'full_name': fullName,
        'student_id': studentId.trim().toUpperCase(),
        'email': email,
        'password': password,
      },
    );
  }

  @override
  Future<void> verifyOtp({required String email, required String code}) async {
    await _api.post<Map<String, dynamic>>(
      '/api/auth/verify-otp',
      data: {'email': email, 'code': code, 'purpose': 'email_verification'},
    );
  }

  @override
  Future<int> resendOtp({required String email, required String purpose}) async {
    final body = await _api.post<Map<String, dynamic>>(
      '/api/auth/resend-otp',
      data: {'email': email, 'purpose': purpose},
    );
    return (_data(body)['resend_available_in'] as num?)?.toInt() ?? 60;
  }

  @override
  Future<AuthSession> login({required String email, required String password}) async {
    final body = await _api.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = _data(body);
    return (
      tokens: _tokens(data['session'] as Map<String, dynamic>),
      user: User.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    final body = await _api.post<Map<String, dynamic>>(
      '/api/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    return _tokens(_data(body)['session'] as Map<String, dynamic>);
  }

  @override
  Future<void> logout() async {
    await _api.post<Map<String, dynamic>>('/api/auth/logout');
  }

  @override
  Future<User> me() async {
    final body = await _api.get<Map<String, dynamic>>('/api/auth/me');
    return User.fromJson(_data(body)['user'] as Map<String, dynamic>);
  }

  @override
  Future<int> forgotPassword(String email) async {
    final body = await _api.post<Map<String, dynamic>>(
      '/api/auth/forgot-password',
      data: {'email': email},
    );
    return (_data(body)['resend_available_in'] as num?)?.toInt() ?? 60;
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/api/auth/reset-password',
      data: {'email': email, 'code': code, 'new_password': newPassword},
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(ref.watch(apiClientProvider)),
);
