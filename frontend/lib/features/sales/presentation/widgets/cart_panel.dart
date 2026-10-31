import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopdesk/features/products/application/products_controller.dart';
import 'package:shopdesk/features/products/domain/product.dart';
import 'package:shopdesk/features/sales/application/sale_draft.dart';
import 'package:shopdesk/features/sales/application/sales_providers.dart';
import 'package:shopdesk/features/sales/domain/sale.dart';
import 'package:shopdesk/features/sales/presentation/widgets/draft_lines.dart';
import 'package:shopdesk/features/sales/presentation/widgets/receipt_sheet.dart';
import 'package:shopdesk/features/sales/presentation/widgets/totals_box.dart';
import 'package:shopdesk/features/settings/application/settings_controller.dart';

/// The "current sale" panel on the Sell screen: lines, customer, discount,
/// payment type, totals and the Charge button.
class CartPanel extends ConsumerStatefulWidget {
  const CartPanel({super.key, this.onDone});
  final VoidCallback? onDone;

  @override
  ConsumerState<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<CartPanel> {
  final _customer = TextEditingController();
  final _discount = TextEditingController(text: '0');
  bool _busy = false;

  @override
  void dispose() {
    _customer.dispose();
    _discount.dispose();
    super.dispose();
  }

  Future<void> _charge() async {
    setState(() => _busy = true);
    try {
      final sale = await ref.read(checkoutServiceProvider).complete(ref.read(posDraftProvider));
      ref.read(posDraftProvider.notifier).clear();
      _customer.clear();
      _discount.text = '0';
      if (!mounted) return;
      await showReceiptSheet(context, sale);
      if (mounted) widget.onDone?.call();
    } on StateError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(posDraftProvider);
    final notifier = ref.read(posDraftProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final products = ref.watch(productsProvider).valueOrNull ?? const <Product>[];
    final totals = draft.totals(products, settings.taxRate);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Current sale', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              if (widget.onDone != null) TextButton(onPressed: widget.onDone, child: const Text('Close')),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              child: DraftLines(provider: posDraftProvider, emptyMessage: 'No items yet.\nTap a product to start a sale.'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customer,
                  decoration: const InputDecoration(labelText: 'Customer (optional)'),
                  onChanged: notifier.setCustomer,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 96,
                child: TextField(
                  controller: _discount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Discount %'),
                  onChanged: (v) => notifier.setDiscount(double.tryParse(v) ?? 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<PaymentMethod>(
            showSelectedIcon: false,
            segments: [for (final m in PaymentMethod.values) ButtonSegment(value: m, label: Text(m.label))],
            selected: {draft.payment},
            onSelectionChanged: (s) => notifier.setPayment(s.first),
          ),
          const SizedBox(height: 12),
          TotalsBox(totals: totals, money: settings.money),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: draft.isEmpty || _busy ? null : _charge,
            child: Text('Charge ${settings.money(totals.total)} and get receipt'),
          ),
          TextButton(
            onPressed: draft.isEmpty
                ? null
                : () {
                    notifier.clear();
                    _customer.clear();
                    _discount.text = '0';
                  },
            child: const Text('Clear sale'),
          ),
        ],
      ),
    );
  }
}
