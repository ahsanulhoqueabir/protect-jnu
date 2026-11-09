import 'package:flutter/material.dart';

/// Protect JnU'ins logo (assets/branding/logo.png). Square, shown uncropped and
/// unstretched; used on the splash, auth and loading screens.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final logo = Image.asset(
      'assets/branding/logo.png',
      width: dark ? size * 0.84 : size,
      height: dark ? size * 0.84 : size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: "Protect JnU'ins logo",
    );
    // The logo is navy on transparent: give it a white tile on dark themes.
    if (!dark) return logo;
    return Container(
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: logo,
    );
  }
}
