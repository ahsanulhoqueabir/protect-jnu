import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protect_jnu/core/network/interceptors.dart';

/// Fake HTTP layer: a request is accepted only with `Bearer good`.
class _Adapter implements HttpClientAdapter {
  final seen = <String?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<List<int>>? body,
    Future<void>? cancel,
  ) async {
    final auth = o.headers['Authorization'] as String?;
    seen.add(auth);
    final ok = auth == 'Bearer good';
    return ResponseBody.fromString(
      ok ? '{"success":true}' : '{"success":false,"code":"invalid_token"}',
      ok ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late String? token;
  late int refreshCalls;
  late int expiredCalls;
  late _Adapter adapter;
  late Dio dio;

  Dio build(Future<bool> Function() refresh) {
    final d = Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = adapter;
    d.interceptors.add(
      AuthInterceptor(d, () => token, refresh: refresh, onSessionExpired: () => expiredCalls++),
    );
    return d;
  }

  setUp(() {
    token = 'stale';
    refreshCalls = 0;
    expiredCalls = 0;
    adapter = _Adapter();
  });

  test('401 refreshes once and replays the request with the new token', () async {
    dio = build(() async {
      refreshCalls++;
      token = 'good';
      return true;
    });
    final res = await dio.get<dynamic>('/me');
    expect(res.statusCode, 200);
    expect(refreshCalls, 1);
    expect(adapter.seen, ['Bearer stale', 'Bearer good']);
    expect(expiredCalls, 0);
  });

  test('a rejected refresh signs the user out', () async {
    dio = build(() async => false);
    await expectLater(dio.get<dynamic>('/me'), throwsA(isA<DioException>()));
    expect(expiredCalls, 1);
  });

  test('a network failure during refresh keeps the session', () async {
    dio = build(() async => throw Exception('offline'));
    await expectLater(dio.get<dynamic>('/me'), throwsA(isA<DioException>()));
    expect(expiredCalls, 0);
  });

  test('still 401 after a successful refresh signs out and does not loop', () async {
    dio = build(() async {
      refreshCalls++;
      token = 'also-bad';
      return true;
    });
    await expectLater(dio.get<dynamic>('/me'), throwsA(isA<DioException>()));
    expect(refreshCalls, 1);
    expect(expiredCalls, 1);
  });

  test('a 401 without a token (failed login) never triggers refresh or sign-out', () async {
    token = null;
    dio = build(() async {
      refreshCalls++;
      return true;
    });
    await expectLater(dio.post<dynamic>('/login'), throwsA(isA<DioException>()));
    expect(refreshCalls, 0);
    expect(expiredCalls, 0);
  });
}
