import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import 'app_theme.dart';

/// CRUD de inventario con listado, formulario y eliminación.
///
/// **Integración con [FirestoreService]:**
/// - `watchProducts()` → `Stream<List<Product>>`
/// - `addProduct(Product)`, `updateProduct(Product)`, `deleteProduct(id)`
///
/// **Integración con [StorageService]:**
/// - `uploadProductImage(productId, bytes)` → URL de imagen
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    super.key,
    required this.firestoreService,
    required this.storageService,
  });

  final FirestoreService firestoreService;
  final StorageService storageService;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String? _statusMessage;
  bool _isSuccess = false;

  void _openCreateForm() {
    showDialog<bool>(
      context: context,
      builder: (_) => ProductFormDialog(
        firestoreService: widget.firestoreService,
        storageService: widget.storageService,
      ),
    ).then((saved) {
      if (saved == true && mounted) {
        setState(() {
          _isSuccess = true;
          _statusMessage = 'Producto guardado correctamente.';
        });
      }
    });
  }

  void _openEditForm(Product product) {
    showDialog<bool>(
      context: context,
      builder: (_) => ProductFormDialog(
        firestoreService: widget.firestoreService,
        storageService: widget.storageService,
        product: product,
      ),
    ).then((saved) {
      if (saved == true && mounted) {
        setState(() {
          _isSuccess = true;
          _statusMessage = 'Producto actualizado.';
        });
      }
    });
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.firestoreService.deleteProduct(product.id);
      if (!mounted) return;
      setState(() {
        _isSuccess = true;
        _statusMessage = 'Producto eliminado.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSuccess = false;
        _statusMessage = 'Error al eliminar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PymeScaffold(
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.35),
        title: const Text('Inventario'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateForm,
        backgroundColor: AppColors.navy,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Nuevo', style: TextStyle(color: Colors.white)),
      ),
      padding: const EdgeInsets.all(24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inventario', style: AppTextStyles.screenTitle),
          const SizedBox(height: 8),
          Text(
            'Productos y stock disponible',
            style: AppTextStyles.body.copyWith(color: AppColors.secondaryText),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            _isSuccess
                ? StatusBanner.success(message: _statusMessage!)
                : StatusBanner.error(message: _statusMessage!),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: widget.firestoreService.watchProducts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: StatusBanner.loading());
                }
                if (snapshot.hasError) {
                  return StatusBanner.error(
                    message: 'Error al cargar productos: ${snapshot.error}',
                  );
                }

                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return Center(
                    child: GlassCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: AppColors.secondaryText.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text('No hay productos registrados'),
                          const SizedBox(height: 16),
                          PymeOutlinedButton(
                            label: 'CREAR PRODUCTO',
                            expanded: false,
                            onPressed: _openCreateForm,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide =
                        constraints.maxWidth >= AppBreakpoints.tablet;
                    if (isWide) {
                      return _ProductTable(
                        products: products,
                        onEdit: _openEditForm,
                        onDelete: _deleteProduct,
                      );
                    }
                    return ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _ProductCard(
                        product: products[index],
                        onEdit: () => _openEditForm(products[index]),
                        onDelete: () => _deleteProduct(products[index]),
                      ),
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

class _ProductTable extends StatelessWidget {
  const _ProductTable({
    required this.products,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Product> products;
  final void Function(Product) onEdit;
  final void Function(Product) onDelete;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: AppTextStyles.labelUppercase,
          columns: const [
            DataColumn(label: Text('Producto')),
            DataColumn(label: Text('Precio')),
            DataColumn(label: Text('Stock')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: products.map((product) {
            return DataRow(
              cells: [
                DataCell(
                  Row(
                    children: [
                      _ProductImage(url: product.imageUrl, size: 40),
                      const SizedBox(width: 12),
                      Text(product.name),
                    ],
                  ),
                ),
                DataCell(Text('\$${product.price.toStringAsFixed(2)}')),
                DataCell(
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: product.stock > 0
                          ? AppColors.successGreen.withValues(alpha: 0.15)
                          : AppColors.errorRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${product.stock}'),
                  ),
                ),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => onEdit(product),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.errorRed),
                        onPressed: () => onDelete(product),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _ProductImage(url: product.imageUrl, size: 56),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: AppTextStyles.sectionTitle),
                Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Stock: ${product.stock}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: product.stock > 0
                        ? AppColors.successGreen
                        : AppColors.errorRed,
                  ),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: url != null && url!.isNotEmpty
          ? Image.network(
              url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(size),
            )
          : _placeholder(size),
    );
  }

  Widget _placeholder(double size) {
    return Container(
      width: size,
      height: size,
      color: AppColors.tagBackground,
      child: Icon(
        Icons.image_outlined,
        color: AppColors.secondaryText.withValues(alpha: 0.5),
      ),
    );
  }
}

/// Formulario modal para crear/editar productos.
class ProductFormDialog extends StatefulWidget {
  const ProductFormDialog({
    super.key,
    required this.firestoreService,
    required this.storageService,
    this.product,
  });

  final FirestoreService firestoreService;
  final StorageService storageService;
  final Product? product;

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _priceController =
        TextEditingController(text: p?.price.toString() ?? '');
    _stockController = TextEditingController(text: p?.stock.toString() ?? '0');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final product = Product(
        id: widget.product?.id ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text),
        stock: int.parse(_stockController.text),
        imageUrl: widget.product?.imageUrl,
      );

      if (widget.product == null) {
        await widget.firestoreService.addProduct(product);
      } else {
        await widget.firestoreService.updateProduct(product);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error al guardar: $e';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white.withValues(alpha: 0.95),
      title: Text(widget.product == null ? 'Nuevo producto' : 'Editar producto'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_errorMessage != null)
                StatusBanner.error(message: _errorMessage!),
              GlassTextField(
                controller: _nameController,
                label: 'NOMBRE',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              GlassTextField(
                controller: _descriptionController,
                label: 'DESCRIPCIÓN',
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              GlassTextField(
                controller: _priceController,
                label: 'PRECIO',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (double.tryParse(v) == null) return 'Número inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              GlassTextField(
                controller: _stockController,
                label: 'STOCK',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (int.tryParse(v) == null) return 'Entero inválido';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        PymeOutlinedButton(
          label: 'GUARDAR',
          expanded: false,
          isLoading: _isSaving,
          onPressed: _save,
        ),
      ],
    );
  }
}
