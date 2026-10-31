import 'package:flutter/material.dart';
import 'package:shopdesk/features/products/domain/product.dart';
import 'package:shopdesk/features/products/presentation/widgets/product_avatar.dart';

/// Search-and-tap list used to add an item to a sale by hand.
Future<Product?> pickProduct(BuildContext context, List<Product> products) {
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _PickerBody(products: products),
  );
}

class _PickerBody extends StatefulWidget {
  const _PickerBody({required this.products});
  final List<Product> products;

  @override
  State<_PickerBody> createState() => _PickerBodyState();
}

class _PickerBodyState extends State<_PickerBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.products
        .where((p) => p.name.toLowerCase().contains(_query) || p.sku.toLowerCase().contains(_query))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search products'),
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final p = list[i];
                  return ListTile(
                    enabled: p.stock > 0,
                    leading: ProductAvatar(product: p, size: 40),
                    title: Text(p.name),
                    subtitle: Text(p.stock > 0 ? '${p.stock} in stock' : 'Out of stock'),
                    onTap: () => Navigator.pop(context, p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
