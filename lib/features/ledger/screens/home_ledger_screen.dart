import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/models/contact_model.dart';
import '../../../core/navigation/business_section.dart';
import '../../../core/widgets/book_switcher.dart';
import '../../../l10n/app_localizations.dart';
import '../../books/providers/book_provider.dart';
import '../../bills/screens/bill_list_screen.dart';
import '../../dashboard/screens/business_dashboard_screen.dart';
import '../../khata/screens/party_list_screen.dart';
import '../../products/screens/product_list_screen.dart';
import 'register_section_body.dart';

/// The app's home shell.
///
/// - Individual Book: the Income/Expense register - there's nothing else to
///   show, so it's both the default and only view. Its AppBar gets a
///   "download all data as Excel" icon that exports whatever the register
///   currently has on screen, active filters included.
/// - Business Book: a persistent shell over all five sections (Dashboard,
///   Bills, Register, Parties, Products). The AppBar (business name +
///   section icons) stays put and the body swaps beneath it, so any section
///   is one tap from any other.
///
/// The sections used to be pushed routes, which meant every move between
/// two of them cost a back-tap plus a second tap to pick the next one -
/// three taps to do one thing. They're peers, not a hierarchy, so they
/// belong at one level with a persistent bar.
///
/// Section state is kept alive across switches (see [IndexedStack]), so
/// returning to a section finds your filters, search text and scroll
/// position where you left them.
class HomeLedgerScreen extends StatefulWidget {
  /// Which section to open on. Lets the named routes ('/bills',
  /// '/customers', ...) land inside the shell rather than on a standalone
  /// screen with no section bar.
  final BusinessSection initialSection;

  const HomeLedgerScreen({super.key, this.initialSection = BusinessSection.bills});

  @override
  State<HomeLedgerScreen> createState() => _HomeLedgerScreenState();
}

class _HomeLedgerScreenState extends State<HomeLedgerScreen> {
  final _registerKey = GlobalKey<RegisterSectionBodyState>();
  final _businessRegisterKey = GlobalKey<RegisterSectionBodyState>();
  final _customersKey = GlobalKey<PartyListScreenState>();
  final _suppliersKey = GlobalKey<PartyListScreenState>();
  final _productsKey = GlobalKey<ProductListScreenState>();

  late BusinessSection _section = widget.initialSection;

  /// Which of Customers/Suppliers the merged Parties section is showing.
  /// Defaults to Customers, matching the standalone screens' old default
  /// entry point.
  ContactType _partyType = ContactType.customer;

  void _select(BusinessSection section) {
    if (_section == section) return;
    setState(() => _section = section);
  }

  void _selectPartyType(ContactType type) {
    if (_partyType == type) return;
    setState(() => _partyType = type);
  }

