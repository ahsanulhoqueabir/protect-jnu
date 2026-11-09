import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_spacing.dart';

/// Six digit boxes backed by ONE invisible text field, so keyboard, paste and the platform's
/// one-time-code autofill all work. Tapping anywhere focuses it.
class OtpBoxes extends StatefulWidget {
  const OtpBoxes({
    super.key,
    required this.controller,
    this.length = 6,
    this.enabled = true,
    this.hasError = false,
    this.onCompleted,
  });

  final TextEditingController controller;
  final int length;
  final bool enabled;
  final bool hasError;
  final ValueChanged<String>? onCompleted;

  @override
  State<OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<OtpBoxes> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Verification code, ${widget.length} digits',
      textField: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? _focus.requestFocus : null,
        child: Stack(
          children: [
            ListenableBuilder(
              listenable: Listenable.merge([widget.controller, _focus]),
              builder: (context, _) {
                final text = widget.controller.text;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < widget.length; i++)
                      _Box(
                        char: i < text.length ? text[i] : '',
                        active: _focus.hasFocus && i == text.length.clamp(0, widget.length - 1),
                        error: widget.hasError,
                        colors: colors,
                      ),
                  ],
                );
              },
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  showCursor: false,
                  enableInteractiveSelection: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.length),
                  ],
                  onChanged: (value) {
                    if (value.length == widget.length) widget.onCompleted?.call(value);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.char, required this.active, required this.error, required this.colors});

  final String char;
  final bool active;
  final bool error;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final border = error
        ? colors.error
        : active
        ? colors.primary
        : colors.outlineVariant;
    return Container(
      width: 46,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: border, width: active || error ? 1.8 : 1),
      ),
      child: Text(char, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
