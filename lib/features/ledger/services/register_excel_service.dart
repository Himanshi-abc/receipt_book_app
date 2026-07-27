import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../../core/models/category_model.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/utils/money.dart';

/// Individual Book only: "Download all data in excel" for the Register
/// screen, given whatever list of transactions is already on screen (i.e.
/// with the active search/type/category/date filters applied). Attachments
/// are intentionally excluded - text fields only.
class RegisterExcelService {
  RegisterExcelService._();

  static String _categoryNameFor(String? categoryId) {
    if (categoryId == null) return '';
    final matches = Category.individualDefaults().where((c) => c.id == categoryId);
    return matches.isEmpty ? categoryId : matches.first.name;
  }

  static Uint8List generate(List<AppTransaction> transactions) {
    final excel = Excel.createExcel();
    const sheetName = 'Transactions';
    excel.rename(excel.getDefaultSheet()!, sheetName);

    excel.appendRow(sheetName, [
      TextCellValue('Date'),
      TextCellValue('Type'),
      TextCellValue('Vendor / Payer'),
      TextCellValue('Category'),
      TextCellValue('Amount'),
      TextCellValue('Notes'),
      TextCellValue('Financial Year'),
      TextCellValue('Tax Head'),
    ]);

    for (final t in transactions) {
      excel.appendRow(sheetName, [
        TextCellValue(
            '${t.date.day.toString().padLeft(2, '0')}/${t.date.month.toString().padLeft(2, '0')}/${t.date.year}'),
        TextCellValue(t.type == TxType.income ? 'Income' : 'Expense'),
        TextCellValue(t.vendorOrCustomerName),
        TextCellValue(_categoryNameFor(t.categoryId)),
        DoubleCellValue(Money.paiseToRupees(t.amountPaise)),
        TextCellValue(t.notes ?? ''),
        TextCellValue(t.financialYear),
        TextCellValue(t.taxHead ?? ''),
      ]);
    }

    final bytes = excel.encode()!;
    return Uint8List.fromList(bytes);
  }
}
