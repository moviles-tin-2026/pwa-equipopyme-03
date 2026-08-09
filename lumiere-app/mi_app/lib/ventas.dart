import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==================== PALETA DE COLORES (COHERENTE CON INVENTARIO) ====================
class _Colors {
  static const bg = Color(0xFFFAF8F5);
  static const card = Colors.white;
  static const border = Color(0xFFECE6DF);
  static const brand = Color(0xFF8C6239);
  static const textDark = Color(0xFF2D2D2D);
  static const textGray = Color(0xFF8E8E8E);
  static const success = Color(0xFF556B2F);
  static const danger = Color(0xFFC97A7A);
}

// Convierte una fecha en una etiqueta relativa corta (Hace 10 min, Ayer, ...).
String tiempoRelativo(DateTime fecha) {
  final diferencia = DateTime.now().difference(fecha);
  if (diferencia.inMinutes < 1) return 'Justo ahora';
  if (diferencia.inMinutes < 60) return 'Hace ${diferencia.inMinutes} min';
  if (diferencia.inHours < 24) return 'Hace ${diferencia.inHours} h';
  if (diferencia.inDays == 1) return 'Ayer';
  return 'Hace ${diferencia.inDays} días';
}

class VentasPage extends StatefulWidget {
  const VentasPage({super.key});

  @override
  State<VentasPage> createState() => _VentasPageState();
}

class _VentasPageState extends State<VentasPage> {
  final _formKey = GlobalKey<FormState>();
  final _cantidadController = TextEditingController(text: '1');

  bool _showAddPanel = false;
  bool _isSaving = false;

  String? _productoSeleccionadoId;
  String _productoSeleccionadoNombre = '';
  double _productoSeleccionadoPrecio = 0;
  int _productoSeleccionadoStock = 0;

  @override
  void dispose() {
    _cantidadController.dispose();
    super.dispose();
  }

  double get _totalCalculado {
    final cantidad = int.tryParse(_cantidadController.text) ?? 0;
    return cantidad * _productoSeleccionadoPrecio;
  }

