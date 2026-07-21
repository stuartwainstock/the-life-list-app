import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Brand hairline rule — default content-block separation.
///
/// Prefer this over tinted/bordered cards (`docs/brand.md` surface
/// philosophy). Color comes from [ColorScheme.outlineVariant] (wired to
/// the hairline token in [AppTheme]), not a hardcoded hex.
class AppHairline extends StatelessWidget {
  final double indent;
  final double endIndent;

  const AppHairline({
    super.key,
    this.indent = 0,
    this.endIndent = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: AppStroke.hairline,
      thickness: AppStroke.hairline,
      indent: indent,
      endIndent: endIndent,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
