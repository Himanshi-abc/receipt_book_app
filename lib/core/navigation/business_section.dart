import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../models/contact_model.dart';

/// The top-level sections of a Business Book.
///
/// These are peers, not a hierarchy: a user moving from Parties to Bills
/// is switching view, not drilling in and out. Modelling them as pushed
/// routes forced a back-tap between every pair, which is what the shell in
/// HomeLedgerScreen now removes.
///
/// Declaration order is the icon/nav-bar order the shell renders (also
/// their `.index`, which drives the IndexedStack body and the mobile
/// bottom NavigationBar) - Dashboard, Bills, Register, Parties, Products.
enum BusinessSection {
  dashboard(icon: Icons.dashboard_outlined),
  bills(icon: Icons.receipt_long_outlined),
  register(icon: Icons.menu_book_outlined),
  // Customers and Suppliers used to be two separate sections; they're now
  // one "Parties" section with a Customer/Supplier toggle at the top of its
  // body (see HomeLedgerScreen._bodyFor) - same two lists, one nav slot.
  parties(icon: Icons.people_outline),
  products(icon: Icons.inventory_2_outlined);

  final IconData icon;

  const BusinessSection({required this.icon});
}

/// The translated nav-bar caption for a section.
///
/// A free mapper rather than a `label` field on the enum, matching
/// `billRangeLabel` / `dateFilterLabel`: an enum constant is built once at
/// startup and has no BuildContext, so a const label could never follow a
/// language change made from Settings.
String businessSectionLabel(AppLocalizations l10n, BusinessSection section) =>
    switch (section) {
      BusinessSection.dashboard => l10n.navDashboard,
      BusinessSection.bills => l10n.navBills,
      BusinessSection.register => l10n.navRegister,
      BusinessSection.parties => l10n.navParties,
      BusinessSection.products => l10n.navProducts,
    };

/// Lets anything inside the shell switch the visible section without
/// pushing a route.
///
/// Screens that can be reached both inside the shell and standalone (the
/// dashboard's drill-down cards, for example) look this up and fall back to
/// `Navigator.pushNamed` when it isn't found, so they work either way.
class BusinessShellScope extends InheritedWidget {
  final BusinessSection current;
  final void Function(BusinessSection section) select;

  /// Pre-selects which party type (Customer vs Supplier) the Parties
  /// section shows, for callers landing on it via [goTo]. Null when the
  /// shell doesn't expose a Parties sub-selection.
  final void Function(ContactType type)? selectPartyType;

  const BusinessShellScope({
    super.key,
    required this.current,
    required this.select,
    this.selectPartyType,
    required super.child,
  });

  static BusinessShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BusinessShellScope>();

  /// Switches section if we're inside the shell; otherwise pushes
  /// [fallbackRoute] so the caller still works as a standalone screen.
  ///
  /// [partyType] only matters when [section] is [BusinessSection.parties] -
  /// it picks which of Customers/Suppliers is shown on arrival.
  static void goTo(
    BuildContext context,
    BusinessSection section, {
    required String fallbackRoute,
    VoidCallback? onReturn,
    ContactType? partyType,
  }) {
    final scope = maybeOf(context);
    if (scope != null) {
      if (partyType != null) scope.selectPartyType?.call(partyType);
      scope.select(section);
      return;
    }
    Navigator.pushNamed(context, fallbackRoute).then((_) => onReturn?.call());
  }

  @override
  bool updateShouldNotify(BusinessShellScope oldWidget) =>
      current != oldWidget.current ||
      select != oldWidget.select ||
      selectPartyType != oldWidget.selectPartyType;
}
