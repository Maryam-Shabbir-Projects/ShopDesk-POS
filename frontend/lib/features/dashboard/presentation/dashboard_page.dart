import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shopdesk/core/constants/app_constants.dart';
import 'package:shopdesk/core/utils/formatters.dart';
import 'package:shopdesk/core/widgets/app_card.dart';
import 'package:shopdesk/core/widgets/empty_state.dart';
import 'package:shopdesk/core/widgets/stat_card.dart';
import 'package:shopdesk/features/auth/application/auth_controller.dart';
import 'package:shopdesk/features/dashboard/application/dashboard_providers.dart';
import 'package:shopdesk/features/products/application/products_controller.dart';
import 'package:shopdesk/features/products/domain/product.dart';
import 'package:shopdesk/features/products/presentation/widgets/product_avatar.dart';
import 'package:shopdesk/features/products/presentation/widgets/status_chip.dart';
import 'package:shopdesk/features/settings/application/settings_controller.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final weekly = ref.watch(weeklySalesProvider);
    final products = ref.watch(productsProvider).valueOrNull ?? const <Product>[];

    final stockValue = products.fold(0.0, (a, p) => a + p.price * p.stock);
    final low = products.where((p) => p.stock <= AppConstants.lowStockThreshold).toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.shopName),
        actions: [
          IconButton(tooltip: 'Settings', icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings')),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          weekly.when(
            loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Could not load sales: $e'),
            data: (days) {
              final today = days.last;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatGrid(
                    children: [
                      StatCard(label: 'Sales today', value: settings.money(today.total)),
                      StatCard(
                        label: 'Orders today',
                        value: '${today.orders}',
                        caption: '${today.items} items · avg ${settings.money(today.orders == 0 ? 0 : today.total / today.orders)}',
                      ),
                      StatCard(label: 'Stock value', value: settings.money(stockValue), caption: '${products.length} products'),
                      StatCard(label: 'Needs restock', value: '${low.length}', caption: 'low or out of stock'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Sales this week', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  AppCard(child: _WeeklyBars(days: days, money: settings.money)),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text('Running low', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: low.isEmpty
                ? const Padding(padding: EdgeInsets.all(12), child: EmptyState(message: 'Everything is well stocked.', icon: Icons.check_circle_outline))
                : Column(
                    children: [
                      for (final p in low)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ProductAvatar(product: p, size: 40),
                          title: Text(p.name),
                          subtitle: Text('${p.stock} left'),
                          trailing: StatusChip(p.status),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars({required this.days, required this.money});
  final List<DayTotal> days;
  final String Function(double) money;

  static final DateFormat _fullDay = DateFormat.EEEE();
  static String _items(int n) => n == 1 ? '1 item' : '$n items';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 11, color: scheme.onSurfaceVariant);
    final maxTotal = days.fold(1.0, (m, d) => d.total > m ? d.total : m);
    final lastIndex = days.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 170,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${days[i].items}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.onSurface),
                      ),
                      const SizedBox(height: 3),
                      Tooltip(
                        message: '${_fullDay.format(days[i].date)}: ${_items(days[i].items)} · ${money(days[i].total)}',
                        child: Container(
                          height: (100 * days[i].total / maxTotal).clamp(4, 100).toDouble(),
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: i == lastIndex ? scheme.primary : scheme.primaryContainer,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(i == lastIndex ? 'Today' : Fmt.weekday.format(days[i].date), style: muted),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text('Number above each bar = items sold. Bar height = sales.', style: muted),
        const Divider(height: 20),
        for (var i = lastIndex; i >= 0; i--)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(i == lastIndex ? 'Today' : _fullDay.format(days[i].date)),
                ),
                Text(_items(days[i].items), style: const TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(
                  width: 96,
                  child: Text(money(days[i].total), textAlign: TextAlign.right, style: muted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
