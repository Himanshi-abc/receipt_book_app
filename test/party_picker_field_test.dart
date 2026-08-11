import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:receipt_book/core/design/app_theme.dart';
import 'package:receipt_book/core/models/contact_model.dart';
import 'package:receipt_book/features/khata/widgets/party_picker_field.dart';
import 'package:receipt_book/l10n/app_localizations.dart';

/// The shared party picker used by both Bills (CreateBillScreen) and the
/// Business Book Register (OcrReviewFormScreen).
///
/// Only the two presentational states are covered here - every interactive
/// path (Select, Add, Import from Contacts) reaches either Firestore
/// (ContactRepository) or the device contacts permission plugin, neither of
/// which is available in a plain widget test without infrastructure this
/// repo doesn't have (no fakes/mocks are wired up for either). Same
/// constraint already noted for CreateBillScreen and OcrReviewFormScreen
/// themselves.
void main() {
  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        
        theme: AppTheme.light(),
        home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
      );

  group('nothing selected', () {
    testWidgets('offers Select / Add / Import, none of them a Card',
        (tester) async {
      await tester.pumpWidget(host(
        PartyPickerField(
          bookId: 'book-1',
          type: ContactType.customer,
          label: 'Customer',
          selected: null,
          onChanged: (_) {},
        ),
      ));

      expect(find.text('Select Customer'), findsOneWidget);
      expect(find.text('Add Customer'), findsOneWidget);
      expect(find.text('Import from Contacts'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('the party type, not the caller\'s label, drives both action '
        'buttons', (tester) async {
      // These buttons used to be built as 'Select $label' + 'Add $label'.
      // Gluing a verb onto a translated noun only produces a grammatical
      // phrase in English, so each type now maps to a whole translated
      // sentence and `label` no longer reaches them. A vendor picker
      // therefore reads "Supplier" (the Parties section's noun) even when
      // the caller passed the older 'Vendor' wording.
      await tester.pumpWidget(host(
        PartyPickerField(
          bookId: 'book-1',
          type: ContactType.vendor,
          label: 'Vendor',
          selected: null,
          onChanged: (_) {},
        ),
      ));

      expect(find.text('Select Supplier'), findsOneWidget);
      expect(find.text('Add Supplier'), findsOneWidget);
      expect(find.textContaining('Vendor'), findsNothing);
    });
  });

  group('a party is selected', () {
    testWidgets('collapses to a single card with a Change button',
        (tester) async {
      final contact = Contact(
        id: 'c1',
        bookId: 'book-1',
        name: 'Ramesh Traders',
        phone: '9876543210',
        type: ContactType.customer,
      );

      await tester.pumpWidget(host(
        PartyPickerField(
          bookId: 'book-1',
          type: ContactType.customer,
          label: 'Customer',
          selected: contact,
          onChanged: (_) {},
        ),
      ));

      expect(find.byType(Card), findsOneWidget);
      expect(find.text('Ramesh Traders'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);

      // The three-button chooser must not still be showing underneath.
      expect(find.text('Select Customer'), findsNothing);
      expect(find.text('Add Customer'), findsNothing);
      expect(find.text('Import from Contacts'), findsNothing);
    });

    testWidgets('a contact with no phone shows a blank subtitle, not "null"',
        (tester) async {
      final contact = Contact(
        id: 'c1',
        bookId: 'book-1',
        name: 'Daily Counter',
        type: ContactType.customer,
      );

      await tester.pumpWidget(host(
        PartyPickerField(
          bookId: 'book-1',
          type: ContactType.customer,
          label: 'Customer',
          selected: contact,
          onChanged: (_) {},
        ),
      ));

      expect(find.text('Daily Counter'), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
    });
  });
}
