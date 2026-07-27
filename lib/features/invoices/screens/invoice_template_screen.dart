import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/invoice_template.dart';
import '../../books/providers/book_provider.dart';
import 'invoice_template_preview_screen.dart';

/// Business Book only: pick which of the 10 InvoiceTemplateStyle presets
/// this book's invoices render with (InvoicePdfService reads
/// Book.invoiceTemplateId). Tapping a card opens a full sample invoice
/// (real PDF render, dummy data) via InvoiceTemplatePreviewScreen; "Use
/// This Template" there is what actually applies it, so every invoice
/// this book generates from then on shares the same look.
class InvoiceTemplateScreen extends StatefulWidget {
  const InvoiceTemplateScreen({super.key});

  @override
  State<InvoiceTemplateScreen> createState() => _InvoiceTemplateScreenState();
}

class _InvoiceTemplateScreenState extends State<InvoiceTemplateScreen> {
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    final book = context.read<BookProvider>().currentBook;
    _selectedId = invoiceTemplateById(book?.invoiceTemplateId).id;
  }

  Future<void> _openPreview(InvoiceTemplateStyle style) async {
    final applied = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => InvoiceTemplatePreviewScreen(style: style)),
    );
    if (applied == true && mounted) {
      setState(() => _selectedId = style.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${style.name}" is now this book\'s invoice template.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Template')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tap a template to see a full sample invoice, then apply it. '
                'It\'s used everywhere this book generates a bill.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.62,
              ),
              itemCount: kInvoiceTemplates.length,
              itemBuilder: (ctx, i) {
                final style = kInvoiceTemplates[i];
                return _TemplateCard(
                  style: style,
                  selected: style.id == _selectedId,
                  onTap: () => _openPreview(style),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final InvoiceTemplateStyle style;
  final bool selected;
  final VoidCallback onTap;

  const _TemplateCard({required this.style, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? primary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: primary.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _MockInvoicePreview(style: style)),
                  if (selected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: primary,
                        child: const Icon(Icons.check, size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(style.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                    style.description,
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A lightweight, fast Flutter-widget mock of the template's look - not a
/// real PDF render (that would need a full generate() round-trip per
/// card) but close enough to compare all 10 styles at a glance.
class _MockInvoicePreview extends StatelessWidget {
  final InvoiceTemplateStyle style;
  const _MockInvoicePreview({required this.style});

  Color get _primary => Color(style.primaryColor);
  Color get _accent => Color(style.accentColor);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          _buildTable(),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: Container(width: 46, height: 7, color: _primary),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isBand = style.headerLayout == InvoiceHeaderLayout.colorBand;
    final titleColor = isBand ? (style.lightTextOnAccent ? Colors.white : Colors.black) : _primary;
    final lineColor =
        isBand ? (style.lightTextOnAccent ? Colors.white70 : Colors.black54) : Colors.grey.shade400;

    final content = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 40, height: 6, color: titleColor),
            const SizedBox(height: 4),
            Container(width: 28, height: 3, color: lineColor),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(width: 26, height: 5, color: titleColor),
            const SizedBox(height: 4),
            Container(width: 20, height: 3, color: lineColor),
          ],
        ),
      ],
    );

    switch (style.headerLayout) {
      case InvoiceHeaderLayout.plain:
        return content;
      case InvoiceHeaderLayout.colorBand:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(3)),
          child: content,
        );
      case InvoiceHeaderLayout.sidebarAccent:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: _primary),
            const SizedBox(width: 6),
            Expanded(child: content),
          ],
        );
    }
  }

  Widget _buildTable() {
    switch (style.tableStyle) {
      case InvoiceTableStyle.bordered:
        return Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400, width: 0.6)),
          child: Column(
            children: [
              Container(height: 10, color: _accent),
              for (var i = 0; i < 3; i++)
                Container(
                  height: 9,
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey.shade300, width: 0.5)),
                  ),
                ),
            ],
          ),
        );
      case InvoiceTableStyle.striped:
        return Column(
          children: [
            Container(height: 10, color: _primary),
            for (var i = 0; i < 3; i++) Container(height: 9, color: i.isOdd ? _accent : Colors.white),
          ],
        );
      case InvoiceTableStyle.minimalLines:
        return Column(
          children: [
            Container(
              height: 9,
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _primary, width: 1))),
            ),
            for (var i = 0; i < 3; i++)
              Container(
                height: 9,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.5)),
                ),
              ),
          ],
        );
    }
  }
}
