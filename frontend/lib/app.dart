import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopdesk/core/constants/app_constants.dart';
import 'package:shopdesk/core/router/app_router.dart';
import 'package:shopdesk/core/theme/app_theme.dart';

class ShopDeskApp extends ConsumerWidget {
  const ShopDeskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
