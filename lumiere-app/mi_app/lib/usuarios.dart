import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mi_app/firebase_options.dart';

// ==================== PALETA DE COLORES (COHERENTE CON INVENTARIO) ====================
class _Colors {
  static const bg = Color(0xFFFAF8F5);
  static const card = Colors.white;
  static const border = Color(0xFFECE6DF);
  static const brand = Color(0xFF8C6239);
  static const brandLight = Color(0xFFE2B28B);
  static const textDark = Color(0xFF2D2D2D);
  static const textGray = Color(0xFF8E8E8E);
  static const success = Color(0xFF556B2F);
  static const danger = Color(0xFFC97A7A);
}

// Esta pantalla es alcanzable por Administrador y Supervisor: InventarioPage
// (ver esAdmin en inventario.dart/main.dart) oculta la navegación a
// "Usuarios" para cualquier otro rol. Dentro de la pantalla, `puedeEditar`
// distingue entre ambos: solo Administrador puede dar de alta o eliminar
// usuarios — Supervisor la ve, pero de solo lectura.
class UsuariosPage extends StatefulWidget {
  final bool puedeEditar;

  const UsuariosPage({super.key, this.puedeEditar = true});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _searchQuery = '';
  bool _showAddPanel = false;
  bool _isSaving = false;
  bool _activo = true;
  String _rolSeleccionado = 'Administrador';

  final List<String> _roles = ['Administrador', 'Supervisor', 'Operador'];

