import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protect_jnu/core/network/api_exception.dart';
import 'package:protect_jnu/features/auth/data/auth_repository.dart';
import 'package:protect_jnu/features/auth/otp_controller.dart';

import '../../helpers/fakes.dart';

CodedApiException coded(String code, {int status = 400, Map<String, dynamic>? details}) =>
    CodedApiException(
      statusCode: status,
      code: code,
      message: 'msg for $code',
      details: details ?? const {},
    );

void main() {
  late MockAuthRepository repo;
  const args = OtpArgs(email: 'a@cse.jnu.ac.bd', purpose: 'email_verification', justSent: true);

  ProviderContainer make() {
    final c = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    c.listen(otpControllerProvider(args), (_, _) {}); // keep the autoDispose provider alive
    return c;
  }

  OtpState read(ProviderContainer c) => c.read(otpControllerProvider(args));
  OtpController ctl(ProviderContainer c) => c.read(otpControllerProvider(args).notifier);

  setUp(() => repo = MockAuthRepository());

  test('starts as sent with the 60 s resend cooldown running', () {
    final s = read(make());
    expect(s.status, OtpStatus.sent);
    expect(s.resendSeconds, 60);
    expect(s.canResend, isFalse);
  });

  test('countdown reaches zero and enables resend', () {
    fakeAsync((async) {
      final c = make();
      async.elapse(const Duration(seconds: 30));
      expect(read(c).resendSeconds, 30);
      async.elapse(const Duration(seconds: 31));
      expect(read(c).resendSeconds, 0);
      expect(read(c).canResend, isTrue);
    });
  });

  test('a correct code ends in verified', () async {
    when(
      () => repo.verifyOtp(
        email: any(named: 'email'),
        code: '123456',
      ),
    ).thenAnswer((_) async {});
    final c = make();
    expect(await ctl(c).submit(() => repo.verifyOtp(email: args.email, code: '123456')), isTrue);
    expect(read(c).status, OtpStatus.verified);
  });

  test('wrong code reports attempts remaining', () async {
    final c = make();
    await ctl(c).submit(() async => throw coded('otp_invalid', details: {'attempts_remaining': 3}));
    expect(read(c).status, OtpStatus.invalid);
    expect(read(c).attemptsRemaining, 3);
  });

  test('expired and missing codes both read as expired', () async {
    for (final code in ['otp_expired', 'otp_not_found']) {
      final c = make();
      await ctl(c).submit(() async => throw coded(code));
      expect(read(c).status, OtpStatus.expired, reason: code);
    }
  });

  test('after 5 wrong attempts the form is locked until a new code is requested', () async {
    final c = make();
    await ctl(c).submit(() async => throw coded('otp_attempts_exceeded'));
    expect(read(c).status, OtpStatus.attemptsExceeded);
    expect(read(c).canSubmit, isFalse);
    // Submitting while locked does not call the server.
    var called = false;
    await ctl(c).submit(() async => called = true);
    expect(called, isFalse);
  });

  test('server rate limit disables resend for the server-given time', () {
    fakeAsync((async) {
      final c = make();
      async.elapse(const Duration(seconds: 61));
      when(() => repo.resendOtp(email: args.email, purpose: args.purpose))
          .thenThrow(coded('otp_send_limit', status: 429, details: {'retry_after_seconds': 120}));
      ctl(c).resend();
      async.flushMicrotasks();
      expect(read(c).status, OtpStatus.rateLimited);
      expect(read(c).resendSeconds, 120);
      expect(read(c).canResend, isFalse);
    });
  });

  test('resend success restarts the cooldown and clears an old error', () {
    fakeAsync((async) {
      final c = make();
      async.elapse(const Duration(seconds: 61));
      when(() => repo.resendOtp(email: args.email, purpose: args.purpose))
          .thenAnswer((_) async => 60);
      ctl(c).resend();
      async.flushMicrotasks();
      expect(read(c).status, OtpStatus.sent);
      expect(read(c).resendSeconds, 60);
    });
  });

  test('unknown failures become a safe failure state', () async {
    final c = make();
    await ctl(c).submit(() async => throw const NetworkException());
    expect(read(c).status, OtpStatus.failure);
    await ctl(c).submit(() async => throw StateError('internal detail'));
    expect(read(c).message, 'Something went wrong. Please try again.');
  });
}
