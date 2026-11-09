import 'package:flutter/material.dart';

import '../../otp_controller.dart';

/// One line under the code boxes that reflects the [OtpState] (FR-AUTH-6).
class OtpStatusText extends StatelessWidget {
  const OtpStatusText({super.key, required this.state});

  final OtpState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (text, color) = switch (state.status) {
      OtpStatus.ready => ('', colors.onSurfaceVariant),
      OtpStatus.working => ('Please wait…', colors.onSurfaceVariant),
      OtpStatus.sent => ('A new code was sent. Check your inbox.', colors.primary),
      OtpStatus.verified => ('Verified.', colors.primary),
      OtpStatus.invalid => (
        '${state.message ?? 'That code is not correct.'}'
            '${state.attemptsRemaining == null ? '' : ' ${state.attemptsRemaining} attempts left.'}',
        colors.error,
      ),
      OtpStatus.expired ||
      OtpStatus.attemptsExceeded ||
      OtpStatus.failure => (state.message ?? 'Something went wrong.', colors.error),
      OtpStatus.rateLimited => (
        '${state.message ?? 'Too many requests.'} Try again in ${state.resendSeconds}s.',
        colors.error,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: color),
      ),
    );
  }
}
