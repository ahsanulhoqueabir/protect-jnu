import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/extensions.dart';

/// Placeholder legal text. It MUST be replaced with your own before release.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(title, style: context.textTheme.headlineSmall),
          const Gap(AppSpacing.md),
          const Text('Placeholder. Replace this text with your own legal document before release.'),
        ],
      ),
    );
  }
}
