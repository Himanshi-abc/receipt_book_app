import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/utils/auth_error_text.dart';
import '../../../core/utils/auth_validators.dart';
import '../../../core/widgets/app_password_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_scaffold.dart';
import 'forgot_password_screen.dart';
import 'otp_screen.dart';
import 'signup_screen.dart';

/// The single Login screen: one identifier field that accepts either an
/// email or a mobile number, plus a password field.
///
/// Firebase's phone provider is OTP-only (there is no phone+password sign
/// in), so when the identifier looks like a mobile number the password is
/// set aside and this instead sends an OTP and hands off to [OtpScreen] -
/// the same email-uses-password / phone-uses-OTP split every mainstream
/// Indian app (Google Pay, PhonePe, ...) uses, and the only combination
/// Firebase Auth actually supports without a custom backend.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _busy = false;
  String? _error;
  bool _identifierLooksLikePhone = false;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    // Resolved before the first await: the catch block below may run after
    // this screen has been popped, when looking up a context is unsafe.
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final identifier = _identifierCtrl.text.trim();
      final auth = context.read<AuthProvider>();
      if (AuthValidators.isEmail(identifier)) {
        await auth.signInWithEmail(identifier, _passwordCtrl.text);
        // Navigation on success is handled by the auth-state listener in app.dart.
      } else {
        final phone = AuthValidators.normalizePhone(identifier);
        await auth.sendOtp(phone);
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OtpScreen(purpose: OtpPurpose.login, phoneNumber: phone),
        ));
      }
    } catch (e) {
      setState(() => _error = authErrorText(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthScaffold(
      title: l10n.loginTitle,
      subtitle: l10n.loginSubtitle,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) AuthErrorBanner(message: _error!),
            TextFormField(
              controller: _identifierCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              validator: (v) => AuthValidators.validateEmailOrPhone(l10n, v),
              onChanged: (v) => setState(
                () => _identifierLooksLikePhone =
                    v.trim().isNotEmpty && !AuthValidators.isEmail(v) && AuthValidators.isPhone(v),
              ),
              decoration: InputDecoration(
                labelText: l10n.emailOrMobileLabel,
                hintText: l10n.emailOrMobileHint,
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPasswordField(
              controller: _passwordCtrl,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) => _identifierLooksLikePhone
                  ? null
                  : AuthValidators.validatePassword(l10n, v),
            ),
            if (_identifierLooksLikePhone) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.phoneLoginUsesOtpHint,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.tones.textTertiary),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                        ),
                child: Text(l10n.forgotPassword),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_identifierLooksLikePhone ? l10n.sendOtp : l10n.logIn),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l10n.noAccountYet,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: context.tones.textSecondary)),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SignUpScreen()),
                          ),
                  child: Text(l10n.signUp),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
