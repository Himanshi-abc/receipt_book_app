import '../../../core/models/khata_entry_model.dart';

/// Outstanding balance for one party, in paise.
/// Positive => the party owes the business ("You'll get").
/// Negative => the business owes the party ("You'll pay").
///
/// This is a plain running total (sum of You Gave minus sum of You Got),
/// not per-bill FIFO matching - matches how the real Khatabook app works,
/// and gives "a payment settles the oldest bill first" for free since
/// there's only ever one aggregate number, never separate tracked bills.
int outstandingPaiseFor(List<KhataEntry> entries) {
  var balance = 0;
  for (final e in entries) {
    balance += e.type == KhataEntryType.youGave ? e.amountPaise : -e.amountPaise;
  }
  return balance;
}

/// For a chronologically-sorted (oldest first) list of one party's entries,
/// returns the running balance after each entry, same length/order as
/// [chronological] - used to show a running total per row on the party
/// detail screen.
List<int> runningBalances(List<KhataEntry> chronological) {
  var balance = 0;
  final result = <int>[];
  for (final e in chronological) {
    balance += e.type == KhataEntryType.youGave ? e.amountPaise : -e.amountPaise;
    result.add(balance);
  }
  return result;
}
