/// Invoice PDF appearance, selectable per Business Book (see
/// InvoiceTemplateScreen) and applied consistently to every invoice that
/// book generates thereafter (InvoicePdfService).
///
/// Deliberately framework-agnostic (no `pdf` or `flutter` imports) so this
/// one catalog can back both the PDF renderer and the Flutter template
/// picker's preview cards - colors are stored as plain 0xAARRGGBB ints and
/// converted to PdfColor/Color at the point of use.
enum InvoiceHeaderLayout {
  /// Two-column header, plain white background - logo/business info on
  /// the left, document type/number/date on the right.
  plain,

  /// Same two columns, wrapped in a full-width colored band.
  colorBand,

  /// A slim colored vertical bar down the left edge, plain content beside it.
  sidebarAccent,
}

enum InvoiceTableStyle {
  /// Full grid lines around every cell.
  bordered,

  /// No grid - alternating row tint (zebra striping) instead.
  striped,

  /// Just a thin rule under the header and between rows - the most
  /// whitespace-heavy option.
  minimalLines,
}

class InvoiceTemplateStyle {
  final String id;
  final String name;
  final String description;

  /// Primary brand accent - header text/band color, table header rule,
  /// and the Grand Total emphasis color.
  final int primaryColor;

  /// Secondary tint - striped-row background / bordered table header fill.
  final int accentColor;

  final InvoiceHeaderLayout headerLayout;
  final InvoiceTableStyle tableStyle;

  /// True when the header band/sidebar is dark enough to need white text.
  final bool lightTextOnAccent;

  const InvoiceTemplateStyle({
    required this.id,
    required this.name,
    required this.description,
    required this.primaryColor,
    required this.accentColor,
    required this.headerLayout,
    required this.tableStyle,
    this.lightTextOnAccent = false,
  });
}

/// Ten distinct, professionally themed templates - a mix of classic,
/// modern, bold, and premium looks, spanning all three header layouts and
/// all three table styles so there's real visual variety to choose from.
const List<InvoiceTemplateStyle> kInvoiceTemplates = [
  InvoiceTemplateStyle(
    id: 'classic_mono',
    name: 'Classic',
    description: 'Traditional black & white GST invoice - formal and print-friendly.',
    primaryColor: 0xFF212121,
    accentColor: 0xFFEEEEEE,
    headerLayout: InvoiceHeaderLayout.plain,
    tableStyle: InvoiceTableStyle.bordered,
  ),
  InvoiceTemplateStyle(
    id: 'modern_blue',
    name: 'Modern Blue',
    description: 'Clean minimal layout with a crisp blue accent.',
    primaryColor: 0xFF1565C0,
    accentColor: 0xFFE3F2FD,
    headerLayout: InvoiceHeaderLayout.plain,
    tableStyle: InvoiceTableStyle.minimalLines,
  ),
  InvoiceTemplateStyle(
    id: 'bold_navy',
    name: 'Bold Navy',
    description: 'Solid navy header band that puts your brand front and center.',
    primaryColor: 0xFF0D47A1,
    accentColor: 0xFFE3F2FD,
    headerLayout: InvoiceHeaderLayout.colorBand,
    tableStyle: InvoiceTableStyle.bordered,
    lightTextOnAccent: true,
  ),
  InvoiceTemplateStyle(
    id: 'emerald_fresh',
    name: 'Emerald Fresh',
    description: 'A fresh green accent for a modern, approachable brand.',
    primaryColor: 0xFF2E7D32,
    accentColor: 0xFFE8F5E9,
    headerLayout: InvoiceHeaderLayout.plain,
    tableStyle: InvoiceTableStyle.striped,
  ),
  InvoiceTemplateStyle(
    id: 'sunset_orange',
    name: 'Sunset Orange',
    description: 'Warm, energetic orange band for retail & hospitality.',
    primaryColor: 0xFFEF6C00,
    accentColor: 0xFFFFF3E0,
    headerLayout: InvoiceHeaderLayout.colorBand,
    tableStyle: InvoiceTableStyle.minimalLines,
    lightTextOnAccent: true,
  ),
  InvoiceTemplateStyle(
    id: 'royal_purple',
    name: 'Royal Purple',
    description: 'Premium purple sidebar accent with refined typography.',
    primaryColor: 0xFF6A1B9A,
    accentColor: 0xFFF3E5F5,
    headerLayout: InvoiceHeaderLayout.sidebarAccent,
    tableStyle: InvoiceTableStyle.bordered,
  ),
  InvoiceTemplateStyle(
    id: 'slate_minimal',
    name: 'Slate Minimal',
    description: 'Ultra-minimal grayscale design - maximum whitespace.',
    primaryColor: 0xFF37474F,
    accentColor: 0xFFECEFF1,
    headerLayout: InvoiceHeaderLayout.plain,
    tableStyle: InvoiceTableStyle.minimalLines,
  ),
  InvoiceTemplateStyle(
    id: 'crimson_bold',
    name: 'Crimson Bold',
    description: 'Bold red band for standout invoices that grab attention.',
    primaryColor: 0xFFC62828,
    accentColor: 0xFFFFEBEE,
    headerLayout: InvoiceHeaderLayout.colorBand,
    tableStyle: InvoiceTableStyle.bordered,
    lightTextOnAccent: true,
  ),
  InvoiceTemplateStyle(
    id: 'teal_corporate',
    name: 'Teal Corporate',
    description: 'Professional teal sidebar accent, ideal for services & consulting.',
    primaryColor: 0xFF00695C,
    accentColor: 0xFFE0F2F1,
    headerLayout: InvoiceHeaderLayout.sidebarAccent,
    tableStyle: InvoiceTableStyle.striped,
  ),
  InvoiceTemplateStyle(
    id: 'graphite_gold',
    name: 'Graphite & Gold',
    description: 'Premium dark header with a gold accent for a luxury feel.',
    primaryColor: 0xFF212121,
    accentColor: 0xFFFFD54F,
    headerLayout: InvoiceHeaderLayout.colorBand,
    tableStyle: InvoiceTableStyle.bordered,
    lightTextOnAccent: true,
  ),
];

InvoiceTemplateStyle invoiceTemplateById(String? id) => kInvoiceTemplates.firstWhere(
      (t) => t.id == id,
      orElse: () => kInvoiceTemplates.first,
    );
