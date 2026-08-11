import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/support_content.dart';
import '../../../l10n/app_localizations.dart';

/// Opens the outside-the-app support channels.
///
/// Both calls fail softly. The Windows build has no dialer and often no
/// WhatsApp, and a dead-end error there helps nobody - so the fallback
/// shows the number itself, which the user can act on.
class SupportLauncher {
  SupportLauncher._();

  static Future<void> whatsApp(BuildContext context) async {
    final uri = Uri.parse(
      'https://wa.me/${SupportContacts.whatsappNumber}'
      '?text=${Uri.encodeComponent(SupportContacts.whatsappGreeting)}',
    );
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      _notify(
        context,
        AppLocalizations.of(context)
            .couldNotOpenWhatsappMessageUs(SupportContacts.phoneNumber),
      );
    }
  }

  static Future<void> call(BuildContext context) async {
    final digits = SupportContacts.phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    var opened = false;
    try {
      opened = await launchUrl(Uri(scheme: 'tel', path: digits));
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      _notify(
          context,
          AppLocalizations.of(context)
              .callUsOnNumber(SupportContacts.phoneNumber));
    }
  }

  static void _notify(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
    );
  }
}
