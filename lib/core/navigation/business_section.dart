import 'package:flutter/material.dart';

/// The top-level sections of a Business Book.
///
/// These are peers, not a hierarchy: a user moving from Customers to Bills
/// is switching view, not drilling in and out. Modelling them as pushed
/// routes forced a back-tap between every pair, which is what the shell in
/// HomeLedgerScreen now removes.
enum BusinessSection {
  bills(icon: Icons.receipt_long_outlined, label: 'Bills'),
  dashboard(icon: Icons.dashboard_outlined, label: 'Dashboard'),
  register(icon: Icons.menu_book_outlined, label: 'Register'),
  customers(icon: Icons.people_outline, label: 'Customers'),
  suppliers(icon: Icons.local_shipping_outlined, label: 'Suppliers'),
  products(icon: Icons.inventory_2_outlined, label: 'Products');

  final IconData icon;
  final String label;

  const BusinessSection({required this.icon, required this.label});
}

/// Lets anything inside the shell switch the visible section without
/// pushing a route.
///
/// Screens that can be reached both inside the shell and standalone (the
/// dashboard's drill-down cards, for example) look this up and fall back to
/// `Navigator.pushNamed` when it isn't found, so they work either way.
class BusinessShellScope extends InheritedWidget {
  final BusinessSection current;
  final void Function(BusinessSection section) select;

  const BusinessShellScope({
    super.key,
    required this.current,
    required this.select,
    required super.child,
  });

  static BusinessShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BusinessShellScope>();

  /// Switches section if we're inside the shell; otherwise pushes
  /// [fallbackRoute] so the caller still works as a standalone screen.
  static void goTo(
    BuildContext context,
    BusinessSection section, {
    required String fallbackRoute,
    VoidCallback? onReturn,
  }) {
    final scope = maybeOf(context);
    if (scope != null) {
      scope.select(section);
      return;
    }
    Navigator.pushNamed(context, fallbackRoute).then((_) => onReturn?.call());
  }

  @override
  bool updateShouldNotify(BusinessShellScope oldWidget) =>
      current != oldWidget.current || select != oldWidget.select;
}
