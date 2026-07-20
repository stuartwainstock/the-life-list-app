/// Spacing, radius, and hairline widths — prefer these over magic numbers.
///
/// Matches the restrained editorial direction in `docs/brand.md`: tight
/// rhythm for lists, breathing room between content groups.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

abstract final class AppStroke {
  /// Default divider / hairline rule width (`docs/brand.md` surface philosophy).
  static const double hairline = 1;
}
