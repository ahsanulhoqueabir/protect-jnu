import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/forms/validators.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/feedback/app_feedback.dart';
import '../../../shared/widgets/forms/app_text_field.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_layout.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim().toLowerCase();
    final ok = await runGuarded(
      context,
      () => ref.read(authRepositoryProvider).forgotPassword(email),
    );
    // The server answers the same whether or not the account exists, so this screen does too.
    if (ok && mounted) context.go(Routes.resetPasswordFor(email));
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Reset your password',
      subtitle: "Enter your university email and we'll send you a 6-digit code.",
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AppEmailField(
              controller: _email,
              hint: 'you@cse.jnu.ac.bd',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: Validators.compose([
                Validators.required('Enter your email'),
                Validators.email(),
                Validators.universityEmail(),
              ]),
            ),
            const Gap(AppSpacing.lg),
            AppButton(label: 'Send code', onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