  // Registra la venta y descuenta el stock del producto en una sola
  // transacción, para que ambos cambios queden sincronizados aunque haya
  // otra persona vendiendo el mismo producto al mismo tiempo.
  Future<void> _registrarVenta() async {
    if (!_formKey.currentState!.validate()) return;
    if (_productoSeleccionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Selecciona un producto'),
          backgroundColor: _Colors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final cantidad = int.parse(_cantidadController.text.trim());
    setState(() => _isSaving = true);

    try {
      final productoRef = FirebaseFirestore.instance
          .collection('productos')
          .doc(_productoSeleccionadoId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(productoRef);
        if (!snapshot.exists) {
          throw Exception('El producto ya no existe');
        }
        final stockActual = (snapshot.data()?['stock'] ?? 0) as int;
        if (stockActual < cantidad) {
          throw Exception('Stock insuficiente (disponible: $stockActual)');
        }

        transaction.update(productoRef, {'stock': stockActual - cantidad});

        final ventaRef = FirebaseFirestore.instance.collection('ventas').doc();
        transaction.set(ventaRef, {
          'productoId': _productoSeleccionadoId,
          'productoNombre': _productoSeleccionadoNombre,
          'cantidad': cantidad,
          'precioUnitario': _productoSeleccionadoPrecio,
          'total': cantidad * _productoSeleccionadoPrecio,
          'fecha': Timestamp.now(),
          'vendedorEmail': FirebaseAuth.instance.currentUser?.email ?? '',
        });
      });

      if (!mounted) return;

      _cantidadController.text = '1';
      setState(() {
        _productoSeleccionadoId = null;
        _productoSeleccionadoNombre = '';
        _productoSeleccionadoPrecio = 0;
        _productoSeleccionadoStock = 0;
        _showAddPanel = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Venta registrada y stock actualizado'),
          backgroundColor: _Colors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: _Colors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Colors.bg,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('ventas')
              .orderBy('fecha', descending: true)
              .limit(100)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Error al cargar ventas.'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _Colors.brand),
              );
            }

            final ventas = snapshot.data?.docs ?? <QueryDocumentSnapshot>[];
            final totalIngresos = ventas.fold<double>(
              0,
              (suma, doc) =>
                  suma +
                  ((doc.data() as Map<String, dynamic>)['total'] ?? 0)
                      .toDouble(),
            );

            // El panel lateral fijo de 380px solo cabe junto a la lista en
            // pantallas anchas; por debajo del breakpoint se muestra uno u
            // otro a pantalla completa (si no, el Row desbordaba en móvil).
            return LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 700;
                if (isNarrow) {
                  return _showAddPanel
                      ? _buildFormularioVenta()
                      : _buildListaVentas(ventas, totalIngresos);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildListaVentas(ventas, totalIngresos)),
                    if (_showAddPanel)
                      const VerticalDivider(width: 1, color: _Colors.border),
                    ClipRect(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOut,
                        child: _showAddPanel
                            ? SizedBox(
                                width: 380,
                                child: _buildFormularioVenta(),
                              )
                            : const SizedBox(width: 0),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildListaVentas(
    List<QueryDocumentSnapshot> ventas,
    double totalIngresos,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: Icons.point_of_sale_rounded,
                label: 'Ventas registradas',
                value: '${ventas.length}',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _KpiCard(
                icon: Icons.payments_rounded,
                label: 'Ingresos',
                value: '\$${totalIngresos.toStringAsFixed(2)}',
                accent: _Colors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Historial de ventas',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _Colors.textDark,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => setState(() => _showAddPanel = !_showAddPanel),
              style: ElevatedButton.styleFrom(
                backgroundColor: _showAddPanel
                    ? _Colors.textDark
                    : _Colors.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                _showAddPanel
                    ? Icons.close_rounded
                    : Icons.add_shopping_cart_rounded,
                size: 18,
              ),
              label: Text(
                _showAddPanel ? 'Cerrar formulario' : 'Registrar venta',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ventas.isEmpty
              ? const Center(child: Text('Aún no hay ventas registradas.'))
              : ListView.separated(
                  itemCount: ventas.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = ventas[index].data() as Map<String, dynamic>;
                    final nombre = (data['productoNombre'] ?? 'Producto')
                        .toString();
                    final cantidad = (data['cantidad'] ?? 0) as int;
                    final total = ((data['total'] ?? 0) as num).toDouble();
                    final ts = data['fecha'];
                    final fechaTexto = ts is Timestamp
                        ? tiempoRelativo(ts.toDate())
                        : '';

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _Colors.border),
                        boxShadow: [
                          BoxShadow(
                            color: _Colors.brand.withValues(alpha: 0.06),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _Colors.success.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.trending_up_rounded,
                              color: _Colors.success,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Cantidad: $cantidad · $fechaTexto',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _Colors.textGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '\$${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _Colors.success,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFormularioVenta() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Nueva venta',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _Colors.textDark,
                      ),
                    ),
                  ),
                  // En móvil el formulario ocupa toda la pantalla (no cabe
                  // junto a la lista), así que aquí es la única forma de
                  // cerrarlo sin guardar.
                  IconButton(
                    icon: const Icon(Icons.close, color: _Colors.textGray),
                    tooltip: 'Cerrar',
                    onPressed: () => setState(() => _showAddPanel = false),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Selecciona el producto y la cantidad vendida.',
                style: TextStyle(fontSize: 12, color: _Colors.textGray),
              ),
              const SizedBox(height: 22),
              const Text(
                'Producto',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('productos')
                    .snapshots(),
                builder: (context, snapshot) {
                  final productos = snapshot.data?.docs ?? <QueryDocumentSnapshot>[];
                  return DropdownButtonFormField<String>(
                    initialValue: _productoSeleccionadoId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'Selecciona un producto',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: _Colors.bg,
                    ),
                    items: productos.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final stock = (data['stock'] ?? 0) as int;
                      return DropdownMenuItem<String>(
                        value: doc.id,
                        enabled: stock > 0,
                        child: Text(
                          '${data['nombre'] ?? 'Sin nombre'} (stock: $stock)',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: stock > 0
                                ? _Colors.textDark
                                : _Colors.textGray,
                          ),
                        ),
                      );
                    }).toList(),
                    validator: (value) =>
                        value == null ? 'Selecciona un producto' : null,
                    onChanged: (value) {
                      final doc = productos.firstWhere((d) => d.id == value);
                      final data = doc.data() as Map<String, dynamic>;
                      setState(() {
                        _productoSeleccionadoId = value;
                        _productoSeleccionadoNombre = (data['nombre'] ?? '')
                            .toString();
                        _productoSeleccionadoPrecio = (data['precio'] ?? 0)
                            .toDouble();
                        _productoSeleccionadoStock =
                            (data['stock'] ?? 0) as int;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 18),
              const Text(
                'Cantidad',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cantidadController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: _Colors.bg,
                ),
                validator: (value) {
                  final cantidad = int.tryParse(value ?? '');
                  if (cantidad == null || cantidad <= 0) {
                    return 'Cantidad inválida';
                  }
                  if (_productoSeleccionadoId != null &&
                      cantidad > _productoSeleccionadoStock) {
                    return 'Supera el stock disponible ($_productoSeleccionadoStock)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _Colors.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _Colors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '\$${_totalCalculado.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _Colors.brand,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _registrarVenta,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _Colors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    _isSaving ? 'Guardando...' : 'Registrar venta',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _Colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (accent ?? _Colors.brand).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent ?? _Colors.brand, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _Colors.textGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: accent ?? _Colors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