  @override
  void dispose() {
    _searchController.dispose();
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> _filtrarUsuarios(
    List<QueryDocumentSnapshot> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final nombre = (data['nombre'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      final rol = (data['rol'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return query.isEmpty ||
          nombre.contains(query) ||
          email.contains(query) ||
          rol.contains(query);
    }).toList();
  }

  Future<void> _agregarUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Se crea la cuenta en una instancia SECUNDARIA de Firebase App.
      // createUserWithEmailAndPassword inicia sesión automáticamente con la
      // cuenta recién creada en la instancia donde se ejecuta; al correrlo en
      // una app secundaria evitamos cerrar la sesión del administrador que
      // está creando el usuario.
      FirebaseApp appSecundaria;
      try {
        appSecundaria = Firebase.app('UsuarioSecundario');
      } catch (_) {
        appSecundaria = await Firebase.initializeApp(
          name: 'UsuarioSecundario',
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      final authSecundaria = FirebaseAuth.instanceFor(app: appSecundaria);

      final credencial = await authSecundaria.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final uid = credencial.user!.uid;
      await authSecundaria.signOut();

      // El ID del documento coincide con el UID de Auth para poder validar
      // permisos por rol directamente en las reglas de Firestore.
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'nombre': _nombreController.text.trim(),
        'email': _emailController.text.trim(),
        'rol': _rolSeleccionado,
        'activo': _activo,
        'creadoEn': Timestamp.now(),
      });

      if (!mounted) return;

      _nombreController.clear();
      _emailController.clear();
      _passwordController.clear();
      setState(() {
        _rolSeleccionado = 'Administrador';
        _activo = true;
        _showAddPanel = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Usuario y acceso creados correctamente'),
          backgroundColor: _Colors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String mensaje = 'No se pudo crear el acceso del usuario';
      if (e.code == 'email-already-in-use') {
        mensaje = 'Ese correo ya tiene una cuenta registrada';
      } else if (e.code == 'weak-password') {
        mensaje = 'La contraseña debe tener al menos 6 caracteres';
      } else if (e.code == 'invalid-email') {
        mensaje = 'El correo no es válido';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: _Colors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudo guardar el usuario'),
          backgroundColor: _Colors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // Elimina el registro del usuario en Firestore (revoca su acceso dentro de
  // la app). Borrar también la cuenta de Firebase Auth requeriría el Admin
  // SDK desde un backend (p. ej. Cloud Functions), fuera del alcance actual
  // de una app 100% cliente.
  Future<void> _eliminarUsuario(String id) async {
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Usuario eliminado'),
          backgroundColor: _Colors.brand,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudo eliminar el usuario'),
          backgroundColor: _Colors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _confirmarEliminacion(String id, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Confirmar eliminación'),
          content: Text('¿Estás seguro que quieres eliminar este usuario? ($nombre)'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No', style: TextStyle(color: _Colors.textGray)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _Colors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sí'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      _eliminarUsuario(id);
    }
  }

  Widget _buildListaUsuarios(
    List<QueryDocumentSnapshot> docs,
    List<QueryDocumentSnapshot> filtrados,
  ) {
    final totalActivos = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['activo'] ?? false) == true;
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: Icons.people_alt_rounded,
                label: 'Usuarios',
                value: '${docs.length}',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _KpiCard(
                icon: Icons.check_circle_rounded,
                label: 'Activos',
                value: '$totalActivos',
                accent: _Colors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _Colors.border),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Buscar usuarios por nombre, email o rol',
                    hintStyle: TextStyle(
                      color: _Colors.textGray.withValues(alpha: 0.8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: _Colors.textGray,
                    ),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            if (widget.puedeEditar) ...[
              const SizedBox(width: 12),
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
                      : Icons.person_add_alt_rounded,
                  size: 18,
                ),
                label: Text(
                  _showAddPanel ? 'Cerrar formulario' : 'Agregar Usuario',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: docs.isEmpty
              ? const Center(child: Text('Aún no hay usuarios registrados.'))
              : filtrados.isEmpty
              ? const Center(
                  child: Text('No hay usuarios que coincidan con la búsqueda.'),
                )
              : ListView.separated(
                  itemCount: filtrados.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = filtrados[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final nombre = (data['nombre'] ?? 'Sin nombre').toString();
                    final email = (data['email'] ?? 'Sin email').toString();
                    final rol = (data['rol'] ?? 'Sin rol').toString();
                    final activo = (data['activo'] ?? false) == true;

                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
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
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: _Colors.brandLight,
                            child: Text(
                              nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                color: _Colors.textDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: const TextStyle(
                                    color: _Colors.textGray,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Rol: $rol',
                                  style: const TextStyle(
                                    color: _Colors.brand,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: activo
                                  ? _Colors.success.withValues(alpha: 0.12)
                                  : _Colors.danger.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              activo ? 'Activo' : 'Inactivo',
                              style: TextStyle(
                                color: activo
                                    ? _Colors.success
                                    : _Colors.danger,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (widget.puedeEditar) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: _Colors.danger,
                              ),
                              tooltip: 'Eliminar usuario',
                              onPressed: () => _confirmarEliminacion(doc.id, nombre),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAddUserForm() {
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
                      'Nuevo Usuario',
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
                'Completa los datos para registrar un nuevo acceso.',
                style: TextStyle(fontSize: 12, color: _Colors.textGray),
              ),
              const SizedBox(height: 22),
              const Text(
                'Nombre completo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nombreController,
                decoration: InputDecoration(
                  hintText: 'Ej. Sofia López',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: _Colors.bg,
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Ingresa un nombre válido'
                    : null,
              ),
              const SizedBox(height: 18),
              const Text(
                'Correo electrónico',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'usuario@lumiere.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: _Colors.bg,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un correo';
                  }
                  final emailRegex = RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  );
                  return emailRegex.hasMatch(value.trim())
                      ? null
                      : 'Correo inválido';
                },
              ),
              const SizedBox(height: 18),
              const Text(
                'Contraseña de acceso',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Mínimo 6 caracteres',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: _Colors.bg,
                ),
                validator: (value) => (value == null || value.length < 6)
                    ? 'Debe tener al menos 6 caracteres'
                    : null,
              ),
              const SizedBox(height: 6),
              const Text(
                'El usuario podrá iniciar sesión de inmediato con este correo y contraseña.',
                style: TextStyle(fontSize: 11, color: _Colors.textGray),
              ),
              const SizedBox(height: 18),
              const Text(
                'Rol',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _rolSeleccionado,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: _Colors.bg,
                ),
                items: _roles.map((rol) {
                  return DropdownMenuItem<String>(value: rol, child: Text(rol));
                }).toList(),
                onChanged: (value) {
                  setState(() => _rolSeleccionado = value ?? 'Administrador');
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
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estado del usuario',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _activo ? 'Activo y con acceso' : 'Inactivo',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _Colors.textGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _activo,
                      onChanged: (value) => setState(() => _activo = value),
                      activeThumbColor: _Colors.brand,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _agregarUsuario,
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
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(
                    _isSaving ? 'Guardando...' : 'Guardar usuario',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Colors.bg,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Error al cargar usuarios.'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _Colors.brand),
              );
            }

            final docs = snapshot.data?.docs ?? <QueryDocumentSnapshot>[];
            final filtrados = _filtrarUsuarios(docs);

            // El panel lateral fijo de 380px solo cabe junto a la lista en
            // pantallas anchas; por debajo del breakpoint se muestra uno u
            // otro a pantalla completa (si no, el Row desbordaba en móvil).
            return LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 700;
                if (isNarrow) {
                  return _showAddPanel
                      ? _buildAddUserForm()
                      : _buildListaUsuarios(docs, filtrados);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildListaUsuarios(docs, filtrados)),
                    if (_showAddPanel)
                      const VerticalDivider(width: 1, color: _Colors.border),
                    ClipRect(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOut,
                        child: _showAddPanel
                            ? SizedBox(width: 380, child: _buildAddUserForm())
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
}
// ==================== WIDGETS DE SOPORTE COMPARTIDOS ====================

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
