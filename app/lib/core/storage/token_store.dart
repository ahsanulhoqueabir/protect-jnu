import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Supabase session tokens issued by our login API. Values are secrets: never log them.
@immutable
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String,
    expiresAt: (json['expires_at'] as num).toInt(),
  );

  final String accessToken;
  final String refreshToken;

  /// Unix seconds.
  final int expiresAt;

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_at': expiresAt,
  };

  @override
  String toString() => 'AuthTokens(<redacted>)';
}

/// Encrypted token storage (D-005/D-054) with an in-memory copy so interceptors can read the
/// token synchronously. Pass `storage: null` for an in-memory store (tests).
class TokenStore {
  TokenStore({this._storage, AuthTokens? initial}) : _tokens = initial;

  static const _key = 'auth_tokens';

  final FlutterSecureStorage? _storage;
  AuthTokens? _tokens;

  /// Reads the persisted tokens. A corrupt or unreadable entry counts as signed out.
  static Future<TokenStore> load(FlutterSecureStorage storage) async {
    AuthTokens? tokens;
    try {
      final raw = await storage.read(key: _key);
      if (raw != null) tokens = AuthTokens.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      tokens = null;
    }
    return TokenStore(storage: storage, initial: tokens);
  }

  AuthTokens? get tokens => _tokens;
  String? get accessToken => _tokens?.accessToken;

  Future<void> save(AuthTokens tokens) async {
    _tokens = tokens;
    await _storage?.write(key: _key, value: jsonEncode(tokens.toJson()));
  }

  Future<void> clear() async {
    _tokens = null;
    try {
      await _storage?.delete(key: _key);
    } on Object {
      // Memory copy is already cleared; a failed delete must not block sign-out.
    }
  }
}
