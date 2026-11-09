import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/feedback/app_feedback.dart';
import '../auth_providers.dart';
import '../data/auth_repository.dart';
import '../otp_controller.dart';
import 'widgets/auth_layout.dart';
import 'widgets/otp_boxes.dart';
import 'widgets/otp_status_text.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email, this.justSent = false});

  final String email;
  final bool justSent;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _code = TextEditingController();

  OtpArgs get _args =>
      OtpArgs(email: widget.email, purpose: 'email_verification', justSent: widget.justSent);

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _code.text;
    if (code.length != 6) return;
    final controller = ref.read(otpControllerProvider(_args).notifier);
    final ok = await controller.submit(
      () => ref.read(authRepositoryProvider).verifyOtp(email: widget.email, code: code),
    );
    if (!ok) {
      _code.clear();
      return;
    }
    if (!mounted) return;
    final pending = ref.read(pendingVerificationProvider);
    if (pending == null || pending.email != widget.email) {
      // App was restarted: the password is gone, so sign in manually.
      showAppSnack(context, 'Email verified. Sign in to continue.', type: SnackType.success);
      context.go(Routes.login);
      return;
    }
    // api-contract R1: verification returns no session, so sign in with the password we hold.
    // On success the router redirects onward.
    try {
      await ref.read(authProvider.notifier).login(email: pending.email, password: pending.password);
    } on Object catch (e) {
      if (!mounted) return;
      showAppSnack(context, userMessage(e), type: SnackType.error);
      context.go(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(otpControllerProvider(_args));
    final controller = ref.read(otpControllerProvider(_args).notifier);
    final working = state.status == OtpStatus.working;
    final isError =
        state.status == OtpStatus.invalid ||
        state.status == OtpStatus.expired ||
        state.status == OtpStatus.attemptsExceeded;

    return AuthLayout(
      title: 'Verify your email',
      subtitle: widget.justSent
          ? 'We sent a 6-digit code to ${widget.email}.'
          : 'Enter the 6-digit code sent to ${widget.email}, or request a new one.',
      footer: AuthFooterLink(
        question: 'Wrong address?',
        action: 'Start over',
        onTap: () {
          ref.read(pendingVerificationProvider.notifier).clear();
          context.go(Routes.register);
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OtpBoxes(
            controller: _code,
            enabled: state.canSubmit,
            hasError: isError,
            onCompleted: (_) => _verify(),
          ),
          const Gap(AppSpacing.md),
          OtpStatusText(state: state),
          const Gap(AppSpacing.lg),
          AppButton(
            label: 'Verify',
            onPressed: state.canSubmit ? _verify : null,
            isLoading: working,
          ),
          const Gap(AppSpacing.xs),
          AppButton(
            variant: AppButtonVariant.text,
            label: state.resendSeconds > 0
                ? 'Send a new code in ${state.resendSeconds}s'
                : 'Send a new code',
            onPressed: state.canResend ? controller.resend : null,
          ),
        ],
      ),
    );
  }
}
