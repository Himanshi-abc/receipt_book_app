import '../../../core/models/book_model.dart';
import '../../../core/models/invoice_model.dart';

/// Entirely fake Book + Invoice used only to preview an InvoiceTemplateStyle
/// (see InvoiceTemplatePreviewScreen) - every Business Profile field is
/// filled in (name, GSTIN, phone, brand, both addresses, website, bank
/// details, signature) plus a realistic set of line items, so the preview
/// shows exactly what a real invoice would look like with nothing blank.
class DummyInvoiceData {
  DummyInvoiceData._();

  static Book book() => Book(
        id: 'preview-book',
        userId: 'preview-user',
        type: BookType.business,
        name: 'Aurora Retail Pvt. Ltd.',
        gstin: '27AAAPL1234C1ZV',
        state: 'Maharashtra',
        address: '221, Linking Road, Bandra West, Mumbai, Maharashtra 400050',
        phone: '+91 98765 43210',
        brandName: 'Aurora Retail',
        shippingAddress: 'Warehouse 4, MIDC Industrial Area, Andheri East, Mumbai 400093',
        website: 'www.auroraretail.example',
        bankDetails: BankAccountDetails(
          accountHolderName: 'Aurora Retail Pvt. Ltd.',
          bankName: 'HDFC Bank',
          accountNumber: '50100234567890',
          ifscCode: 'HDFC0000123',
        ),
        // Any non-null value is enough - InvoicePdfService only checks
        // presence to show the "Authorized Signatory" footer line, it
        // doesn't fetch/render the actual image bytes (see its doc comment).
        signatureUrl: 'preview-signature',
        createdAt: DateTime.now(),
      );

  static Invoice invoice() {
    final date = DateTime.now();
    final lineItems = [
      InvoiceLineItem(
        id: 'preview-1',
        description: 'Premium Cotton T-Shirt',
        hsnSac: '6109',
        qty: 3,
        rateePaise: 79900,
        taxRatePercent: 12,
      ),
      InvoiceLineItem(
        id: 'preview-2',
        description: 'Denim Jacket',
        hsnSac: '6201',
        qty: 1,
        rateePaise: 249900,
        taxRatePercent: 12,
      ),
      InvoiceLineItem(
        id: 'preview-3',
        description: 'Alteration Service',
        hsnSac: '9997',
        qty: 1,
        rateePaise: 15000,
        taxRatePercent: 18,
      ),
    ];

    return Invoice(
      id: 'preview-invoice',
      bookId: 'preview-book',
      docType: InvoiceDocType.invoice,
      billDirection: BillDirection.sales,
      invoiceNumber: 'INV-2026-0104',
      invoiceDate: date,
      customerContactId: 'preview-customer',
      customerName: 'Priya Sharma',
      customerState: 'Maharashtra',
      customerGstin: '27BBBCS5678D1ZK',
      lineItems: lineItems,
      discountPaise: 20000,
      additionalChargeDescription: 'Shipping & Handling',
      additionalChargePaise: 5000,
      amountReceivedPaise: 300000,
      paymentMode: 'UPI',
      createdAt: date,
    );
  }
}
