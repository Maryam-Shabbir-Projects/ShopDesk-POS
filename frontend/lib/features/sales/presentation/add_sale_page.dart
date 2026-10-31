import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopdesk/core/utils/formatters.dart';
import 'package:shopdesk/core/widgets/app_card.dart';
import 'package:shopdesk/features/products/application/products_controller.dart';
import 'package:shopdesk/features/products/domain/product.dart';
import 'package:shopdesk/features/sales/application/sale_draft.dart';
import 'package:shopdesk/features/sales/application/sales_providers.dart';
import 'package:shopdesk/features/sales/domain/sale.dart';
import 'package:shopdesk/features/sales/presentation/widgets/draft_lines.dart';
import 'package:shopdesk/features/sales/presentation/widgets/product_picker_sheet.dart';
import 'package:shopdesk/features/sales/presentation/widgets/receipt_sheet.dart';
import 'package:shopdesk/features/sales/presentation/widgets/totals_box.dart';
import 'package:shopdesk/features/scanner/domain/scan_result.dart';
import 'package:shopdesk/features/scanner/presentation/scan_input_bar.dart';
import 'package:shopdesk/features/settings/application/settings_controller.dart';

/// Record a sale by hand (for example a missed one): scan or pick items,
/// choose tax, payment and date, then save to get the receipt.
class AddSalePage extends ConsumerStatefulWidget {
  const AddSalePage({super.key});

  @override
  ConsumerState<AddSalePage> createState() => _AddSalePageState();
}

class _AddSalePageState extends ConsumerState<AddSalePage> {
  final _customer = TextEditingController();
  final _discount = TextEditingController(text: '0');
  late final TextEditingController _tax;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tax = TextEditingController(text: Fmt.number(ref.read(settingsProvider).taxRate));
  }

  @override
  void dispose() {
    _customer.dispose();
    _discount.dispose();
    _tax.dispose();
    super.dispose();
  }

  ScanResult _onScan(String code) {
    final products = ref.read(productsProvider).valueOrNull ?? const <Product>[];
    final match = products.where((p) => p.matchesCode(code)).firstOrNull;
    if (match == null) return ScanResult.unknown(code);
    final error = ref.read(manualDraftProvider.notifier).add(match);
    return error == null ? ScanResult.added('Added: ${match.name}') : ScanResult.blocked(error);
  }

  void _offerNewProduct(String code) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Barcode not found'),
        content: Text('No product uses $code. Add it as a new product?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/stock/new', extra: code);
            },
            child: const Text('Add product'),
          ),
        ],
      ),
    );
  }

  Future<void> _addByHand() async {
    final products = ref.read(productsProvider).valueOrNull ?? const <Product>[];
    final picked = await pickProduct(context, products);
    if (picked == null || !mounted) return;
    final error = ref.read(manualDraftProvider.notifier).add(picked);
    if (error != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _pickDateTime(DateTime current) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (time == null) return;
    ref.read(manualDraftProvider.notifier).setDate(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final sale = await ref.read(checkoutServiceProvider).complete(ref.read(manualDraftProvider));
      ref.read(manualDraftProvider.notifier).clear();
      ref.read(historyFilterProvider.notifier).update((f) => f.copyWith(day: sale.createdAt));
      if (!mounted) return;
      await showReceiptSheet(context, sale);
      if (mounted) context.pop();
    } on StateError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(manualDraftProvider);
    final notifier = ref.read(manualDraftProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final products = ref.watch(productsProvider).valueOrNull ?? const <Product>[];
    final totals = draft.totals(products, settings.taxRate);
    final when = draft.date ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Add sale')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ScanInputBar(onCode: _onScan, onUnknown: _offerNewProduct),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Items', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                DraftLines(provider: manualDraftProvider, emptyMessage: 'No items yet.\nScan a barcode or pick a product.'),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: _addByHand, icon: const Icon(Icons.add), label: const Text('Add item')),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Sale details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(
                  controller: _customer,
                  decoration: const InputDecoration(labelText: 'Customer name (optional)'),
                  onChanged: notifier.setCustomer,
                ),
                const SizedBox(height: 12),
                SegmentedButton<PaymentMethod>(
                  showSelectedIcon: false,
                  segments: [for (final m in PaymentMethod.values) ButtonSegment(value: m, label: Text(m.label))],
                  selected: {draft.payment},
                  onSelectionChanged: (s) => notifier.setPayment(s.first),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _discount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Discount %'),
                        onChanged: (v) => notifier.setDiscount(double.tryParse(v) ?? 0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _tax,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Tax %'),
                        onChanged: (v) => notifier.setTax(double.tryParse(v) ?? 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _pickDateTime(when),
                  icon: const Icon(Icons.event_outlined),
                  label: Text(Fmt.dateTime.format(when)),
                ),
                const SizedBox(height: 16),
                TotalsBox(totals: totals, money: settings.money),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: draft.isEmpty || _busy ? null : _save,
                  child: const Text('Save sale and get receipt'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
