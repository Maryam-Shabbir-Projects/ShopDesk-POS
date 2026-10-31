import 'package:flutter/material.dart';
import 'package:shopdesk/core/widgets/app_card.dart';

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, this.caption});
  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          ),
          if (caption != null)
            Text(caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: t.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Grid of [StatCard]s with a fixed row height (grows with the text size
/// setting), so the boxes never overflow on small phones.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final columns = MediaQuery.sizeOf(context).width >= 700 ? 4 : 2;
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6).toDouble();
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: 104 * scale,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      children: children,
    );
  }
}
