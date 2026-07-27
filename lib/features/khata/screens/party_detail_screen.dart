import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/contact_model.dart';
import '../../../core/models/khata_entry_model.dart';
import '../../../core/services/contact_repository.dart';
import '../../../core/utils/money.dart';
import '../../books/providers/book_provider.dart';
import '../../../core/models/invoice_model.dart';
import '../../bills/screens/create_bill_screen.dart';
import '../../invoices/screens/invoice_preview_share_screen.dart';
import '../../invoices/services/invoice_repository.dart';
import '../services/khata_balance.dart';
import '../services/khata_entry_repository.dart';
import '../services/khata_pdf_service.dart';
import 'add_ledger_entry_screen.dart';
import 'add_party_screen.dart';
import 'khata_entry_detail_screen.dart';

enum _PartyMenuAction { edit, downloadPdf, createInvoice, delete }

enum _EntryAction { view, edit, share }

class PartyDetailScreen extends StatefulWidget {
  final Contact contact;
  const PartyDetailScreen({required this.contact, super.key});

  @override
  State<PartyDetailScreen> createState() => _PartyDetailScreenState();
}

class _PartyDetailScreenState extends State<PartyDetailScreen> {
  final _entryRepo = KhataEntryRepository();
  late Contact _contact = widget.contact;
  bool _loading = true;
  List<KhataEntry> _entries = [];
  List<int> _runningBalances = [];

  /// Entries auto-created from a Sales/Purchase bill share their id with
  /// that Invoice (see InvoiceRepository._syncKhataEntry) - keyed here so
  /// tapping one can open the real invoice instead of a plain ledger row.
  Map<String, Invoice> _invoicesById = {};

