import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopdesk/features/auth/application/auth_controller.dart';
import 'package:shopdesk/features/auth/domain/auth_failure.dart';
import 'package:shopdesk/features/auth/domain/auth_validators.dart';
import 'package:shopdesk/features/auth/presentation/verify_code_page.dart';
import 'package:shopdesk/features/auth/presentation/widgets/auth_layout.dart';
import 'package:shopdesk/features/auth/presentation/widgets/password_field.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authControllerProvider.notifier);
    final email = _email.text.trim();
    try {
      await auth.signIn(email, _password.text);
      // The router moves to Home as soon as the owner is signed in.
    } on AuthFailure catch (e) {
      if (e.kind == AuthFailureKind.emailNotVerified) {
        // Right password but the email was never confirmed: send a fresh code.
        try {
          await auth.resendSignUpCode(email);
          if (mounted) context.push('/verify', extra: VerifyArgs(email, VerifyPurpose.signUp));
        } on AuthFailure catch (e2) {
          if (mounted) setState(() => _error = e2.text);
        }
      } else if (mounted) {
        setState(() => _error = e.text);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSignUp = ref.watch(canSignUpProvider);
    return AuthLayout(
      title: 'Sign in',
      subtitle: 'Use your owner account to open the shop.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: AuthValidators.email,
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _password,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => context.push('/forgot'), child: const Text('Forgot password?')),
              ),
              AuthErrorText(_error),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Sign in'),
              ),
            ],
          ),
        ),
        if (canSignUp) ...[
          const SizedBox(height: 12),
          TextButton(onPressed: () => context.pushReplacement('/signup'), child: const Text('New here? Create the owner account')),
        ],
      ],
    );
  }
}
