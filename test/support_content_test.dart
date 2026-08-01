import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:receipt_book/core/design/app_theme.dart';
import 'package:receipt_book/features/settings/models/support_content.dart';
import 'package:receipt_book/features/settings/screens/faq_screen.dart';
import 'package:receipt_book/features/settings/screens/legal_document_screen.dart';

/// Help & Support and About Us content, and the two screens that render it.
void main() {
  group('support content', () {
    test('every FAQ has a question, an answer and a category', () {
      expect(kFaqs, isNotEmpty);
      for (final faq in kFaqs) {
        expect(faq.question.trim(), isNotEmpty, reason: faq.question);
        expect(faq.answer.trim(), isNotEmpty, reason: faq.question);
        expect(faq.category.trim(), isNotEmpty, reason: faq.question);
      }
    });

    test('no duplicate FAQ questions', () {
      final questions = kFaqs.map((f) => f.question).toList();
      expect(questions.toSet().length, questions.length);
    });

    test('every legal document has a title, a date and non-empty sections', () {
      for (final doc in [kAboutReceiptBook, kPrivacyPolicy, kTermsAndConditions]) {
        expect(doc.title.trim(), isNotEmpty);
        expect(doc.lastUpdated.trim(), isNotEmpty);
        expect(doc.sections, isNotEmpty, reason: doc.title);
        for (final section in doc.sections) {
          expect(
            section.paragraphs.isNotEmpty || section.bullets.isNotEmpty,
            isTrue,
            reason: '${doc.title} / ${section.heading}',
          );
        }
      }
    });

    test('the Terms disclaim tax advice', () {
      // The app has an ITR helper, so "this is not professional advice" is
      // the one clause that must never be edited away by accident.
      final text = kTermsAndConditions.sections
          .expand((s) => [...s.paragraphs, ...s.bullets])
          .join(' ')
          .toLowerCase();

      expect(text, contains('not'));
      expect(text, contains('tax'));
      expect(text, contains('advice'));
    });

    test('the WhatsApp number is digits only, as wa.me requires', () {
      expect(SupportContacts.whatsappNumber, matches(RegExp(r'^\d+$')));
    });
  });

  Widget host(Widget child) => MaterialApp(theme: AppTheme.light(), home: child);

  group('FaqScreen', () {
    testWidgets('lists categories and expands an answer on tap', (tester) async {
      await tester.pumpWidget(host(const FaqScreen()));
      await tester.pumpAndSettle();

      expect(find.text('GETTING STARTED'), findsOneWidget);
      expect(find.text('What is ReceiptBook?'), findsOneWidget);

      // Collapsed to begin with.
      expect(find.textContaining('record-keeping app'), findsNothing);

      await tester.tap(find.text('What is ReceiptBook?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('record-keeping app'), findsOneWidget);
    });

    testWidgets('search matches answer text, not just question text',
        (tester) async {
      await tester.pumpWidget(host(const FaqScreen()));
      await tester.pumpAndSettle();

      // "IGST" appears in an answer; no question title contains it.
      await tester.enterText(find.byType(TextField), 'IGST');
      await tester.pumpAndSettle();

      expect(
        find.text('Why does my invoice show CGST and SGST instead of IGST?'),
        findsOneWidget,
      );
      expect(find.text('What is ReceiptBook?'), findsNothing);
    });

    testWidgets('shows an empty state when nothing matches', (tester) async {
      await tester.pumpWidget(host(const FaqScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzzzzzz');
      await tester.pumpAndSettle();

      expect(find.text('No answers matched'), findsOneWidget);
    });
  });

  group('LegalDocumentScreen', () {
    testWidgets('renders headings, paragraphs and bullets', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        host(const LegalDocumentScreen(document: kPrivacyPolicy)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Privacy Policy'), findsAtLeastNWidgets(1));
      expect(
        find.text('Last updated ${kPrivacyPolicy.lastUpdated}'),
        findsOneWidget,
      );
      expect(find.text('1. Information you give us'), findsOneWidget);
    });

    testWidgets('all three documents render without layout errors',
        (tester) async {
      for (final doc in [kAboutReceiptBook, kPrivacyPolicy, kTermsAndConditions]) {
        await tester.pumpWidget(host(LegalDocumentScreen(document: doc)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: doc.title);
      }
    });
  });
}
