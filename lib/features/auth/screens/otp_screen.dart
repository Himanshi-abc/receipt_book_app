import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/utils/auth_error_text.dart';
import '../../../core/widgets/app_otp_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_scaffold.dart';
import 'set_new_password_screen.dart';

/// What the verified OTP is being used for - each maps to a different
/// [AuthProvider] call and a different next screen once verified.
enum OtpPurpose { login, signup, resetPassword }

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.purpose,
    this.phoneNumber,
    this.pendingEmail,
    this.pendingPassword,
  }) : assert(
          purpose != OtpPurpose.signup ||
              (pendingEmail != null && pendingPassword != null),
          'signup OTP verification needs the pending email + password to link',
        );

  final OtpPurpose purpose;

  /// Shown to the user and used to resend the code.
  final String? phoneNumber;

  /// Only used for [OtpPurpose.signup].
  final String? pendingEmail;
  final String? pendingPassword;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpKey = GlobalKey<AppOtpFieldState>();
  bool _busy = false;
  String? _error;
  String _code = '';

  Timer? _resendTimer;
  int _resendSecondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendSecondsLeft = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _resendSecondsLeft--);
      if (_resendSecondsLeft <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    if (widget.phoneNumber == null || _resendSecondsLeft > 0) return;
    // Captured before the first await - see LoginScreen._submit.
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().sendOtp(widget.phoneNumber!);
      _otpKey.currentState?.clear();
      _startResendCountdown();
    } catch (e) {
      setState(() => _error = authErrorText(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify(String code) async {
    // Captured before the first await - see LoginScreen._submit.
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      switch (widget.purpose) {
        case OtpPurpose.login:
          await auth.verifyOtp(code);
          if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
          break;
        case OtpPurpose.signup:
          await auth.completeSignUp(
            smsCode: code,
            email: widget.pendingEmail!,
            password: widget.pendingPassword!,
          );
          if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
          break;
        case OtpPurpose.resetPassword:
          await auth.verifyOtpForPasswordReset(code);
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const SetNewPasswordScreen()),
            );
          }
          break;
      }
    } catch (e) {
      setState(() => _error = authErrorText(l10n, e));
      _otpKey.currentState?.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subtitle = widget.phoneNumber != null
        ? l10n.otpSentToNumber(widget.phoneNumber!)
        : l10n.otpSentToYourMobile;
    return AuthScaffold(
      title: l10n.verifyMobileTitle,
      subtitle: subtitle,
      leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) AuthErrorBanner(message: _error!),
          AppOtpField(
            key: _otpKey,
            hasError: _error != null,
            onChanged: (v) => _code = v,
            onCompleted: (code) {
              _code = code;
              _verify(code);
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
          FilledButton(
            onPressed: _busy || _code.length < 6 ? null : () => _verify(_code),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(l10n.verify),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: TextButton(
              onPressed: (_busy || _resendSecondsLeft > 0) ? null : _resend,
              child: Text(_resendSecondsLeft > 0
                  ? l10n.resendCodeIn(_resendSecondsLeft)
                  : l10n.resendCode),
            ),
          ),
        ],
      ),
    );
  }
}
