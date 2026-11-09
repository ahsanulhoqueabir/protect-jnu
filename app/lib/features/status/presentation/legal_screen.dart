import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/extensions.dart';
import '../domain/legal_content.dart';

/// Shows a legal document (draft text, see [LegalContent]).
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.title, required this.sections});

  final String title;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(title, style: context.textTheme.headlineSmall),
          const Gap(AppSpacing.xs),
          Text(
            LegalContent.updated,
            style: context.textTheme.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          for (final s in sections) ...[
            const Gap(AppSpacing.lg),
            Text(s.heading, style: context.textTheme.titleMedium),
            const Gap(AppSpacing.xs),
            Text(s.body, style: context.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
