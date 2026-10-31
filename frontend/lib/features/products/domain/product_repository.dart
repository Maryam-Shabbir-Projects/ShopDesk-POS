import 'package:shopdesk/features/products/domain/product.dart';

abstract interface class ProductRepository {
  Future<List<Product>> getAll();

  /// Inserts when [Product.id] is null, otherwise updates. Returns the id.
  Future<int> upsert(Product product);

  Future<void> delete(int id);

  /// Adds [delta] (may be negative) to stock, never going below zero.
  Future<void> adjustStock(int id, int delta);

  Future<int> count();
}
