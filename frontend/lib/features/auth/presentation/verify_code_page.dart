import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopdesk/core/config/app_config.dart';
import 'package:shopdesk/features/auth/application/auth_controller.dart';
import 'package:shopdesk/features/auth/domain/auth_failure.dart';
import 'package:shopdesk/features/auth/presentation/widgets/auth_layout.dart';

enum VerifyPurpose { signUp, reset }

class VerifyArgs {
  const VerifyArgs(this.email, this.purpose);
  final String email;
  final VerifyPurpose purpose;
}

/// "Yes, it is me": the owner types the 6-digit code that was emailed.
/// Used for sign-up and for forgot password.
class VerifyCodePage extends ConsumerStatefulWidget {
  const VerifyCodePage({super.key, required this.args});
  final VerifyArgs args;

  @override
  ConsumerState<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends ConsumerState<VerifyCodePage> {
  static const _cooldownSeconds = 30;

  final _code = TextEditingController();
  Timer? _timer;
  int _cooldown = _cooldownSeconds;
  bool _busy = false;
  String? _error;

  bool get _isSignUp => widget.args.purpose == VerifyPurpose.signUp;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = _cooldownSeconds);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) {
        t.cancel();
        if (mounted) setState(() => _cooldown = 0);
      } else if (mounted) {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authControllerProvider.notifier);
    try {
      if (_isSignUp) {
        await auth.verifySignUp(widget.args.email, code); // router moves to Home
      } else {
        await auth.verifyResetCode(widget.args.email, code);
        if (mounted) context.pushReplacement('/reset-password');
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final auth = ref.read(authControllerProvider.notifier);
    try {
      if (_isSignUp) {
        await auth.resendSignUpCode(widget.args.email);
      } else {
        await auth.requestPasswordReset(widget.args.email);
      }
      _startCooldown();
      if (mounted) {
        setState(() => _error = null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A new code is on its way.')));
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final demoCode = AppConfig.isDemo ? ref.watch(demoCodeProvider) : null;
    return AuthLayout(
      title: 'Check your email',
      subtitle: _isSignUp
          ? 'We sent a 6-digit code to ${widget.args.email}. Enter it to confirm this is you.'
          : 'If an account exists for ${widget.args.email}, we sent a 6-digit code. Enter it to continue.',
      children: [
        if (AppConfig.isDemo)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(10)),
            child: Text(
              demoCode == null
                  ? 'Demo mode: no email is sent, and no code is made for an unknown email.'
                  : 'Demo mode: no email is sent. Your code is $demoCode.',
              style: TextStyle(color: scheme.onTertiaryContainer, fontWeight: FontWeight.w600),
            ),
          ),
        TextField(
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(counterText: '', hintText: '------'),
          onChanged: (v) {
            if (v.length == 6 && !_busy) _verify();
          },
          onSubmitted: (_) => _verify(),
        ),
        AuthErrorText(_error),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Verify'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _cooldown == 0 ? _resend : null,
          child: Text(_cooldown == 0 ? 'Send a new code' : 'Send a new code in ${_cooldown}s'),
        ),
        TextButton(onPressed: () => context.pop(), child: const Text('Wrong email? Go back')),
      ],
    );
  }
}
