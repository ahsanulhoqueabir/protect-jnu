import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/forms/validators.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/feedback/app_feedback.dart';
import '../../../shared/widgets/forms/app_password_field.dart';
import '../data/auth_repository.dart';
import '../otp_controller.dart';
import 'widgets/auth_layout.dart';
import 'widgets/otp_boxes.dart';
import 'widgets/otp_status_text.dart';

/// Step 2 of password reset: the emailed code plus the new password (api-contract /reset-password).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();

  // The forgot-password step just sent a code, so the 60 s cooldown is already running.
  OtpArgs get _args => OtpArgs(email: widget.email, purpose: 'password_reset', justSent: true);

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final codeOk = Validators.otpCode()(_code.text) == null && _code.text.length == 6;
    if (!_formKey.currentState!.validate() || !codeOk) {
      if (!codeOk) {
        showAppSnack(context, 'Enter the 6-digit code from your email.', type: SnackType.error);
      }
      return;
    }
    final ok = await ref
        .read(otpControllerProvider(_args).notifier)
        .submit(
          () => ref
              .read(authRepositoryProvider)
              .resetPassword(email: widget.email, code: _code.text, newPassword: _password.text),
        );
    if (!mounted) return;
    if (ok) {
      showAppSnack(
        context,
        'Password changed. Sign in with your new password.',
        type: SnackType.success,
      );
      context.go(Routes.login);
    } else {
      _code.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(otpControllerProvider(_args));
    final controller = ref.read(otpControllerProvider(_args).notifier);
    final isError =
        state.status == OtpStatus.invalid ||
        state.status == OtpStatus.expired ||
        state.status == OtpStatus.attemptsExceeded;

    return AuthLayout(
      title: 'Choose a new password',
      subtitle: 'Enter the code sent to ${widget.email}.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OtpBoxes(controller: _code, enabled: state.canSubmit, hasError: isError),
            const Gap(AppSpacing.md),
            OtpStatusText(state: state),
            const Gap(AppSpacing.md),
            AppPasswordField(
              controller: _password,
              label: 'New password',
              showStrength: true,
              isNewPassword: true,
              onSubmitted: (_) => _submit(),
              validator: Validators.compose([
                Validators.required('Choose a password'),
                Validators.newPassword(),
              ]),
            ),
            const Gap(AppSpacing.lg),
            AppButton(
              label: 'Change password',
              onPressed: state.canSubmit ? _submit : null,
              isLoading: state.status == OtpStatus.working,
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
      ),
    );
  }
}
