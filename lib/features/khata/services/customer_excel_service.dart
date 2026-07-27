import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../../core/models/contact_model.dart';

/// Business Book, Customers section only: "Download all customers data
/// having outstanding amount greater than zero" - Name/Mobile/Address, so
/// the user has a follow-up-ready contact list for who owes them money.
/// The outstanding-amount filtering itself happens in the caller (it needs
/// the balance map computed by PartyListScreen); this just formats
/// whichever contacts it's given.
class CustomerExcelService {
  CustomerExcelService._();

  static Uint8List generate(List<Contact> customers) {
    final excel = Excel.createExcel();
    const sheetName = 'Customers';
    excel.rename(excel.getDefaultSheet()!, sheetName);

    excel.appendRow(sheetName, [
      TextCellValue('Name'),
      TextCellValue('Mobile Number'),
      TextCellValue('Address'),
    ]);

    for (final c in customers) {
      excel.appendRow(sheetName, [
        TextCellValue(c.name),
        TextCellValue(c.phone ?? ''),
        TextCellValue(c.address ?? ''),
      ]);
    }

    final bytes = excel.encode()!;
    return Uint8List.fromList(bytes);
  }
}
