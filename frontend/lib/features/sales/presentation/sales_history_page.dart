import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopdesk/core/utils/formatters.dart';
import 'package:shopdesk/core/widgets/app_card.dart';
import 'package:shopdesk/core/widgets/empty_state.dart';
import 'package:shopdesk/core/widgets/stat_card.dart';
import 'package:shopdesk/features/sales/application/sale_draft.dart';
import 'package:shopdesk/features/sales/application/sales_providers.dart';
import 'package:shopdesk/features/sales/domain/sale.dart';
import 'package:shopdesk/features/sales/presentation/widgets/receipt_sheet.dart';
import 'package:shopdesk/features/settings/application/settings_controller.dart';

class SalesHistoryPage extends ConsumerWidget {
  const SalesHistoryPage({super.key});

  Future<void> _pickDay(BuildContext context, WidgetRef ref, HistoryFilter filter) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: filter.day,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      ref.read(historyFilterProvider.notifier).state = filter.copyWith(day: picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(historyFilterProvider);
    final settings = ref.watch(settingsProvider);
    final salesAsync = ref.watch(salesInRangeProvider(filter.range));

    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ref.read(manualDraftProvider.notifier).clear();
          context.push('/sales/add');
        },
        icon: const Icon(Icons.add),
        label: const Text('Add sale'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDay(context, ref, filter),
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(Fmt.date.format(filter.day)),
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 1, label: Text('Day')),
                    ButtonSegment(value: 7, label: Text('7 days')),
                    ButtonSegment(value: 30, label: Text('30 days')),
                  ],
                  selected: {filter.days},
                  onSelectionChanged: (s) =>
                      ref.read(historyFilterProvider.notifier).state = filter.copyWith(days: s.first),
                ),
              ],
            ),
          ),
          Expanded(
            child: salesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load sales: $e')),
              data: (sales) => _Body(sales: sales, money: settings.money),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.sales, required this.money});
  final List<Sale> sales;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    final total = sales.fold(0.0, (a, s) => a + s.total);
    final units = sales.fold(0, (a, s) => a + s.itemCount);

    // Items sold in this period, best sellers first.
    final byItem = <int, ({String name, String emoji, int qty, double amount})>{};
    for (final s in sales) {
      for (final i in s.items) {
        final cur = byItem[i.productId];
        byItem[i.productId] = (
          name: i.name,
          emoji: i.emoji,
          qty: (cur?.qty ?? 0) + i.qty,
          amount: (cur?.amount ?? 0) + i.lineTotal,
        );
      }
    }
    final itemRows = byItem.values.toList()..sort((a, b) => b.qty.compareTo(a.qty));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        StatGrid(
          children: [
            StatCard(label: 'Total sales', value: money(total)),
            StatCard(label: 'Orders', value: '${sales.length}'),
            StatCard(label: 'Items sold', value: '$units'),
            StatCard(label: 'Average order', value: money(sales.isEmpty ? 0 : total / sales.length)),
          ],
        ),
        const SizedBox(height: 16),
        Text('Items sold', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: itemRows.isEmpty
              ? const Padding(padding: EdgeInsets.all(12), child: EmptyState(message: 'No sales in this period.'))
              : Column(
                  children: [
                    for (final r in itemRows)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Text(r.emoji, style: const TextStyle(fontSize: 22)),
                        title: Text(r.name),
                        subtitle: Text('${r.qty} sold'),
                        trailing: Text(money(r.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        Text('Orders', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (sales.isEmpty)
          const AppCard(child: EmptyState(message: 'No orders in this period.'))
        else
          for (final s in sales)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () => showReceiptSheet(context, s),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${s.receiptNo} · ${s.customer.isEmpty ? 'Walk-in' : s.customer}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(Fmt.dateTime.format(s.createdAt),
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text(s.items.map((i) => '${i.qty} × ${i.name}').join(', '), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(money(s.total), style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(s.payment.label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
