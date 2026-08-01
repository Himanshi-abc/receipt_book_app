import 'package:flutter/material.dart';

/// Motion tokens.
///
/// Three durations, no more. Anything under ~120ms reads as a glitch,
/// anything over ~350ms feels sluggish on repeat use - and in an app where
/// a shopkeeper enters dozens of bills a day, repeat use is the only use.
/// Curves are asymmetric on purpose: things enter fast and settle
/// (easeOutCubic), which reads as responsive rather than floaty.
class AppMotion {
  AppMotion._();

  /// Hover, focus ring, color tint changes.
  static const Duration fast = Duration(milliseconds: 150);

  /// Default: expand/collapse, selection, card state.
  static const Duration base = Duration(milliseconds: 220);

  /// Page-level or large-surface transitions.
  static const Duration slow = Duration(milliseconds: 300);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve standard = Curves.easeInOutCubic;
}
