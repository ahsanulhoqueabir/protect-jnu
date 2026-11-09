import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import 'brand_mark.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(size: 56),
            Gap(AppSpacing.lg),
            CircularProgressIndicator(),
          ],
        ),
      );
}
