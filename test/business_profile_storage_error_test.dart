import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:receipt_book/features/books/screens/business_profile_screen.dart';
import 'package:receipt_book/l10n/app_localizations_en.dart';

/// The logo/signature upload's Storage error messaging.
///
/// Context for the bug report this was written for: "uploading logo and
/// signature both are not working with some firestore storage popup error".
/// Both uploads go through the same FirebaseStorage code path, and this
/// screen is the *only* place in the app that surfaces a Storage failure to
/// the user at all - every other Storage upload (receipt photos, invoice
/// PDFs) fails silently and retries in the background. A project-wide
/// Storage outage - most plausibly the Firebase project still sitting on
/// the free Spark plan, which lost all Storage access project-wide as of
/// the Feb 2026 policy change - would look exactly like "only logo/
/// signature are broken" purely because this is the one screen that says
/// anything. These tests pin the message that's supposed to point at that.
void main() {
  // The message is localized now, so it needs an AppLocalizations. English
  // is instantiated directly rather than pumped through a widget - these
  // assertions are about the English copy this file has always pinned.
  final l10n = AppLocalizationsEn();

  group('businessProfileStorageErrorMessage', () {
    for (final code in ['unauthorized', 'unauthenticated', 'object-not-found', 'unknown']) {
      test('code "$code" is treated as a project-wide Storage problem, not '
          'a per-file one, and points at the Blaze plan requirement', () {
        final message = businessProfileStorageErrorMessage(
          l10n,
          FirebaseException(plugin: 'firebase_storage', code: code),
          isSignature: false,
        );

        expect(message, contains('Blaze'));
        expect(message, contains(code));
      });
    }

    test('names the logo vs the signature correctly', () {
      final logoMsg = businessProfileStorageErrorMessage(
        l10n,
        FirebaseException(plugin: 'firebase_storage', code: 'unauthorized'),
        isSignature: false,
      );
      final signatureMsg = businessProfileStorageErrorMessage(
        l10n,
        FirebaseException(plugin: 'firebase_storage', code: 'unauthorized'),
        isSignature: true,
      );

      expect(logoMsg, contains('logo'));
      expect(logoMsg, isNot(contains('signature')));
      expect(signatureMsg, contains('signature'));
    });

    test('an unrelated code falls back to the raw Firebase detail, not a '
        'billing guess', () {
      final message = businessProfileStorageErrorMessage(
        l10n,
        FirebaseException(
          plugin: 'firebase_storage',
          code: 'canceled',
          message: 'User canceled the upload',
        ),
        isSignature: false,
      );

      expect(message, isNot(contains('Blaze')));
      expect(message, contains('canceled'));
      expect(message, contains('User canceled the upload'));
    });

    test('a missing message still produces readable text', () {
      final message = businessProfileStorageErrorMessage(
        l10n,
        FirebaseException(plugin: 'firebase_storage', code: 'canceled'),
        isSignature: false,
      );

      expect(message, isNotEmpty);
      expect(message, contains('canceled'));
    });
  });
}
