import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/storage/storage_providers.dart';
import '../../core/utils/logger.dart';
import 'data/auth_repository.dart';
import 'domain/user.dart';

/// The signed-in user, or `null` when signed out. The router listens to this.
final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(AuthNotifier.new);

/// Credentials held IN MEMORY only while the user verifies their email, so the app can log in
/// right after `/verify-otp` (api-contract R1). Never persisted, never logged.
class PendingVerification {
  const PendingVerification({required this.email, required this.password});
  final String email;
  final String password;
}

final pendingVerificationProvider =
    NotifierProvider<PendingVerificationNotifier, PendingVerification?>(
      PendingVerificationNotifier.new,
    );

class PendingVerificationNotifier extends Notifier<PendingVerification?> {
  @override
  PendingVerification? build() => null;

  void set(PendingVerification value) => state = value;
  void clear() => state = null;
}

class AuthNotifier extends AsyncNotifier<User?> {
  Future<bool>? _refreshing;

  @override
  Future<User?> build() async {
    final tokens = ref.watch(tokenStoreProvider).tokens;
    if (tokens == null) return null;

    final storage = ref.watch(localStorageProvider);
    // A cached user lets the app open instantly, including offline.
    final cached = _parseCachedUser(storage.user);
    if (cached != null) return cached;

    try {
      final user = await ref.read(authRepositoryProvider).me();
      await storage.setUser(user.toJson());
      return user;
    } on ApiException catch (e) {
      AppLogger.error('Could not restore session', e);
      final rejected = e is CodedApiException && e.statusCode >= 400 && e.statusCode < 500;
      if (rejected || e is UnauthorizedException) await _clearLocal();
      return null;
    }
  }

  User? _parseCachedUser(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      return User.fromJson(json);
    } on Object {
      return null; // Cache written by an older app version.
    }
  }

  /// Throws [CodedApiException] with `email_not_verified` (403) for an unverified account.
  Future<void> login({required String email, required String password}) async {
    final session = await ref
        .read(authRepositoryProvider)
        .login(email: _normalizeEmail(email), password: password);
    await ref.read(tokenStoreProvider).save(session.tokens);
    await ref.read(localStorageProvider).setUser(session.user.toJson());
    ref.read(pendingVerificationProvider.notifier).clear();
    state = AsyncData(session.user);
  }

  /// Rotates the session. One refresh at a time: concurrent callers share the same Future.
  /// Returns false if the server rejected the refresh token. Throws on network problems.
  Future<bool> refreshTokens() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _doRefresh() async {
    final store = ref.read(tokenStoreProvider);
    final current = store.tokens;
    if (current == null) return false;
    try {
      final fresh = await ref.read(authRepositoryProvider).refresh(current.refreshToken);
      await store.save(fresh);
      return true;
    } on CodedApiException catch (e) {
      if (e.statusCode == 401) return false;
      rethrow;
    }
  }

  /// The current access token, refreshed first if it expires within a minute. For Supabase calls.
  Future<String?> freshAccessToken() async {
    final store = ref.read(tokenStoreProvider);
    final tokens = store.tokens;
    if (tokens == null) return null;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (tokens.expiresAt - nowSeconds < 60) {
      try {
        await refreshTokens();
      } on Object catch (e) {
        AppLogger.error('Token refresh before Supabase call failed', e);
      }
    }
    return store.accessToken;
  }

  Future<void> logout() async {
    // Best effort: revoke on the server, but always sign out locally.
    try {
      if (ref.read(tokenStoreProvider).tokens != null) {
        await ref.read(authRepositoryProvider).logout();
      }
    } on Object catch (e) {
      AppLogger.error('Server logout failed', e);
    }
    await expireSession();
  }

  /// Local sign-out without calling the server (the server already rejected the session).
  Future<void> expireSession() async {
    await _clearLocal();
    state = const AsyncData(null);
  }

  Future<void> _clearLocal() async {
    await ref.read(tokenStoreProvider).clear();
    await ref.read(localStorageProvider).clearSession();
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();
}

/// Current user id. Providers holding per-user data watch this, so their cache
/// resets when the user changes and one account never sees another's data.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authProvider.select((auth) => auth.value?.id)),
);
