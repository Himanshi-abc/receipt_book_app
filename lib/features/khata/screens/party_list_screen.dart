import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/models/contact_model.dart';
import '../../../core/services/book_access_service.dart';
import '../../../core/services/contact_repository.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../core/widgets/app_stat_card.dart';
import '../../../core/widgets/money_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../books/providers/book_provider.dart';
import '../services/customer_excel_service.dart';
import '../services/khata_balance.dart';
import '../services/khata_entry_repository.dart';
import 'add_party_screen.dart';
import 'party_detail_screen.dart';

enum _SortOption { recentlyUpdated, outstandingHighToLow, nameAZ }

/// Shown for both Customers (ContactType.customer) and Suppliers
/// (ContactType.vendor) - same screen, parameterized by type. Business
/// Book only; the caller is responsible for gating navigation to this
/// screen behind `currentBook?.isBusiness == true` (see HomeLedgerScreen).
class PartyListScreen extends StatefulWidget {
  final ContactType type;

  /// When true this renders without its own AppBar, because HomeLedgerScreen's
  /// shell already provides one. The Excel action moves up there too, driven
  /// through [PartyListScreenState.downloadCustomersExcel].
  final bool embedded;

  const PartyListScreen({required this.type, this.embedded = false, super.key});

  @override
  State<PartyListScreen> createState() => PartyListScreenState();
}

class PartyListScreenState extends State<PartyListScreen> {
  final _contactRepo = ContactRepository();
  final _entryRepo = KhataEntryRepository();
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  List<Contact> _all = [];
  List<Contact> _filtered = [];
  Map<String, int> _balanceByContactId = {};
  Map<String, DateTime> _lastActivityByContactId = {};
  _SortOption _sort = _SortOption.recentlyUpdated;

  /// Book-wide totals (across every Customer AND Supplier, not just
  /// [widget.type]) - shown as a summary banner on both the Customers and
  /// Suppliers screens, same as a "You Collect" / "You Pay" pair in a
  /// billing app like Swipe.
  int _youCollectPaise = 0;
  int _youPayPaise = 0;

  bool get _isCustomer => widget.type == ContactType.customer;

  String _sectionTitleOf(AppLocalizations l10n) =>
      _isCustomer ? l10n.customers : l10n.suppliers;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final bookId = context.read<BookProvider>().currentBook?.id;
    if (bookId == null) return;
    setState(() => _loading = true);
    final contacts = await _contactRepo.loadContacts(bookId, type: widget.type);
    // Unfiltered by type - needed for the book-wide You Collect/You Pay
    // summary, which spans both Customers and Suppliers regardless of
    // which of the two screens is currently open.
    final allContacts = await _contactRepo.loadContacts(bookId);
    final allEntries = await _entryRepo.entriesForBook(bookId);

    final balances = <String, int>{};
    final lastActivity = <String, DateTime>{};
    for (final c in contacts) {
      final entries = allEntries.where((e) => e.contactId == c.id).toList();
      balances[c.id] = outstandingPaiseFor(entries);
      var latest = c.updatedAt;
      for (final e in entries) {
        if (e.updatedAt.isAfter(latest)) latest = e.updatedAt;
      }
      lastActivity[c.id] = latest;
    }

    // A positive balance means "the party owes the business" (see
    // khata_balance.dart) - for a Customer that's money to collect, but for
    // a Supplier it's the reverse: you're the one holding their money.
    var youCollect = 0;
    var youPay = 0;
    for (final c in allContacts) {
      final entries = allEntries.where((e) => e.contactId == c.id).toList();
      final balance = outstandingPaiseFor(entries);
      if (balance == 0) continue;
      final owedToBusiness = c.type == ContactType.customer ? balance > 0 : balance < 0;
      if (owedToBusiness) {
        youCollect += balance.abs();
      } else {
        youPay += balance.abs();
      }
    }

