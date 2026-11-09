import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/feedback/app_feedback.dart';
import '../../sos/domain/sos_flow.dart';
import '../../sos/presentation/sos_button.dart';
import '../../sos/sos_providers.dart';

/// Home: the SOS button, or the student's open alert (one open alert at a time, D-060).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alert = ref.watch(openAlertProvider);

    // After the alert exists: tell the student if no location was shared, then show the status screen.
    ref.listen(sosFlowProvider, (_, next) {
      if (next is! SosSent) return;
      if (!next.withLocation) {
        showAppSnack(
          context,
          'Alert sent without your location (location is off or not allowed).',
          type: SnackType.error,
        );
      }
      ref.read(sosFlowProvider.notifier).reset();
      context.push(Routes.activeAlert);
    });

    final open = alert.value;
    return Scaffold(
      appBar: AppBar(title: const Text("Protect JnU'ins")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (alert.isLoading && !alert.hasValue)
                const CircularProgressIndicator()
              else if (open != null && open.status.isOpen) ...[
                Text(
                  'You have an open alert.',
                  style: context.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'View alert status',
                  onPressed: () => context.push(Routes.activeAlert),
                ),
              ] else
                const SosButton(),
            ],
          ),
        ),
      ),
    );
  }
}
