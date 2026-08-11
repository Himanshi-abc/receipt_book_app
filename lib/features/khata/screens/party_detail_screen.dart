import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/models/contact_model.dart';
import '../../../core/models/khata_entry_model.dart';
import '../../../core/services/contact_repository.dart';
import '../../../core/utils/money.dart';
import '../../../l10n/app_localizations.dart';
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

  /// The Customer/Supplier noun this screen builds its menu items and
  /// delete prompt around. `partySupplier` rather than `partyVendor`: the
  /// Parties section has always said "Supplier", and only the receipt form
  /// says "Vendor".
  String _partyLabel(AppLocalizations l10n) =>
      _isCustomer ? l10n.partyCustomer : l10n.partySupplier;

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
    final l10n = AppLocalizations.of(context);
    final phone = _contact.phone?.trim();
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noPhoneSaved)),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.couldNotOpenDialer)),
        );
      }
    }
  }

  Future<void> _whatsapp() async {
    final l10n = AppLocalizations.of(context);
    final phone = _contact.phone?.trim();
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noPhoneSaved)),
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
          SnackBar(content: Text(l10n.couldNotOpenWhatsapp)),
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
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deletePartyTitle(_partyLabel(l10n))),
        content: Text(l10n.deletePartyMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.actionCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.actionDelete)),
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
    final l10n = AppLocalizations.of(context);
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
              title: Text(isInvoice ? l10n.viewInvoice : l10n.viewEntry),
              onTap: () => Navigator.pop(ctx, _EntryAction.view),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(isInvoice ? l10n.editInvoice : l10n.editEntry),
              onTap: () => Navigator.pop(ctx, _EntryAction.edit),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(isInvoice ? l10n.shareInvoice : l10n.shareEntry),
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
        // Shared in the sender's app language, composed from the same keys
        // the screen itself uses rather than a separate message template.
        final lines = [
          _contact.name,
          '${isGave ? l10n.khataYouGave : l10n.khataYouGot}: '
              '${Money.format(e.amountPaise)}',
          '${l10n.date}: ${e.date.day}/${e.date.month}/${e.date.year}',
          if (e.description != null && e.description!.trim().isNotEmpty) e.description!,
        ];
        await Share.share(lines.join('\n'));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tones = context.tones;
    final writable = context.watch<BookProvider>().currentBookIsWritable;
    final balance = _balance;
    final partyLabel = _partyLabel(l10n);

    // Ported from fixed green/red shades to the theme's tones - the
    // hardcoded shade50 backgrounds were near-white boxes in dark mode.
    // The sign-to-tone mapping is deliberately left as it was: a positive
    // balance reads positive whichever party type this is.
    final balanceTone = balance == 0
        ? tones.neutral
        : (balance > 0 ? tones.positive : tones.negative);

    return Scaffold(
      appBar: AppBar(
        title: Text(_contact.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
              icon: const Icon(Icons.call), tooltip: l10n.actionCall, onPressed: _call),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.whatsapp),
            tooltip: l10n.actionWhatsapp,
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
              PopupMenuItem(
                value: _PartyMenuAction.edit,
                child: Text(l10n.editParty(partyLabel)),
              ),
              PopupMenuItem(
                value: _PartyMenuAction.downloadPdf,
                child: Text(l10n.downloadLedgerPdf),
              ),
              PopupMenuItem(
                value: _PartyMenuAction.createInvoice,
                child: Text(l10n.createBill),
              ),
              PopupMenuItem(
                value: _PartyMenuAction.delete,
                child: Text(l10n.deleteParty(partyLabel)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: balanceTone.bg,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  balance == 0
                      ? l10n.settledUp
                      : (balance > 0
                          ? (_isCustomer ? l10n.youWillGet : l10n.youWillPay)
                          : (_isCustomer ? l10n.youWillPay : l10n.youWillGet)),
                  style: theme.textTheme.bodyMedium?.copyWith(color: tones.textSecondary),
                ),
                // A settled-up lakh-scale balance is the widest thing on
                // this screen; shrink it rather than clip it on a phone.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Money.format(balance.abs()),
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(color: balanceTone.fg, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? Center(child: Text(l10n.noTransactionsTitle))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        itemCount: _entries.length,
                        itemBuilder: (ctx, i) {
                          final e = _entries[i];
                          final isGave = e.type == KhataEntryType.youGave;
                          return ListTile(
                            title: Text(
                              e.description?.trim().isNotEmpty == true
                                  ? e.description!
                                  : (isGave ? l10n.khataYouGave : l10n.khataYouGot),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${e.date.day}/${e.date.month}/${e.date.year}'
                              '${e.attachments.isNotEmpty ? '  ·  📎' : ''}',
                            ),
                            // A ListTile gives `trailing` no width of its
                            // own, so two lakh-scale amounts here used to
                            // squeeze the title to a few characters on a
                            // phone. Capped, and each line shrinks to fit
                            // rather than being cut off.
                            trailing: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 128),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      Money.format(e.amountPaise),
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isGave
                                            ? tones.negative.fg
                                            : tones.positive.fg,
                                      ),
                                    ),
                                  ),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      l10n.balanceShort(
                                          Money.format(_runningBalances[i].abs())),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: tones.textTertiary),
                                    ),
                                  ),
                                ],
                              ),
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
                padding: const EdgeInsets.all(AppSpacing.md),
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
                        // Translations of these run longer than the English
                        // ("ਤੁਹਾਨੂੰ ਮਿਲਣੇ ਹਨ"), and half a phone width is all
                        // each button gets - shrink rather than wrap to two
                        // lines and change the bar's height.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(l10n.khataYouGave, maxLines: 1),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => _addEntry(KhataEntryType.youGot),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(l10n.khataYouGot, maxLines: 1),
                        ),
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
