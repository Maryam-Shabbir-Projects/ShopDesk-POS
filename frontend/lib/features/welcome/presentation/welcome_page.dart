import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopdesk/core/constants/app_constants.dart';
import 'package:shopdesk/core/theme/app_theme.dart';
import 'package:shopdesk/features/auth/application/auth_controller.dart';

/// First screen: icon, welcome message, Sign in, and (until an owner exists)
/// Create owner account.
class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSignUp = ref.watch(canSignUpProvider);
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(22)),
                  child: Icon(Icons.storefront_outlined, size: 44, color: scheme.onPrimary),
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome to ${AppConstants.appName}',
                  textAlign: TextAlign.center,
                  style: AppTheme.cursiveTitle(brightness, size: 32),
                ),
                const SizedBox(height: 10),
                Text(
                  'Sell, track stock and see what to reorder.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(onPressed: () => context.push('/signin'), child: const Text('Sign in')),
                      if (canSignUp) ...[
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () => context.push('/signup'),
                          child: const Text('Create owner account'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
