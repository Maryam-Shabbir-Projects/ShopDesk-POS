import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopdesk/core/constants/app_constants.dart';
import 'package:shopdesk/core/widgets/empty_state.dart';
import 'package:shopdesk/features/products/application/products_controller.dart';
import 'package:shopdesk/features/products/domain/product.dart';
import 'package:shopdesk/features/products/presentation/widgets/product_avatar.dart';
import 'package:shopdesk/features/products/presentation/widgets/status_chip.dart';
import 'package:shopdesk/features/settings/application/settings_controller.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  String _query = '';
  StockStatus? _filter;

  Future<void> _restock(Product p) async {
    final controller = TextEditingController(text: '10');
    final qty = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restock ${p.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Quantity received', helperText: 'Currently ${p.stock} in stock'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)), child: const Text('Add stock')),
        ],
      ),
    );
    controller.dispose();
    if (qty != null && qty > 0) {
      await ref.read(productsProvider.notifier).receiveStock({p.id!: qty});
    }
  }

  Future<void> _delete(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('${p.name} will be removed from your stock list. Past sales keep their records.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await ref.read(productsProvider.notifier).delete(p.id!);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final products = ref.watch(productsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          IconButton(
            tooltip: 'Scan stock in',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => context.push('/stock/in'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/stock/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by name, SKU or barcode'),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final (label, value) in <(String, StockStatus?)>[
                  ('All', null),
                  ('Low stock', StockStatus.low),
                  ('Out of stock', StockStatus.out),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _filter == value,
                      onSelected: (_) => setState(() => _filter = value),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: products.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load stock: $e')),
              data: (all) {
                final list = all.where((p) {
                  final matchesText = _query.isEmpty ||
                      p.name.toLowerCase().contains(_query) ||
                      p.sku.toLowerCase().contains(_query) ||
                      p.barcode.toLowerCase().contains(_query);
                  final matchesStatus = _filter == null ||
                      (_filter == StockStatus.low ? p.stock <= AppConstants.lowStockThreshold : p.status == _filter);
                  return matchesText && matchesStatus;
                }).toList();
                if (list.isEmpty) {
                  return const EmptyState(message: 'No products found. Add your first product to begin.', icon: Icons.inventory_2_outlined);
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = list[i];
                    return ListTile(
                      leading: ProductAvatar(product: p),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${p.stock} in stock · ${p.sku.isEmpty ? 'No SKU' : p.sku}${p.barcode.isEmpty ? '' : ' · ${p.barcode}'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(settings.money(p.price), style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              StatusChip(p.status),
                            ],
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              switch (v) {
                                case 'restock':
                                  _restock(p);
                                case 'edit':
                                  context.push('/stock/edit', extra: p);
                                case 'delete':
                                  _delete(p);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'restock', child: Text('Restock')),
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => context.push('/stock/edit', extra: p),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
