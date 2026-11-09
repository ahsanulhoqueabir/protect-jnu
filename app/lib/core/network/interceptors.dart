import 'package:dio/dio.dart';

import '../utils/logger.dart';

/// Refreshes the stored session. Returns true when new tokens are stored, false when the
/// server rejected the refresh token. Throws on network trouble (the session is kept).
typedef TokenRefresher = Future<bool> Function();

/// Adds `Authorization: Bearer <token>`. On 401 it refreshes the session once and replays the
/// request; if that fails (or the replay is still 401) the user is signed out.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(
    this._dio,
    this._readToken, {
    required this.refresh,
    required this.onSessionExpired,
  });

  final Dio _dio;
  final String? Function() _readToken;
  final TokenRefresher refresh;
  final void Function() onSessionExpired;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    final sent = request.headers['Authorization'];
    // Only a rejected Bearer token counts; a failed login carries no Authorization header.
    if (err.response?.statusCode != 401 || sent == null) return handler.next(err);

    if (request.extra['retried'] == true) {
      onSessionExpired();
      return handler.next(err);
    }

    // A concurrent request may already have refreshed: then just replay with the new token.
    final current = _readToken();
    var refreshed = current != null && sent != 'Bearer $current';
    if (!refreshed) {
      try {
        refreshed = await refresh();
      } on Object {
        return handler.next(err); // Offline or server down: keep the session.
      }
    }
    if (!refreshed) {
      onSessionExpired();
      return handler.next(err);
    }

    request.extra['retried'] = true;
    request.headers['Authorization'] = 'Bearer ${_readToken()}';
    try {
      handler.resolve(await _dio.fetch<dynamic>(request));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

/// Logs requests and responses. Enabled by `ENABLE_HTTP_LOGS`.
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.debug('-> ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    AppLogger.debug('<- ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.error('x ${err.requestOptions.method} ${err.requestOptions.uri}', err.message);
    handler.next(err);
  }
}
