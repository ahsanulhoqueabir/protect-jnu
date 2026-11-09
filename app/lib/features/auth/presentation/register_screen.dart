import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/forms/validators.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/feedback/app_feedback.dart';
import '../../../shared/widgets/forms/app_password_field.dart';
import '../../../shared/widgets/forms/app_selection_fields.dart';
import '../../../shared/widgets/forms/app_text_field.dart';
import '../auth_providers.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_layout.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _studentId = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late final _termsTap = TapGestureRecognizer()..onTap = () => context.push(Routes.terms);
  late final _privacyTap = TapGestureRecognizer()..onTap = () => context.push(Routes.privacy);
  bool _submitting = false;
  String? _serverEmailError;
  String? _serverStudentIdError;

  @override
  void dispose() {
    _name.dispose();
    _studentId.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _serverEmailError = null;
    _serverStudentIdError = null;
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final email = _email.text.trim().toLowerCase();
    try {
      await ref
          .read(authRepositoryProvider)
          .register(
            fullName: _name.text.trim(),
            studentId: _studentId.text,
            email: email,
            password: _password.text,
          );
      ref
          .read(pendingVerificationProvider.notifier)
          .set(PendingVerification(email: email, password: _password.text));
      if (mounted) context.go(Routes.verifyEmailFor(email, sent: true));
      return;
    } on CodedApiException catch (e) {
      switch (e.code) {
        case 'email_taken' || 'email_domain_not_allowed':
          _serverEmailError = e.message;
          _formKey.currentState!.validate();
        case 'student_id_taken':
          _serverStudentIdError = e.message;
          _formKey.currentState!.validate();
        default:
          if (mounted) showAppSnack(context, e.message, type: SnackType.error);
      }
    } on Object catch (e) {
      if (mounted) showAppSnack(context, userMessage(e), type: SnackType.error);
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final linkStyle = TextStyle(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    );

    return AuthLayout(
      title: 'Create your account',
      subtitle: 'Use your Jagannath University email.',
      footer: AuthFooterLink(
        question: 'Already have an account?',
        action: 'Sign in',
        onTap: () => context.go(Routes.login),
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Full name',
                controller: _name,
                prefixIcon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: Validators.compose([
                  Validators.required('Enter your name'),
                  Validators.maxLength(100),
                ]),
              ),
              const Gap(AppSpacing.md),
              AppTextField(
                label: 'Student ID',
                controller: _studentId,
                hint: 'B210305040',
                prefixIcon: Icons.badge_outlined,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]'))],
                validator: Validators.compose([
                  Validators.required('Enter your student ID'),
                  Validators.studentId(),
                  (_) => _serverStudentIdError,
                ]),
                onChanged: (_) => _serverStudentIdError = null,
              ),
              const Gap(AppSpacing.md),
              AppEmailField(
                controller: _email,
                hint: 'you@cse.jnu.ac.bd',
                validator: Validators.compose([
                  Validators.required('Enter your email'),
                  Validators.email(),
                  Validators.universityEmail(),
                  (_) => _serverEmailError,
                ]),
              ),
              const Gap(AppSpacing.md),
              AppPasswordField(
                controller: _password,
                showStrength: true,
                isNewPassword: true,
                textInputAction: TextInputAction.next,
                validator: Validators.compose([
                  Validators.required('Choose a password'),
                  Validators.newPassword(),
                ]),
              ),
              const Gap(AppSpacing.md),
              AppPasswordField(
                controller: _confirm,
                label: 'Confirm password',
                isNewPassword: true,
                onSubmitted: (_) => _submit(),
                validator: Validators.compose([
                  Validators.required('Confirm your password'),
                  Validators.match(() => _password.text, 'Passwords do not match'),
                ]),
              ),
              const Gap(AppSpacing.sm),
              AppCheckboxField(
                validator: Validators.mustBeTrue('Please accept to continue'),
                labelWidget: Text.rich(
                  TextSpan(
                    text: 'I agree to the ',
                    children: [
                      TextSpan(text: 'Terms', style: linkStyle, recognizer: _termsTap),
                      const TextSpan(text: ' and '),
                      TextSpan(text: 'Privacy Policy', style: linkStyle, recognizer: _privacyTap),
                    ],
                  ),
                ),
              ),
              const Gap(AppSpacing.md),
              AppButton(label: 'Create account', onPressed: _submit, isLoading: _submitting),
            ],
          ),
        ),
      ),
    );
  }
}
