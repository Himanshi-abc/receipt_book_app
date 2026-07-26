import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/contact_model.dart';
import '../../../core/services/book_access_service.dart';
import '../../../core/services/contact_repository.dart';
import '../../../core/utils/money.dart';
import '../../books/providers/book_provider.dart';
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
  const PartyListScreen({required this.type, super.key});

  @override
  State<PartyListScreen> createState() => _PartyListScreenState();
}

class _PartyListScreenState extends State<PartyListScreen> {
  final _contactRepo = ContactRepository();
  final _entryRepo = KhataEntryRepository();
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  List<Contact> _all = [];
  List<Contact> _filtered = [];
  Map<String, int> _balanceByContactId = {};
  Map<String, DateTime> _lastActivityByContactId = {};
  _SortOption _sort = _SortOption.recentlyUpdated;

  bool get _isCustomer => widget.type == ContactType.customer;
  String get _sectionTitle => _isCustomer ? 'Customers' : 'Suppliers';

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

    setState(() {
      _all = contacts;
      _balanceByContactId = balances;
      _lastActivityByContactId = lastActivity;
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

  String _sortLabel(_SortOption o) {
    switch (o) {
      case _SortOption.recentlyUpdated:
        return 'Recently updated';
      case _SortOption.outstandingHighToLow:
        return 'Outstanding: High to low';
      case _SortOption.nameAZ:
        return 'Name: A-Z';
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

    return Scaffold(
      appBar: AppBar(title: Text(_sectionTitle)),
      body: !access.writable
          ? _buildLockedState(access)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search ${_sectionTitle.toLowerCase()} by name',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (_) => setState(_applyFilters),
                        ),
                      ),
                      PopupMenuButton<_SortOption>(
                        icon: const Icon(Icons.sort),
                        tooltip: 'Sort by',
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
                                      Text(_sortLabel(o)),
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
                          ? Center(
                              child: Text(
                                _all.isEmpty
                                    ? 'No ${_sectionTitle.toLowerCase()} yet. Tap + to add one.'
                                    : 'No matches found.',
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                itemCount: _filtered.length,
                                itemBuilder: (ctx, i) {
                                  final contact = _filtered[i];
                                  final balance = _balanceByContactId[contact.id] ?? 0;
                                  return ListTile(
                                    title: Text(contact.name),
                                    subtitle: Text(contact.phone ?? ''),
                                    trailing: balance == 0
                                        ? const Text('₹0.00', style: TextStyle(color: Colors.grey))
                                        : Text(
                                            Money.format(balance.abs()),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: balance > 0
                                                  ? Colors.green.shade700
                                                  : Colors.red.shade700,
                                            ),
                                          ),
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
              label: Text(_isCustomer ? 'Add Customer' : 'Add Supplier'),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(BookAccessService.messageFor(access.reason), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, '/settings/manage-books'),
              child: const Text('Switch Active Book / Upgrade'),
            ),
          ],
        ),
      ),
    );
  }
}
