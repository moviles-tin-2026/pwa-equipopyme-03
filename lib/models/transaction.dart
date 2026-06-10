/// Modelo de transacción de venta — implementar serialización Firestore en el equipo backend.
class Transaction {
  const Transaction({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.date,
    this.customer,
  });

  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double total;
  final String? customer;
  final DateTime date;
}
