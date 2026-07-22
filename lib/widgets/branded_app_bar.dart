import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Standard top-level [AppBar] for tab screens (Sightings, Hotspots, Life
/// List, Settings) and other chrome that shares the same title + actions
/// shape.
///
/// Centralizes [AppTheme.toolbarHeightOf] and the Public Sans title style
/// from [ThemeData.appBarTheme] so screens don't re-hand-roll those and
/// drift apart (`docs/tickets/done/shared-appbar-component.md`).
///
/// Do **not** use this for species detail's `_HeroAppBar` — that
/// collapsing photo header is intentionally a different pattern.
///
/// ```dart
/// appBar: BrandedAppBar(
///   context: context,
///   title: 'Nearby Sightings',
///   actions: [ ... ],
/// ),
/// ```
class BrandedAppBar extends AppBar {
  BrandedAppBar({
    super.key,
    required BuildContext context,
    required String title,
    List<Widget> actions = const [],
  }) : super(
          title: Text(title),
          toolbarHeight: AppTheme.toolbarHeightOf(context),
          actions: actions.isEmpty ? null : actions,
        );
}
