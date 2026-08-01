import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/models/contact_model.dart';
import '../../../core/navigation/business_section.dart';
import '../../../core/widgets/book_switcher.dart';
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
/// - Business Book: a persistent shell over all six sections. The AppBar
///   (business name + section icons) stays put and the body swaps beneath
///   it, so any section is one tap from any other.
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

  void _select(BusinessSection section) {
    if (_section == section) return;
    setState(() => _section = section);
  }

  /// The section-specific AppBar action, if the current section has one.
  /// These live here rather than in each section because the sections no
  /// longer own an AppBar to put them in.
  Widget? _sectionAction() {
    switch (_section) {
      case BusinessSection.register:
        return IconButton(
          icon: const Icon(Icons.file_download_outlined),
          tooltip: 'Download register (Excel)',
          onPressed: () => _businessRegisterKey.currentState?.exportFilteredToExcel(),
        );
      case BusinessSection.customers:
        return IconButton(
          icon: const Icon(Icons.file_download_outlined),
          tooltip: 'Download customers with outstanding amount (Excel)',
          onPressed: () => _customersKey.currentState?.downloadCustomersExcel(),
        );
      case BusinessSection.products:
        return IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          tooltip: 'Download product list (PDF)',
          onPressed: () => _productsKey.currentState?.downloadProductsPdf(),
        );
      case BusinessSection.bills:
      case BusinessSection.dashboard:
      case BusinessSection.suppliers:
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
              tooltip: 'Download all data (Excel)',
              onPressed: () => _registerKey.currentState?.exportFilteredToExcel(),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
        body: RegisterSectionBody(key: _registerKey),
      );
    }

    final sectionAction = _sectionAction();

    return BusinessShellScope(
      current: _section,
      select: _select,
      child: Scaffold(
        appBar: AppBar(
          title: const BookSwitcher(),
          // A single scrolling strip rather than a plain actions list:
          // six section icons plus settings plus a section action is more
          // than a 360dp phone can lay out, and AppBar actions clip
          // silently rather than wrapping - the last icons would simply be
          // unreachable. Scrolling keeps every one of them tappable at any
          // width.
          actions: [
            _SectionActionsStrip(
              current: _section,
              onSelect: _select,
              trailing: [
                if (sectionAction != null) sectionAction,
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: 'Settings',
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                ),
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
      case BusinessSection.customers:
        return PartyListScreen(
          key: _customersKey,
          type: ContactType.customer,
          embedded: true,
        );
      case BusinessSection.suppliers:
        return PartyListScreen(
          key: _suppliersKey,
          type: ContactType.vendor,
          embedded: true,
        );
      case BusinessSection.products:
        return const ProductListScreen(embedded: true);
    }
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
      message: section.label,
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