    setState(() {
      _all = contacts;
      _balanceByContactId = balances;
      _lastActivityByContactId = lastActivity;
      _youCollectPaise = youCollect;
      _youPayPaise = youPay;
      _loading = false;
      _applyFilters();
    });
  }

  void _applyFilters() {
    final query = _searchCtrl.text.trim().toLowerCase();
    var list = query.isEmpty
        ? List<Contact>.from(_all)
        : _all.where((c) => c.name.toLowerCase().contains(query)).toList();

    switch (_sort) {
      case _SortOption.recentlyUpdated:
        list.sort((a, b) => (_lastActivityByContactId[b.id] ?? b.updatedAt)
            .compareTo(_lastActivityByContactId[a.id] ?? a.updatedAt));
        break;
      case _SortOption.outstandingHighToLow:
        list.sort((a, b) => (_balanceByContactId[b.id] ?? 0)
            .abs()
            .compareTo((_balanceByContactId[a.id] ?? 0).abs()));
        break;
      case _SortOption.nameAZ:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }
    _filtered = list;
  }

  /// Customers section only: "download all customers data having the
  /// outstanding amount greater than zero" - Name/Mobile/Address, straight
  /// to device storage via file_picker's Save As dialog (same pattern as
  /// the Individual Book Excel export - lets the user see/pick exactly
  /// where it lands, e.g. Downloads).
  Future<void> downloadCustomersExcel() async {
    final l10n = AppLocalizations.of(context);
    final withDue = _all.where((c) => (_balanceByContactId[c.id] ?? 0) > 0).toList();
    if (withDue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noCustomersWithOutstanding)),
      );
      return;
    }
    final bytes = CustomerExcelService.generate(withDue);
    try {
      final path = await FilePicker.platform.saveFile(
        fileName: 'customers_outstanding_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        bytes: bytes,
      );
      // null means the user cancelled the save dialog - not an error.
      if (path != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.exportExcelSaved)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.exportExcelFailed('$e'))));
      }
    }
  }

  String _sortLabel(AppLocalizations l10n, _SortOption o) {
    switch (o) {
      case _SortOption.recentlyUpdated:
        return l10n.sortRecentlyUpdated;
      case _SortOption.outstandingHighToLow:
        return l10n.sortOutstandingHighToLow;
      case _SortOption.nameAZ:
        return l10n.sortNameAZ;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final book = bookProvider.currentBook;
    if (book == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final access = bookProvider.accessFor(book);
    final l10n = AppLocalizations.of(context);
    final sectionTitle = _sectionTitleOf(l10n);

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(sectionTitle),
              actions: [
                if (_isCustomer)
                  IconButton(
                    icon: const Icon(Icons.file_download_outlined),
                    tooltip: l10n.downloadCustomersOutstandingExcel,
                    onPressed: downloadCustomersExcel,
                  ),
              ],
            ),
      body: !access.writable
          ? _buildLockedState(access)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageGutter, AppSpacing.lg, AppSpacing.pageGutter, 0),
                  // IntrinsicHeight, not bare `stretch`: this Row's parent
                  // is a Column, so incoming maxHeight is unbounded and
                  // `stretch` would force a tight infinite height on the
                  // cards, blanking the screen.
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: AppStatCard(
                            label: l10n.youCollect,
                            amountPaise: _youCollectPaise,
                            tone: AppTone.positive,
                            icon: Icons.call_received,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppStatCard(
                            label: l10n.youPay,
                            amountPaise: _youPayPaise,
                            tone: AppTone.negative,
                            icon: Icons.call_made,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageGutter, vertical: AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppSearchField(
                          controller: _searchCtrl,
                          // Per-type keys rather than lower-casing the
                          // section noun: most of the supported scripts
                          // have no letter case for toLowerCase to change.
                          hintText: _isCustomer
                              ? l10n.searchCustomerHint
                              : l10n.searchSupplierHint,
                          onChanged: (_) => setState(_applyFilters),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      PopupMenuButton<_SortOption>(
                        icon: const Icon(Icons.sort),
                        tooltip: l10n.sortBy,
                        onSelected: (o) => setState(() {
                          _sort = o;
                          _applyFilters();
                        }),
                        itemBuilder: (ctx) => _SortOption.values
                            .map((o) => PopupMenuItem<_SortOption>(
                                  value: o,
                                  child: Row(
                                    children: [
                                      if (o == _sort)
                                        const Icon(Icons.check, size: 18)
                                      else
                                        const SizedBox(width: 18),
                                      const SizedBox(width: 8),
                                      Text(_sortLabel(l10n, o)),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _filtered.isEmpty
                          ? (_all.isEmpty
                              ? AppEmptyState(
                                  icon: _isCustomer
                                      ? Icons.people_outline
                                      : Icons.local_shipping_outlined,
                                  title: _isCustomer
                                      ? l10n.noCustomersYet
                                      : l10n.noSuppliersYet,
                                  message: _isCustomer
                                      ? l10n.noCustomersYetMessage
                                      : l10n.noSuppliersYetMessage,
                                  actionLabel: _isCustomer
                                      ? l10n.addCustomer
                                      : l10n.addSupplier,
                                  onAction: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AddPartyScreen(defaultType: widget.type),
                                      ),
                                    );
                                    _load();
                                  },
                                )
                              : AppEmptyState(
                                  icon: Icons.search_off,
                                  title: l10n.noMatches,
                                  message: l10n.noPartyMatchesSearch,
                                ))
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.pageGutter,
                                  AppSpacing.xs,
                                  AppSpacing.pageGutter,
                                  // Clears the extended FAB so the last row
                                  // is never trapped underneath it.
                                  AppSpacing.giant + AppSpacing.xxl,
                                ),
                                itemCount: _filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (ctx, i) {
                                  final contact = _filtered[i];
                                  final balance = _balanceByContactId[contact.id] ?? 0;
                                  return _PartyRow(
                                    contact: contact,
                                    balancePaise: balance,
                                    isCustomer: _isCustomer,
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PartyDetailScreen(contact: contact),
                                        ),
                                      );
                                      _load();
                                    },
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
      floatingActionButton: access.writable
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: Text(_isCustomer ? l10n.addCustomer : l10n.addSupplier),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddPartyScreen(defaultType: widget.type),
                  ),
                );
                _load();
              },
            )
          : null,
    );
  }

  Widget _buildLockedState(BookAccessResult access) {
    final l10n = AppLocalizations.of(context);
    return AppEmptyState(
      icon: Icons.lock_outline,
      title: l10n.bookLockedTitle,
      message: BookAccessService.messageFor(l10n, access.reason),
      tone: AppTone.warning,
      actionLabel: l10n.switchBookOrUpgrade,
      onAction: () => Navigator.pushNamed(context, '/settings/manage-books'),
    );
  }
}

