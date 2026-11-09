import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/logger.dart';
import 'data/auth_repository.dart';

/// UI states required by FR-AUTH-6.
enum OtpStatus {
  ready,
  sent,
  working,
  invalid,
  expired,
  attemptsExceeded,
  rateLimited,
  verified,
  failure,
}

@immutable
class OtpState {
  const OtpState({
    this.status = OtpStatus.ready,
    this.message,
    this.attemptsRemaining,
    this.resendSeconds = 0,
  });

  final OtpStatus status;
  final String? message;
  final int? attemptsRemaining;

  /// Seconds until another code may be requested. 0 means the resend action is enabled.
  final int resendSeconds;

  bool get canResend => resendSeconds == 0 && status != OtpStatus.working;
  bool get canSubmit => status != OtpStatus.working && status != OtpStatus.attemptsExceeded;

  OtpState copyWith({
    OtpStatus? status,
    String? message,
    int? attemptsRemaining,
    int? resendSeconds,
  }) => OtpState(
    status: status ?? this.status,
    message: message,
    attemptsRemaining: attemptsRemaining,
    resendSeconds: resendSeconds ?? this.resendSeconds,
  );
}

/// Identifies one OTP screen: which email, which purpose, and whether a code was just sent.
@immutable
class OtpArgs {
  const OtpArgs({required this.email, required this.purpose, this.justSent = false});

  final String email;

  /// `email_verification` or `password_reset`.
  final String purpose;
  final bool justSent;

  @override
  bool operator ==(Object other) =>
      other is OtpArgs &&
      other.email == email &&
      other.purpose == purpose &&
      other.justSent == justSent;

  @override
  int get hashCode => Object.hash(email, purpose, justSent);
}

/// State machine for entering and re-requesting a one-time code. Server rules (10 min expiry,
/// 5 attempts, 60 s cooldown, 3 sends per 15 min) are enforced by the backend; this reflects them.
final otpControllerProvider = NotifierProvider.autoDispose.family<OtpController, OtpState, OtpArgs>(
  OtpController.new,
);

class OtpController extends Notifier<OtpState> {
  OtpController(this.args);

  final OtpArgs args;
  Timer? _timer;

  /// The server's cooldown (api-contract section 3).
  static const defaultCooldown = 60;

  @override
  OtpState build() {
    ref.onDispose(() => _timer?.cancel());
    if (args.justSent) {
      _startCountdown(defaultCooldown);
      return const OtpState(status: OtpStatus.sent, resendSeconds: defaultCooldown);
    }
    return const OtpState();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = state.resendSeconds - 1;
      if (left <= 0) timer.cancel();
      state = state.copyWith(
        status: state.status,
        message: state.message,
        attemptsRemaining: state.attemptsRemaining,
        resendSeconds: left < 0 ? 0 : left,
      );
    });
  }

  /// Runs the verify or reset call and maps every server answer onto an [OtpStatus].
  /// Returns true on success.
  Future<bool> submit(Future<void> Function() action) async {
    if (!state.canSubmit) return false;
    state = state.copyWith(status: OtpStatus.working, resendSeconds: state.resendSeconds);
    try {
      await action();
      state = state.copyWith(status: OtpStatus.verified, resendSeconds: state.resendSeconds);
      return true;
    } on ApiException catch (e) {
      state = _fromError(e);
      return false;
    } on Object catch (e) {
      AppLogger.error('OTP submit failed', e);
      state = state.copyWith(
        status: OtpStatus.failure,
        message: 'Something went wrong. Please try again.',
        resendSeconds: state.resendSeconds,
      );
      return false;
    }
  }

  /// Asks the server for a new code (invalidates the previous one).
  Future<void> resend() async {
    if (!state.canResend) return;
    state = state.copyWith(status: OtpStatus.working, resendSeconds: 0);
    try {
      final wait = await ref
          .read(authRepositoryProvider)
          .resendOtp(email: args.email, purpose: args.purpose);
      state = OtpState(status: OtpStatus.sent, resendSeconds: wait);
      _startCountdown(wait);
    } on ApiException catch (e) {
      state = _fromError(e);
    } on Object catch (e) {
      AppLogger.error('OTP resend failed', e);
      state = const OtpState(
        status: OtpStatus.failure,
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  OtpState _fromError(ApiException e) {
    final keep = state.resendSeconds;
    if (e is CodedApiException) {
      switch (e.code) {
        case 'otp_invalid':
          return OtpState(
            status: OtpStatus.invalid,
            message: e.message,
            attemptsRemaining: e.attemptsRemaining,
            resendSeconds: keep,
          );
        case 'otp_expired':
        case 'otp_not_found':
          return OtpState(
            status: OtpStatus.expired,
            message: 'This code has expired or is no longer valid. Request a new one.',
            resendSeconds: keep,
          );
        case 'otp_attempts_exceeded':
          return OtpState(
            status: OtpStatus.attemptsExceeded,
            message: 'Too many wrong attempts. Request a new code.',
            resendSeconds: keep,
          );
        case 'otp_resend_cooldown':
        case 'otp_send_limit':
          final wait = e.retryAfterSeconds ?? defaultCooldown;
          _startCountdown(wait);
          return OtpState(status: OtpStatus.rateLimited, message: e.message, resendSeconds: wait);
      }
    }
    return OtpState(status: OtpStatus.failure, message: e.message, resendSeconds: keep);
  }
}
