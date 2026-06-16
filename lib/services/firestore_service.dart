/// Contrato de API esperado por los screens — implementar en el equipo backend.
library;

import '../models/product.dart';
import '../models/transaction.dart';

/// Métricas agregadas para [DashboardScreen].
class DashboardMetrics {
  const DashboardMetrics({
    required this.totalProducts,
    required this.totalStock,
    required this.salesToday,
    required this.salesMonth,
  });

  final int totalProducts;
  final int totalStock;
  final double salesToday;
  final double salesMonth;
}

abstract class FirestoreService {
  Stream<List<Product>> watchProducts();
  Future<void> addProduct(Product product);
  Future<void> updateProduct(Product product);
  Future<void> deleteProduct(String productId);

  Stream<List<Transaction>> watchTransactions({int limit = 50});
  Future<void> createSale({
    required String productId,
    required int quantity,
    String? customer,
  });

  Stream<DashboardMetrics> watchDashboardMetrics();
}
