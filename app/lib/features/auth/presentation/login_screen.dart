import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/feedback/app_feedback.dart';
import '../../../shared/widgets/forms/app_password_field.dart';
import '../../../shared/widgets/forms/app_text_field.dart';
import '../auth_providers.dart';
import 'widgets/auth_layout.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // The keyboard's Done key bypasses the button, so guard double submits here.
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final email = _email.text.trim().toLowerCase();
    try {
      // On success the router redirects away from this screen.
      await ref.read(authProvider.notifier).login(email: email, password: _password.text);
    } on CodedApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'email_not_verified') {
        // Unverified accounts go to the OTP screen (FR-AUTH-7); the password stays in memory
        // only so the app can sign in right after verification.
        ref
            .read(pendingVerificationProvider.notifier)
            .set(PendingVerification(email: email, password: _password.text));
        context.go(Routes.verifyEmailFor(email));
      } else {
        showAppSnack(context, e.message, type: SnackType.error);
      }
    } on Object catch (e) {
      if (mounted) showAppSnack(context, userMessage(e), type: SnackType.error);
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Welcome back',
      subtitle: 'Sign in to continue.',
      footer: AuthFooterLink(
        question: "Don't have an account?",
        action: 'Create one',
        onTap: () => context.push(Routes.register),
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppEmailField(controller: _email, hint: 'you@cse.jnu.ac.bd'),
              const Gap(AppSpacing.md),
              AppPasswordField(controller: _password, onSubmitted: (_) => _submit()),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push(Routes.forgotPassword),
                  child: const Text('Forgot password?'),
                ),
              ),
              const Gap(AppSpacing.xs),
              AppButton(label: 'Sign in', onPressed: _submit, isLoading: _submitting),
            ],
          ),
        ),
      ),
    );
  }
}