/// One customer/supplier row.
///
/// Promoted from an inline `ListTile` to a real card row for two reasons:
/// the balance now carries an explicit "You'll get"/"You'll pay" caption
/// (a bare coloured number required the user to remember what green meant),
/// and a settled party renders in neutral rather than as a colourless
/// "₹0.00" that looked like missing data.
class _PartyRow extends StatelessWidget {
  final Contact contact;
  final int balancePaise;
  final bool isCustomer;
  final VoidCallback onTap;

  const _PartyRow({
    required this.contact,
    required this.balancePaise,
    required this.isCustomer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.tones;
    final settled = balancePaise == 0;

    // A positive balance means the party owes the business. For a customer
    // that's money to collect; for a supplier the same sign means the
    // reverse - hence the flip. (See khata_balance.dart.)
    final owedToBusiness = isCustomer ? balancePaise > 0 : balancePaise < 0;
    final tone = settled
        ? AppTone.neutral
        : (owedToBusiness ? AppTone.positive : AppTone.negative);
    final l10n = AppLocalizations.of(context);
    final caption = settled
        ? l10n.settledUp
        : (owedToBusiness ? l10n.youWillGet : l10n.youWillPay);

    return Material(
      color: tones.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: tones.border),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              _Avatar(name: contact.name),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      contact.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (contact.phone?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        contact.phone!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: tones.textTertiary)
                            .tabular,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MoneyText(
                    balancePaise,
                    tone: tone,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    caption,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: tones.textTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Monogram avatar. Gives each row a stable visual anchor so a long list
/// is scannable by shape, not just by reading every name.
class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final tones = context.tones;
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tones.brand.bg,
        shape: BoxShape.circle,
        border: Border.all(color: tones.brand.border),
      ),
      child: Text(
        initial,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: tones.brand.fg),
      ),
    );
  }
}