  /// The section-specific AppBar action, if the current section has one.
  /// These live here rather than in each section because the sections no
  /// longer own an AppBar to put them in.
  Widget? _sectionAction() {
    switch (_section) {
      case BusinessSection.register:
        return IconButton(
          icon: const Icon(Icons.file_download_outlined),
          tooltip: AppLocalizations.of(context).downloadRegisterExcel,
          onPressed: () => _businessRegisterKey.currentState?.exportFilteredToExcel(),
        );
      case BusinessSection.parties:
        // Only Customers has an Excel export today (see
        // PartyListScreen.downloadCustomersExcel) - Suppliers has no
        // equivalent, same as the pre-merge standalone screens.
        return _partyType == ContactType.customer
            ? IconButton(
                icon: const Icon(Icons.file_download_outlined),
                tooltip: AppLocalizations.of(context).downloadCustomersOutstandingExcel,
                onPressed: () => _customersKey.currentState?.downloadCustomersExcel(),
              )
            : null;
      case BusinessSection.products:
        return IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          tooltip: AppLocalizations.of(context).downloadProductListPdf,
          onPressed: () => _productsKey.currentState?.downloadProductsPdf(),
        );
      case BusinessSection.bills:
      case BusinessSection.dashboard:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final currentBook = bookProvider.currentBook;
    final isBusiness = currentBook?.isBusiness == true;

    if (currentBook == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!isBusiness) {
      return Scaffold(
        appBar: AppBar(
          title: const BookSwitcher(),
          actions: [
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: AppLocalizations.of(context).downloadAllDataExcel,
              onPressed: () => _registerKey.currentState?.exportFilteredToExcel(),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: AppLocalizations.of(context).settingsTitle,
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
        body: RegisterSectionBody(key: _registerKey),
      );
    }

    final sectionAction = _sectionAction();
    final settingsAction = IconButton(
      icon: const Icon(Icons.settings),
      tooltip: AppLocalizations.of(context).settingsTitle,
      onPressed: () => Navigator.pushNamed(context, '/settings'),
    );

    // On a phone the five sections move out of the AppBar and into a bottom
    // NavigationBar - the native pattern for peer sections, and one tap from
    // any section to any other without the top strip having to scroll. At
    // tablet/desktop width the AppBar strip is kept exactly as before.
    final compact = context.isCompact;

    return BusinessShellScope(
      current: _section,
      select: _select,
      selectPartyType: _selectPartyType,
      child: Scaffold(
        appBar: AppBar(
          title: const BookSwitcher(),
          actions: compact
              // Sections live in the bottom bar now, so the AppBar only
              // carries the current section's action plus Settings.
              ? [
                  if (sectionAction != null) sectionAction,
                  settingsAction,
                ]
              // A single scrolling strip rather than a plain actions list:
              // five section icons plus settings plus a section action is
              // more than a 360dp phone can lay out, and AppBar actions clip
              // silently rather than wrapping - the last icons would simply
              // be unreachable. Scrolling keeps every one of them tappable at
              // any width.
              : [
                  _SectionActionsStrip(
                    current: _section,
                    onSelect: _select,
                    trailing: [
                      if (sectionAction != null) sectionAction,
                      settingsAction,
                    ],
                  ),
                ],
        ),
        // IndexedStack, not a switch: rebuilding a section from scratch on
        // every visit would drop the user's filters and scroll position,
        // and re-run each section's Firestore reads on every tap.
        body: IndexedStack(
          index: _section.index,
          children: [
            for (final section in BusinessSection.values) _bodyFor(section),
          ],
        ),
        bottomNavigationBar: compact
            ? NavigationBar(
                selectedIndex: _section.index,
                onDestinationSelected: (i) =>
                    _select(BusinessSection.values[i]),
                // Only-selected labels keep all five destinations legible at
                // 360dp, where five always-on labels ("Dashboard",
                // "Register") would crowd and ellipsize.
                labelBehavior:
                    NavigationDestinationLabelBehavior.onlyShowSelected,
                destinations: [
                  for (final section in BusinessSection.values)
                    NavigationDestination(
                      icon: Icon(section.icon),
                      label: businessSectionLabel(
                          AppLocalizations.of(context), section),
                    ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _bodyFor(BusinessSection section) {
    switch (section) {
      case BusinessSection.bills:
        return const BillsSectionBody();
      case BusinessSection.dashboard:
        return const BusinessDashboardScreen(embedded: true);
      case BusinessSection.register:
        return RegisterSectionBody(key: _businessRegisterKey);
      case BusinessSection.parties:
        return _PartiesBody(
          type: _partyType,
          onTypeChanged: _selectPartyType,
          customersKey: _customersKey,
          suppliersKey: _suppliersKey,
        );
      case BusinessSection.products:
        return ProductListScreen(key: _productsKey, embedded: true);
    }
  }
}

/// Customers and Suppliers used to be two separate sections; this merges
/// them into one "Parties" section with a toggle at the top, defaulting to
/// Customers. Both lists are kept alive underneath (IndexedStack, not a
/// conditional build) so toggling back and forth doesn't drop a party's
/// search text or scroll position - the same reason the outer shell keeps
/// every top-level section alive.
class _PartiesBody extends StatelessWidget {
  final ContactType type;
  final ValueChanged<ContactType> onTypeChanged;
  final GlobalKey<PartyListScreenState> customersKey;
  final GlobalKey<PartyListScreenState> suppliersKey;

  const _PartiesBody({
    required this.type,
    required this.onTypeChanged,
    required this.customersKey,
    required this.suppliersKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageGutter, AppSpacing.md, AppSpacing.pageGutter, AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<ContactType>(
                  segments: [
                    ButtonSegment(
                      value: ContactType.customer,
                      label: Text(AppLocalizations.of(context).customers),
                      icon: const Icon(Icons.people_outline),
                    ),
                    ButtonSegment(
                      value: ContactType.vendor,
                      label: Text(AppLocalizations.of(context).suppliers),
                      icon: const Icon(Icons.local_shipping_outlined),
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) => onTypeChanged(s.first),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: type == ContactType.customer ? 0 : 1,
            children: [
              PartyListScreen(
                key: customersKey,
                type: ContactType.customer,
                embedded: true,
              ),
              PartyListScreen(
                key: suppliersKey,
                type: ContactType.vendor,
                embedded: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The persistent section switcher: one icon per section, the active one
/// tinted and pill-backed, followed by any section action and Settings.
///
/// Horizontally scrollable and width-capped so the business name in the
/// title always keeps room, however many icons there are.
class _SectionActionsStrip extends StatelessWidget {
  final BusinessSection current;
  final void Function(BusinessSection) onSelect;
  final List<Widget> trailing;

  const _SectionActionsStrip({
    required this.current,
    required this.onSelect,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;
    final baseColor = theme.appBarTheme.foregroundColor ??
        theme.colorScheme.onSurface;

    return ConstrainedBox(
      // Leaves at least a third of the bar for the book name, so a long
      // business name never gets squeezed to an ellipsis by the icons.
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.68,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true, // keeps the rightmost icons visible by default
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final section in BusinessSection.values)
              _SectionIcon(
                section: section,
                selected: section == current,
                selectedColor: selectedColor,
                baseColor: baseColor,
                onTap: () => onSelect(section),
              ),
            if (trailing.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: SizedBox(
                  height: 24,
                  child: VerticalDivider(
                    width: 1,
                    color: baseColor.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ...trailing,
          ],
        ),
      ),
    );
  }
}

class _SectionIcon extends StatelessWidget {
  final BusinessSection section;
  final bool selected;
  final Color selectedColor;
  final Color baseColor;
  final VoidCallback onTap;

  const _SectionIcon({
    required this.section,
    required this.selected,
    required this.selectedColor,
    required this.baseColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: businessSectionLabel(AppLocalizations.of(context), section),
      child: IconButton(
        onPressed: onTap,
        // Without a selected state the bar can't answer "where am I?" -
        // and with the body swapping in place rather than pushing, that
        // question no longer has a back arrow to answer it.
        style: selected
            ? IconButton.styleFrom(
                backgroundColor: selectedColor.withValues(alpha: 0.14),
              )
            : null,
        icon: Icon(
          section.icon,
          color: selected ? selectedColor : baseColor,
        ),
      ),
    );
  }
}
