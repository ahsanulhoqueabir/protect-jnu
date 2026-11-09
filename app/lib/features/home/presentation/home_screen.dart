import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../auth/auth_providers.dart';

/// Placeholder home. The SOS button and live alerts arrive in Phase 4 (not built here).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text("Protect JnU'ins")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            user == null ? '' : 'Welcome, ${user.fullName}.\nYou are signed in and verified.',
            textAlign: TextAlign.center,
            style: context.textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}
