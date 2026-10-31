import 'package:flutter/material.dart';
import 'package:shopdesk/features/products/domain/product.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final StockStatus status;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final (label, bg, fg) = switch (status) {
      StockStatus.inStock => ('In stock', s.primaryContainer, s.onPrimaryContainer),
      StockStatus.low => ('Low stock', s.tertiaryContainer, s.onTertiaryContainer),
      StockStatus.out => ('Out of stock', s.errorContainer, s.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}
