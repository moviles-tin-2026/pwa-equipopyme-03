import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/transaction.dart';
import '../services/firestore_service.dart';
import 'app_theme.dart';

String _formatDateTime(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  final h = date.hour.toString().padLeft(2, '0');
  final min = date.minute.toString().padLeft(2, '0');
  return '$d/$m/${date.year} $h:$min';
}

/// Registro de ventas e historial de transacciones.
///
/// **Integración con [FirestoreService]:**
/// - `watchProducts()` para selector de producto
/// - `watchTransactions(limit:)` para historial
/// - `createSale(productId, quantity, customer?)` para registrar venta
class SalesScreen extends StatefulWidget {
  const SalesScreen({
    super.key,
    required this.firestoreService,
  });

  final FirestoreService firestoreService;

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');
  final _customerController = TextEditingController();

  Product? _selectedProduct;
  bool _isSubmitting = false;
  String? _feedbackMessage;
  bool _isSuccess = false;

  static const _pageSize = 20;
  int _visibleCount = _pageSize;

  @override
  void dispose() {
    _quantityController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  Future<void> _submitSale() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      setState(() => _feedbackMessage = 'Selecciona un producto.');
      return;
    }

    final quantity = int.parse(_quantityController.text);
    if (quantity > _selectedProduct!.stock) {
      setState(() {
        _isSuccess = false;
        _feedbackMessage =
            'Stock insuficiente. Disponible: ${_selectedProduct!.stock} unidades.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _feedbackMessage = null;
    });

    try {
      await widget.firestoreService.createSale(
        productId: _selectedProduct!.id,
        quantity: quantity,
        customer: _customerController.text.trim().isEmpty
            ? null
            : _customerController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _isSuccess = true;
        _feedbackMessage = 'Venta registrada correctamente.';
        _quantityController.text = '1';
        _customerController.clear();
        _selectedProduct = null;
      });
      _formKey.currentState!.reset();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSuccess = false;
        _feedbackMessage = 'Error al registrar venta: $e';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= AppBreakpoints.tablet;

    return PymeScaffold(
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.35),
        title: const Text('Ventas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      padding: const EdgeInsets.all(24),
      body: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildSaleForm()),
                const SizedBox(width: 24),
                Expanded(flex: 3, child: _buildHistory()),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildSaleForm(),
                  const SizedBox(height: 24),
                  SizedBox(height: 500, child: _buildHistory()),
                ],
              ),
            ),
    );
  }

  Widget _buildSaleForm() {
    return GlassCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Registrar venta', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 4),
            Text(
              'Fecha: ${_formatDateTime(DateTime.now())}',
              style: AppTextStyles.body.copyWith(color: AppColors.secondaryText),
            ),
            if (_feedbackMessage != null) ...[
              const SizedBox(height: 16),
              _isSuccess
                  ? StatusBanner.success(message: _feedbackMessage!)
                  : StatusBanner.error(message: _feedbackMessage!),
            ],
            const SizedBox(height: 20),
            Text('PRODUCTO', style: AppTextStyles.labelUppercase),
            const SizedBox(height: 8),
            StreamBuilder<List<Product>>(
              stream: widget.firestoreService.watchProducts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const StatusBanner.loading(message: 'Cargando productos...');
                }
                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return const Text('No hay productos en inventario.');
                }

                return DropdownButtonFormField<Product>(
                  value: _selectedProduct,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  hint: const Text('Seleccionar producto'),
                  items: products
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text('${p.name} (stock: ${p.stock})'),
                        ),
                      )
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (product) => setState(() => _selectedProduct = product),
                  validator: (_) =>
                      _selectedProduct == null ? 'Selecciona un producto' : null,
                );
              },
            ),
            const SizedBox(height: 20),
            GlassTextField(
              controller: _quantityController,
              label: 'CANTIDAD',
              keyboardType: TextInputType.number,
              enabled: !_isSubmitting,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Requerido';
                final qty = int.tryParse(value);
                if (qty == null || qty <= 0) return 'Cantidad inválida';
                if (_selectedProduct != null && qty > _selectedProduct!.stock) {
                  return 'Máximo ${_selectedProduct!.stock} unidades';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            GlassTextField(
              controller: _customerController,
              label: 'CLIENTE (OPCIONAL)',
              hint: 'Nombre del cliente',
              enabled: !_isSubmitting,
            ),
            const SizedBox(height: 24),
            PymeOutlinedButton(
              label: 'REGISTRAR VENTA',
              isLoading: _isSubmitting,
              onPressed: _submitSale,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Historial', style: AppTextStyles.sectionTitle),
              Icon(Icons.history_rounded, color: AppColors.secondaryText),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Transaction>>(
              stream: widget.firestoreService.watchTransactions(
                limit: _visibleCount,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: StatusBanner.loading());
                }
                if (snapshot.hasError) {
                  return StatusBanner.error(
                    message: 'Error: ${snapshot.error}',
                  );
                }

                final transactions = snapshot.data ?? [];
                if (transactions.isEmpty) {
                  return const Center(
                    child: Text('Sin transacciones registradas.'),
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: transactions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final tx = transactions[index];
                          return _TransactionRow(
                            transaction: tx,
                          );
                        },
                      ),
                    ),
                    if (transactions.length >= _visibleCount)
                      TextButton(
                        onPressed: () =>
                            setState(() => _visibleCount += _pageSize),
                        child: Text(
                          'VER MÁS TRANSACCIONES',
                          style: AppTextStyles.labelUppercase.copyWith(
                            color: AppColors.linkBlue,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaction.productName, style: AppTextStyles.body),
                Text(
                  _formatDateTime(transaction.date),
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              'x${transaction.quantity}',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              transaction.customer ?? '—',
              style: AppTextStyles.body.copyWith(
                color: AppColors.secondaryText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '\$${transaction.total.toStringAsFixed(2)}',
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
