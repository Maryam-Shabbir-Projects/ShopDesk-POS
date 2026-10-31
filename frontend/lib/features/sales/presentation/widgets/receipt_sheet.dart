import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:shopdesk/core/utils/formatters.dart';
import 'package:shopdesk/features/sales/domain/sale.dart';
import 'package:shopdesk/features/sales/presentation/widgets/receipt_pdf.dart';
import 'package:shopdesk/features/settings/application/settings_controller.dart';

Future<void> showReceiptSheet(BuildContext context, Sale sale) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ReceiptSheet(sale: sale),
  );
}

class ReceiptSheet extends ConsumerWidget {
  const ReceiptSheet({super.key, required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final scheme = Theme.of(context).colorScheme;
    final mono = TextStyle(fontFamily: 'monospace', fontSize: 13, color: scheme.onSurface);

    Widget row(String l, String r, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(l, style: mono.copyWith(fontWeight: bold ? FontWeight.w800 : null))),
              Text(r, style: mono.copyWith(fontWeight: bold ? FontWeight.w800 : null)),
            ],
          ),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.check_circle, size: 44, color: scheme.primary),
            const SizedBox(height: 8),
            Text(settings.shopName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text(
              'Receipt ${sale.receiptNo} · ${Fmt.dateTime.format(sale.createdAt)}'
              '${sale.customer.isEmpty ? '' : '\nCustomer: ${sale.customer}'}',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            for (final i in sale.items) row('${i.qty} × ${i.name}', settings.money(i.lineTotal)),
            const Divider(height: 20),
            row('Subtotal', settings.money(sale.subtotal)),
            if (sale.discount > 0) row('Discount', '-${settings.money(sale.discount)}'),
            row('Tax (${Fmt.number(sale.taxRate)}%)', settings.money(sale.tax)),
            row('Total (${sale.payment.label})', settings.money(sale.total), bold: true),
            if (settings.receiptFooter.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(settings.receiptFooter, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Print or share'),
                    onPressed: () => Printing.layoutPdf(
                      name: sale.receiptNo,
                      onLayout: (_) => ReceiptPdf.build(sale, settings),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
