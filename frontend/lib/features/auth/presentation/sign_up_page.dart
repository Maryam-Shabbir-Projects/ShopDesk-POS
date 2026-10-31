import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopdesk/features/auth/application/auth_controller.dart';
import 'package:shopdesk/features/auth/domain/auth_failure.dart';
import 'package:shopdesk/features/auth/domain/auth_validators.dart';
import 'package:shopdesk/features/auth/presentation/verify_code_page.dart';
import 'package:shopdesk/features/auth/presentation/widgets/auth_layout.dart';
import 'package:shopdesk/features/auth/presentation/widgets/password_field.dart';

/// Creates the owner account. After this the app emails a 6-digit code and
/// the owner is signed in only once it is entered.
class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final email = _email.text.trim();
    try {
      await ref.read(authControllerProvider.notifier).signUp(email, _password.text);
      if (mounted) context.push('/verify', extra: VerifyArgs(email, VerifyPurpose.signUp));
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Create owner account',
      subtitle: 'We will email a 6-digit code to confirm that this email is yours.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: AuthValidators.email,
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _password,
                label: 'Password',
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                validator: AuthValidators.password,
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _confirm,
                label: 'Confirm password',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: AuthValidators.matches(() => _password.text),
              ),
              const SizedBox(height: 6),
              Text(
                'At least 8 characters, with a letter and a number.',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              AuthErrorText(_error),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Send verification code'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: () => context.pushReplacement('/signin'), child: const Text('Already have an account? Sign in')),
      ],
    );
  }
}
