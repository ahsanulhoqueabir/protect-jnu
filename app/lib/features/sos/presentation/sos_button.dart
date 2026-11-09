import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/extensions.dart';
import '../domain/sos_flow.dart';
import '../sos_providers.dart';

/// Hold for 2 s to trigger, then a 5 s window to cancel (PRD). A short press does nothing.
class SosButton extends ConsumerWidget {
  const SosButton({super.key});

  static const double size = 220;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(sosFlowProvider);
    final notifier = ref.read(sosFlowProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: switch (flow) {
            SosCountdown(:final secondsLeft) => _CountdownDial(
              secondsLeft: secondsLeft,
              onCancel: notifier.cancel,
            ),
            SosSending() || SosSent() => const _Dial(
              label: 'Sending…',
              child: CircularProgressIndicator(color: Colors.white),
            ),
            _ => Listener(
              onPointerDown: (_) => notifier.pressStart(),
              onPointerUp: (_) => notifier.pressEnd(),
              onPointerCancel: (_) => notifier.pressEnd(),
              child: Semantics(
                button: true,
                label: 'SOS. Press and hold for two seconds to send an alert.',
                child: _Dial(
                  label: 'SOS',
                  progress: flow is SosHolding ? flow.progress : null,
                ),
              ),
            ),
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          switch (flow) {
            SosHolding() => 'Keep holding…',
            SosCountdown() => 'Alert will be sent. Tap Cancel to stop it.',
            SosSending() || SosSent() => 'Sending your alert…',
            SosFailed(:final message) => message,
            _ => 'Press and hold for 2 seconds',
          },
          textAlign: TextAlign.center,
          style: context.textTheme.bodyMedium?.copyWith(
            color: flow is SosFailed ? context.colors.error : null,
          ),
        ),
      ],
    );
  }
}

class _Dial extends StatelessWidget {
  const _Dial({required this.label, this.progress, this.child});

  final String label;
  final double? progress;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFC62828),
            boxShadow: [BoxShadow(color: Color(0x55C62828), blurRadius: 24, spreadRadius: 4)],
          ),
        ),
        if (progress != null)
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 10,
              color: Colors.white,
              backgroundColor: Colors.white24,
            ),
          ),
        child ??
            Text(
              label,
              style: context.textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
      ],
    );
  }
}

class _CountdownDial extends StatelessWidget {
  const _CountdownDial({required this.secondsLeft, required this.onCancel});

  final int secondsLeft;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFC62828)),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$secondsLeft',
              key: const Key('sos-countdown'),
              style: context.textTheme.displayLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            FilledButton(
              key: const Key('sos-cancel'),
              onPressed: onCancel,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFC62828),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
    );
  }
}
