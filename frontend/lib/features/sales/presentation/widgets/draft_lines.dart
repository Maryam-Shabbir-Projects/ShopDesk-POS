import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopdesk/core/widgets/empty_state.dart';
import 'package:shopdesk/features/products/application/products_controller.dart';
import 'package:shopdesk/features/products/domain/product.dart';
import 'package:shopdesk/features/products/presentation/widgets/product_avatar.dart';
import 'package:shopdesk/features/sales/application/sale_draft.dart';
import 'package:shopdesk/features/settings/application/settings_controller.dart';

/// The list of items in a draft sale with quantity controls. Works for any
/// draft provider, so Sell and Add sale share it.
class DraftLines extends ConsumerWidget {
  const DraftLines({super.key, required this.provider, this.emptyMessage = 'No items yet.'});
  final SaleDraftProvider provider;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(provider);
    final products = ref.watch(productsProvider).valueOrNull ?? const <Product>[];
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(provider.notifier);

    if (draft.isEmpty) return Padding(padding: const EdgeInsets.all(16), child: EmptyState(message: emptyMessage));

    return Column(
      children: [
        for (final entry in draft.lines.entries)
          Builder(builder: (context) {
            final product = products.where((p) => p.id == entry.key).firstOrNull;
            if (product == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  ProductAvatar(product: product, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(settings.money(product.price * entry.value),
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove one',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => notifier.decrement(entry.key),
                  ),
                  Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  IconButton(
                    tooltip: 'Add one',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      final error = notifier.add(product);
                      if (error != null) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(content: Text(error)));
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Remove item',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => notifier.remove(entry.key),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
