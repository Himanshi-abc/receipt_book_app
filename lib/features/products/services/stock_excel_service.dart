import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../../../core/models/product_model.dart';
import '../../../core/utils/money.dart';

/// Exports the product/service catalog as a .xlsx file - one row per
/// product. This is a catalog export, not a live stock-quantity report:
/// the product form has no quantity-on-hand field today.
class StockExcelService {
  StockExcelService._();

  static Uint8List generate(List<Product> products) {
    final excel = Excel.createExcel();
    const sheetName = 'Products';
    excel.rename(excel.getDefaultSheet()!, sheetName);

    excel.appendRow(sheetName, [
      TextCellValue('Name'),
      TextCellValue('Type'),
      TextCellValue('Selling Price'),
      TextCellValue('Price Type'),
      TextCellValue('Tax Rate %'),
      TextCellValue('Purchase Price'),
      TextCellValue('HSN Code'),
      TextCellValue('Unit'),
      TextCellValue('Category'),
    ]);

    for (final p in products) {
      excel.appendRow(sheetName, [
        TextCellValue(p.name),
        TextCellValue(p.type == ProductItemType.product ? 'Product' : 'Service'),
        DoubleCellValue(Money.paiseToRupees(p.sellingPricePaise)),
        TextCellValue(p.priceIncludesTax ? 'With Tax' : 'Without Tax'),
        DoubleCellValue(p.taxRatePercent),
        p.purchasePricePaise != null
            ? DoubleCellValue(Money.paiseToRupees(p.purchasePricePaise!))
            : TextCellValue(''),
        TextCellValue(p.hsnCode ?? ''),
        TextCellValue(p.unit ?? ''),
        TextCellValue(p.category ?? ''),
      ]);
    }

    final bytes = excel.encode()!;
    return Uint8List.fromList(bytes);
  }
}