  bool get _isCustomer => _contact.type == ContactType.customer;
  String get _partyLabel => _isCustomer ? 'Customer' : 'Supplier';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final book = context.read<BookProvider>().currentBook!;
    final entries = await _entryRepo.entriesForContact(_contact.id);
    final invoices = await InvoiceRepository().watchInvoices(book.id).first;
    setState(() {
      _entries = entries;
      _runningBalances = runningBalances(entries);
      _invoicesById = {for (final inv in invoices) inv.id: inv};
      _loading = false;
    });
  }

  int get _balance => _runningBalances.isEmpty ? 0 : _runningBalances.last;

  Future<void> _call() async {
    final phone = _contact.phone?.trim();
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number saved for this party.')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open the dialer.")),
        );
      }
    }
  }

  Future<void> _whatsapp() async {
    final phone = _contact.phone?.trim();
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number saved for this party.')),
      );
      return;
    }
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    // Bare 10-digit numbers are assumed Indian and need the country code for
    // wa.me links to resolve to the right chat.
    if (digits.length == 10) digits = '91$digits';
    final uri = Uri.parse('https://wa.me/$digits');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open WhatsApp.")),
        );
      }
    }
  }

  Future<void> _addEntry(KhataEntryType type) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddLedgerEntryScreen(contact: _contact, type: type),
      ),
    );
    _load();
  }

  Future<void> _editContact() async {
    final book = context.read<BookProvider>().currentBook!;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPartyScreen(defaultType: _contact.type, existingContact: _contact),
      ),
    );
    final refreshed = await ContactRepository().loadContacts(book.id, type: _contact.type);
    final match = refreshed.where((c) => c.id == _contact.id);
    if (match.isNotEmpty && mounted) setState(() => _contact = match.first);
  }

  Future<void> _downloadLedgerPdf() async {
    final book = context.read<BookProvider>().currentBook!;
    final bytes = await KhataPdfService.generate(
      book: book,
      contact: _contact,
      entries: _entries,
      runningBalances: _runningBalances,
    );
    await Printing.sharePdf(bytes: bytes, filename: '${_contact.name}_ledger.pdf');
  }

  Future<void> _createInvoice() async {
    final book = context.read<BookProvider>().currentBook!;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateBillScreen(
          book: book,
          direction: _isCustomer ? BillDirection.sales : BillDirection.purchase,
          initialParty: _contact,
        ),
      ),
    );
  }

  Future<void> _deleteContact() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete this $_partyLabel?'),
        content: const Text('This can be recovered from support within the retention window.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ContactRepository().softDelete(_contact);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _showEntryActions(KhataEntry e) async {
    // Entries auto-created from a Sales/Purchase bill (see
    // InvoiceRepository._syncKhataEntry) share their id with that Invoice -
    // route to the real invoice instead of the plain ledger row for those.
    final invoice = _invoicesById[e.id];
    final isInvoice = invoice != null;

    final action = await showModalBottomSheet<_EntryAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: Text(isInvoice ? 'View Invoice' : 'View Entry'),
              onTap: () => Navigator.pop(ctx, _EntryAction.view),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(isInvoice ? 'Edit Invoice' : 'Edit Entry'),
              onTap: () => Navigator.pop(ctx, _EntryAction.edit),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(isInvoice ? 'Share Invoice' : 'Share Entry'),
              onTap: () => Navigator.pop(ctx, _EntryAction.share),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    if (isInvoice) {
      final book = context.read<BookProvider>().currentBook!;
      switch (action) {
        case _EntryAction.view:
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InvoicePreviewShareScreen(invoice: invoice, book: book),
            ),
          );
          break;
        case _EntryAction.edit:
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateBillScreen(
                book: book,
                direction: invoice.billDirection,
                existingInvoice: invoice,
              ),
            ),
          );
          break;
        case _EntryAction.share:
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InvoicePreviewShareScreen(
                invoice: invoice,
                book: book,
                autoAction: PreviewAutoAction.share,
              ),
            ),
          );
          break;
      }
      _load();
      return;
    }

    switch (action) {
      case _EntryAction.view:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => KhataEntryDetailScreen(entry: e, contact: _contact)),
        );
        break;
      case _EntryAction.edit:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddLedgerEntryScreen(contact: _contact, type: e.type, existingEntry: e),
          ),
        );
        _load();
        break;
      case _EntryAction.share:
        final isGave = e.type == KhataEntryType.youGave;
        final lines = [
          _contact.name,
          '${isGave ? 'You Gave' : 'You Got'}: ${Money.format(e.amountPaise)}',
          'Date: ${e.date.day}/${e.date.month}/${e.date.year}',
          if (e.description != null && e.description!.trim().isNotEmpty) e.description!,
        ];
        await Share.share(lines.join('\n'));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final writable = context.watch<BookProvider>().currentBookIsWritable;
    final balance = _balance;

    return Scaffold(
      appBar: AppBar(
        title: Text(_contact.name),
        actions: [
          IconButton(icon: const Icon(Icons.call), tooltip: 'Call', onPressed: _call),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.whatsapp),
            tooltip: 'WhatsApp',
            onPressed: _whatsapp,
          ),
          PopupMenuButton<_PartyMenuAction>(
            onSelected: (action) {
              switch (action) {
                case _PartyMenuAction.edit:
                  _editContact();
                  break;
                case _PartyMenuAction.downloadPdf:
                  _downloadLedgerPdf();
                  break;
                case _PartyMenuAction.createInvoice:
                  _createInvoice();
                  break;
                case _PartyMenuAction.delete:
                  _deleteContact();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(value: _PartyMenuAction.edit, child: Text('Edit $_partyLabel')),
              const PopupMenuItem(
                value: _PartyMenuAction.downloadPdf,
                child: Text('Download Ledger PDF'),
              ),
              const PopupMenuItem(
                value: _PartyMenuAction.createInvoice,
                child: Text('Create Bill'),
              ),
              PopupMenuItem(value: _PartyMenuAction.delete, child: Text('Delete $_partyLabel')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: balance == 0
                ? Colors.grey.shade100
                : (balance > 0 ? Colors.green.shade50 : Colors.red.shade50),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  balance == 0
                      ? 'Settled up'
                      : (balance > 0
                          ? (_isCustomer ? "You'll get" : "You'll pay")
                          : (_isCustomer ? "You'll pay" : "You'll get")),
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  Money.format(balance.abs()),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: balance == 0
                        ? Colors.grey.shade700
                        : (balance > 0 ? Colors.green.shade700 : Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? const Center(child: Text('No transactions yet.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _entries.length,
                        itemBuilder: (ctx, i) {
                          final e = _entries[i];
                          final isGave = e.type == KhataEntryType.youGave;
                          return ListTile(
                            title: Text(e.description?.trim().isNotEmpty == true
                                ? e.description!
                                : (isGave ? 'You Gave' : 'You Got')),
                            subtitle: Text(
                              '${e.date.day}/${e.date.month}/${e.date.year}'
                              '${e.attachments.isNotEmpty ? '  ·  📎' : ''}',
                            ),
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  Money.format(e.amountPaise),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isGave ? Colors.red.shade700 : Colors.green.shade700,
                                  ),
                                ),
                                Text(
                                  'Bal ${Money.format(_runningBalances[i].abs())}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                            onTap: () => _showEntryActions(e),
                          );
                        },
                      ),
          ),
          if (writable)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade700),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => _addEntry(KhataEntryType.youGave),
                        child: const Text('You Gave'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => _addEntry(KhataEntryType.youGot),
                        child: const Text('You Got'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
