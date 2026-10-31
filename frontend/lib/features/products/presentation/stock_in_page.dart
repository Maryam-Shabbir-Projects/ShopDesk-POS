import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopdesk/core/widgets/empty_state.dart';
import 'package:shopdesk/features/products/application/products_controller.dart';
import 'package:shopdesk/features/products/domain/product.dart';
import 'package:shopdesk/features/products/presentation/widgets/product_avatar.dart';
import 'package:shopdesk/features/scanner/domain/scan_result.dart';
import 'package:shopdesk/features/scanner/presentation/scan_input_bar.dart';

/// Scan a delivery, review the counts, then confirm once.
class StockInPage extends ConsumerStatefulWidget {
  const StockInPage({super.key});

  @override
  ConsumerState<StockInPage> createState() => _StockInPageState();
}

class _StockInPageState extends ConsumerState<StockInPage> {
  final Map<int, int> _received = {};

  ScanResult _onCode(String code) {
    final products = ref.read(productsProvider).valueOrNull ?? const <Product>[];
    final match = products.where((p) => p.matchesCode(code)).firstOrNull;
    if (match == null) return ScanResult.unknown(code);
    setState(() => _received[match.id!] = (_received[match.id!] ?? 0) + 1);
    return ScanResult.added('Stock +1: ${match.name}');
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

  Future<void> _confirm() async {
    final total = _received.values.fold(0, (a, b) => a + b);
    await ref.read(productsProvider.notifier).receiveStock(Map.of(_received));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$total units added to stock')));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider).valueOrNull ?? const <Product>[];
    final units = _received.values.fold(0, (a, b) => a + b);
    return Scaffold(
      appBar: AppBar(title: const Text('Scan stock in')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ScanInputBar(onCode: _onCode, onUnknown: _offerNewProduct),
          ),
          Expanded(
            child: _received.isEmpty
                ? const EmptyState(message: 'Scan a barcode to start. Each scan adds one unit.', icon: Icons.qr_code_scanner)
                : ListView(
                    children: [
                      for (final entry in _received.entries)
                        Builder(builder: (context) {
                          final p = products.firstWhere((x) => x.id == entry.key);
                          return ListTile(
                            leading: ProductAvatar(product: p),
                            title: Text(p.name),
                            subtitle: Text('Now ${p.stock} in stock'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Remove one',
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => setState(() {
                                    final left = entry.value - 1;
                                    left <= 0 ? _received.remove(entry.key) : _received[entry.key] = left;
                                  }),
                                ),
                                Text('+${entry.value}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                IconButton(
                                  tooltip: 'Add one',
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => setState(() => _received[entry.key] = entry.value + 1),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
          ),
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: units == 0 ? null : _confirm,
                child: Text('Add $units units to stock'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
