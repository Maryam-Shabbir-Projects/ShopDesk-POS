import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopdesk/core/widgets/app_card.dart';
import 'package:shopdesk/core/widgets/empty_state.dart';
import 'package:shopdesk/features/products/application/products_controller.dart';
import 'package:shopdesk/features/products/domain/product.dart';
import 'package:shopdesk/features/products/presentation/widgets/product_avatar.dart';
import 'package:shopdesk/features/sales/application/sale_draft.dart';
import 'package:shopdesk/features/sales/presentation/widgets/cart_panel.dart';
import 'package:shopdesk/features/settings/application/settings_controller.dart';

/// Sell screen: products by category. Wide screens show the sale beside the
/// catalog; phones open it as a bottom sheet.
class PosPage extends ConsumerStatefulWidget {
  const PosPage({super.key});

  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}

class _PosPageState extends ConsumerState<PosPage> {
  String _category = 'All';
  String _query = '';

  void _addToSale(Product product) {
    final error = ref.read(posDraftProvider.notifier).add(product);
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error), duration: const Duration(seconds: 2)));
    }
  }

  void _openCartSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.9,
          child: CartPanel(onDone: () => Navigator.of(ctx).pop()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final draft = ref.watch(posDraftProvider);
    final settings = ref.watch(settingsProvider);
    final products = productsAsync.valueOrNull ?? const <Product>[];
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final catalog = productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load products: $e')),
      data: (all) => _Catalog(
        products: all,
        category: _category,
        query: _query,
        onCategory: (c) => setState(() => _category = c),
        onQuery: (q) => setState(() => _query = q.trim().toLowerCase()),
        onTap: _addToSale,
        money: settings.money,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Sell')),
      body: wide
          ? Row(
              children: [
                Expanded(child: catalog),
                const VerticalDivider(width: 1),
                SizedBox(width: 380, child: CartPanel()),
              ],
            )
          : catalog,
      floatingActionButton: (!wide && !draft.isEmpty)
          ? FloatingActionButton.extended(
              onPressed: _openCartSheet,
              icon: const Icon(Icons.shopping_cart_outlined),
              label: Text(
                'View sale · ${draft.itemCount} items · ${settings.money(draft.totals(products, settings.taxRate).total)}',
              ),
            )
          : null,
    );
  }
}

class _Catalog extends StatelessWidget {
  const _Catalog({
    required this.products,
    required this.category,
    required this.query,
    required this.onCategory,
    required this.onQuery,
    required this.onTap,
    required this.money,
  });

  final List<Product> products;
  final String category;
  final String query;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onQuery;
  final ValueChanged<Product> onTap;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...{for (final p in products) p.category}];
    final visible = products
        .where((p) => (category == 'All' || p.category == category) &&
            (query.isEmpty || p.name.toLowerCase().contains(query) || p.sku.toLowerCase().contains(query)))
        .toList();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search products'),
            onChanged: onQuery,
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final c in categories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(c), selected: c == category, onSelected: (_) => onCategory(c)),
                ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const EmptyState(message: 'No products match your search.', icon: Icons.search_off)
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisExtent: 196,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final p = visible[i];
                    final out = p.stock <= 0;
                    return Opacity(
                      opacity: out ? 0.5 : 1,
                      child: AppCard(
                        padding: const EdgeInsets.all(10),
                        onTap: () => onTap(p),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(child: ProductAvatar(product: p, size: 72)),
                            const SizedBox(height: 8),
                            Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(out ? 'Out of stock' : '${p.stock} in stock',
                                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                            const Spacer(),
                            Text(money(p.price), style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
