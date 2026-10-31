import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopdesk/features/auth/application/auth_controller.dart';
import 'package:shopdesk/features/auth/domain/auth_failure.dart';
import 'package:shopdesk/features/auth/domain/auth_validators.dart';
import 'package:shopdesk/features/auth/presentation/widgets/auth_layout.dart';
import 'package:shopdesk/features/auth/presentation/widgets/password_field.dart';

/// Reached only after the emailed code was accepted. Saving signs the owner in.
class NewPasswordPage extends ConsumerStatefulWidget {
  const NewPasswordPage({super.key});

  @override
  ConsumerState<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends ConsumerState<NewPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authControllerProvider.notifier).setNewPassword(_password.text);
      messenger.showSnackBar(const SnackBar(content: Text('Password updated. You are signed in.')));
      // The router moves to Home as soon as the owner is signed in.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Set a new password',
      subtitle: 'Your email is verified. Choose a new password.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PasswordField(
                controller: _password,
                label: 'New password',
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                validator: AuthValidators.password,
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _confirm,
                label: 'Confirm new password',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: AuthValidators.matches(() => _password.text),
              ),
              AuthErrorText(_error),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save new password'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
