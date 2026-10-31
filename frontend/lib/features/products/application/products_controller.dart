import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopdesk/core/providers.dart';
import 'package:shopdesk/features/products/data/product_image_service.dart';
import 'package:shopdesk/features/products/data/sqlite_product_repository.dart';
import 'package:shopdesk/features/products/domain/product.dart';
import 'package:shopdesk/features/products/domain/product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => SqliteProductRepository(ref.watch(databaseProvider)),
);

final productImageServiceProvider = Provider<ProductImageService>((ref) => ProductImageService());

class ProductsController extends AsyncNotifier<List<Product>> {
  ProductRepository get _repo => ref.read(productRepositoryProvider);

  @override
  Future<List<Product>> build() => _repo.getAll();

  Future<void> save(Product product) async {
    await _repo.upsert(product);
    await _reload();
  }

  Future<void> delete(int id) async {
    await _repo.delete(id);
    await _reload();
  }

  /// [quantities] maps product id to units received.
  Future<void> receiveStock(Map<int, int> quantities) async {
    for (final entry in quantities.entries) {
      await _repo.adjustStock(entry.key, entry.value);
    }
    await _reload();
  }

  Future<void> _reload() async {
    ref.invalidateSelf();
    await future;
  }
}

final productsProvider = AsyncNotifierProvider<ProductsController, List<Product>>(ProductsController.new);
