// main.dart
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// También diferido: el SDK JS de Firestore (incluye el módulo de
// "pipelines", ~750KB sin comprimir y 80%+ sin usar aquí) solo hacía
// falta para la consulta de rol tras el login, no para pintar la
// pantalla. Antes se cargaba igual porque este import no era diferido,
// aunque inventario.dart sí lo fuera.
import 'package:cloud_firestore/cloud_firestore.dart' deferred as firestore;
import 'firebase_options.dart';
// Carga diferida: el catálogo (y todo lo que arrastra: usuarios, ventas,
// reportes, Firestore Storage) no se necesita para pintar el login, así que
// no debe ir en el bundle inicial. Se descarga solo tras un login exitoso.
import 'inventario.dart' deferred as inventario;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // SESSION en vez de LOCAL (el default): la sesión dura solo mientras la
  // pestaña esté abierta, a cambio de evitar el iframe de sincronización
  // entre pestañas que abre Firebase Auth para la persistencia LOCAL —ese
  // iframe es el origen de las cookies de terceros que penalizan Best
  // Practices en Lighthouse. Decisión consciente: el personal deberá
  // volver a iniciar sesión si cierra la pestaña/navegador.
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lumière & Co. - Acceso',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Montserrat',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8C6239),
          primary: const Color(0xFF8C6239),
          surface: const Color(0xFFFAF8F5),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final emailIngresado = _emailController.text.trim().toLowerCase();

      // 1. Iniciar sesión en Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailIngresado,
        password: _passwordController.text.trim(),
      );

      final uid = userCredential.user?.uid;
      if (uid == null) throw Exception('UID no válido');

      // 2. El rol vive únicamente en usuarios/{uid}.rol (o .role). Ese
      // documento lo crea la app al dar de alta un usuario (ver
      // usuarios.dart), así que es la única fuente de verdad — ya no se
      // consultan colecciones sueltas de respaldo ni se infiere nada del
      // correo.
      await firestore.loadLibrary();
      if (!mounted) return;
      // (Tipo inferido a propósito: `firestore.DocumentSnapshot` no se puede
      // escribir como anotación porque viene de una librería diferida.)
      final userDoc = await firestore.FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();

      if (!mounted) return;

      final data = userDoc.data();
      final rolEncontrado = (data?['rol'] ?? data?['role'] ?? '')
          .toString()
          .toLowerCase();

      // 3. Administrador y Supervisor tienen acceso completo; cualquier
      // otro rol (Operador, o sin rol asignado) solo ve Catálogo y Ventas.
      bool esAdmin =
          rolEncontrado.contains('admin') || rolEncontrado.contains('supervisor');

      // El spinner del botón ya cubre esta espera de red; aprovechamos para
      // descargar el chunk diferido del catálogo antes de navegar.
      await inventario.loadLibrary();
      if (!mounted) return;

      if (esAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Acceso concedido como Administrador'),
            backgroundColor: Color(0xFF556B2F),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => inventario.InventarioPage(esAdmin: true),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Acceso concedido como Operador'),
            backgroundColor: Color(0xFF556B2F),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => inventario.InventarioPage(esAdmin: false),
          ),
        );
      }

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'Error al iniciar sesión';
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        message = 'Correo o contraseña incorrectos';
      } else if (e.code == 'invalid-email') {
        message = 'El correo no es válido';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFC97A7A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: const Color(0xFFC97A7A),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Detecta si es pantalla móvil (ancho menor a 600px)
            final isMobile = constraints.maxWidth < 600;

            return SingleChildScrollView(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 1000,
                  // En escritorio mantiene la altura fija; en móvil crece según el contenido
                  maxHeight: isMobile ? double.infinity : 620,
                ),
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8C6239).withValues(alpha: 0.06),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
              ),
            );
          },
        ),
      ),
    ); 
  }

  // === ESTRUCTURA PARA ESCRITORIO ===
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Expanded(
          flex: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              bottomLeft: Radius.circular(24),
            ),
            child: VelasLogIn(),
          ),
        ),
        Expanded(
          flex: 1,
          child: _buildFormContent(
            padding: const EdgeInsets.symmetric(
              horizontal: 44.0,
              vertical: 36.0,
            ),
          ),
        ),
      ],
    );
  }

  // === ESTRUCTURA PARA MÓVILES (Imagen arriba, formulario abajo) ===
  Widget _buildMobileLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          height: 180,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            child: VelasLogIn(),
          ),
        ),
        _buildFormContent(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
        ),
      ],
    );
  }

  // === CONTENIDO REUTILIZABLE DEL FORMULARIO ===
  Widget _buildFormContent({required EdgeInsetsGeometry padding}) {
    return Padding(
      padding: padding,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2B28B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'LUMIÈRE & CO.',
                  style: TextStyle(
                    letterSpacing: 2,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8C6239),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Bienvenido de vuelta!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Panel de acceso exclusivo para el personal de Lumière & Co.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF8E8E8E),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            _buildInputLabel('Tu correo corporativo'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 13, color: Color(0xFF2D2D2D)),
              decoration: _buildInputDecoration('ejemplo@lumiere.com'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingresa tu correo';
                }
                if (!value.contains('@')) {
                  return 'Ingresa un correo válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildInputLabel('Tu contraseña'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(fontSize: 13, color: Color(0xFF2D2D2D)),
              decoration: _buildInputDecoration('••••••••••••••••').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF8C6239).withValues(alpha: 0.6),
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingresa tu contraseña';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8C6239),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Iniciar sesión',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF8C6239),
        letterSpacing: 0.3,
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: const Color(0xFF8E8E8E).withValues(alpha: 0.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      filled: true,
      fillColor: const Color(0xFFFAF8F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFFAF8F5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2B28B), width: 1.5),
      ),
    );
  }
}

class VelasLogIn extends StatelessWidget {
  const VelasLogIn({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/img/vela_login.webp'),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.4),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  // Sigma reducido de 10 a 5: mismo look "vidrio esmerilado",
                  // pero la mitad del costo de raster (BackdropFilter es una
                  // de las operaciones más caras del pipeline de pintado).
                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: Container(
                    width: double.infinity,
                    color: Colors.white.withValues(alpha: 0.12),
                    padding: const EdgeInsets.all(20.0),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lumière & Co.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Creadas con amor, encendidas con intención.',
                          style: TextStyle(
                            color: Color(0xFFF0EFEF),
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}