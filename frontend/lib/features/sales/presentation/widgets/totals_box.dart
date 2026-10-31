import 'package:flutter/material.dart';
import 'package:shopdesk/features/sales/domain/pricing_service.dart';

class TotalsBox extends StatelessWidget {
  const TotalsBox({super.key, required this.totals, required this.money});
  final SaleTotals totals;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    Widget row(String label, String value, {TextStyle? style}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(label, style: style ?? muted), Text(value, style: style ?? muted)],
          ),
        );
    return Column(
      children: [
        row('Subtotal', money(totals.subtotal)),
        if (totals.discount > 0) row('Discount', '-${money(totals.discount)}'),
        row('Tax (${totals.taxRate.toStringAsFixed(totals.taxRate % 1 == 0 ? 0 : 1)}%)', money(totals.tax)),
        const Divider(height: 16),
        row(
          'Total',
          money(totals.total),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
