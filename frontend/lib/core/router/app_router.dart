import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopdesk/features/auth/application/auth_controller.dart';
import 'package:shopdesk/features/auth/presentation/forgot_password_page.dart';
import 'package:shopdesk/features/auth/presentation/new_password_page.dart';
import 'package:shopdesk/features/auth/presentation/sign_in_page.dart';
import 'package:shopdesk/features/auth/presentation/sign_up_page.dart';
import 'package:shopdesk/features/auth/presentation/verify_code_page.dart';
import 'package:shopdesk/features/dashboard/presentation/dashboard_page.dart';
import 'package:shopdesk/features/predictor/presentation/predictor_page.dart';
import 'package:shopdesk/features/products/domain/product.dart';
import 'package:shopdesk/features/products/presentation/inventory_page.dart';
import 'package:shopdesk/features/products/presentation/product_form_page.dart';
import 'package:shopdesk/features/products/presentation/stock_in_page.dart';
import 'package:shopdesk/features/sales/presentation/add_sale_page.dart';
import 'package:shopdesk/features/sales/presentation/pos_page.dart';
import 'package:shopdesk/features/sales/presentation/sales_history_page.dart';
import 'package:shopdesk/features/settings/presentation/settings_page.dart';
import 'package:shopdesk/features/shell/home_shell.dart';
import 'package:shopdesk/features/welcome/presentation/welcome_page.dart';

/// Pages anyone can open. Everything else needs a signed-in owner.
const _publicPaths = {'/', '/signin', '/signup', '/forgot', '/verify', '/reset-password'};

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run the redirect whenever the signed-in user changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  Page<void> tab(Widget page) => NoTransitionPage<void>(child: page);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      if (auth.isLoading) return null;
      final signedIn = auth.valueOrNull != null;
      final isPublic = _publicPaths.contains(state.matchedLocation);
      if (!signedIn) return isPublic ? null : '/';
      return isPublic ? '/home' : null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const WelcomePage()),
      GoRoute(path: '/signin', builder: (_, __) => const SignInPage()),
      GoRoute(path: '/signup', builder: (_, __) => const SignUpPage()),
      GoRoute(path: '/forgot', builder: (_, __) => const ForgotPasswordPage()),
      GoRoute(
        path: '/verify',
        builder: (_, state) {
          final args = state.extra;
          return args is VerifyArgs ? VerifyCodePage(args: args) : const SignInPage();
        },
      ),
      GoRoute(path: '/reset-password', builder: (_, __) => const NewPasswordPage()),
      ShellRoute(
        builder: (context, state, child) => HomeShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/home', pageBuilder: (_, __) => tab(const DashboardPage())),
          GoRoute(path: '/sell', pageBuilder: (_, __) => tab(const PosPage())),
          GoRoute(path: '/stock', pageBuilder: (_, __) => tab(const InventoryPage())),
          GoRoute(path: '/sales', pageBuilder: (_, __) => tab(const SalesHistoryPage())),
          GoRoute(path: '/predict', pageBuilder: (_, __) => tab(const PredictorPage())),
        ],
      ),
      // Full-screen pages pushed on top of the tabs.
      GoRoute(path: '/stock/new', builder: (_, state) => ProductFormPage(initialBarcode: state.extra as String?)),
      GoRoute(path: '/stock/edit', builder: (_, state) => ProductFormPage(product: state.extra as Product?)),
      GoRoute(path: '/stock/in', builder: (_, __) => const StockInPage()),
      GoRoute(path: '/sales/add', builder: (_, __) => const AddSalePage()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
    ],
  );
});
