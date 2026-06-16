import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import 'app_theme.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'sales_screen.dart';

/// Pantalla principal post-autenticación con navegación a módulos.
///
/// **Integración:** recibe los servicios inyectados desde `main.dart`.
/// Usa [onNavigate] opcional si el equipo prefiere rutas nombradas externas.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.authService,
    required this.firestoreService,
    required this.storageService,
    this.onNavigate,
  });

  final AuthService authService;
  final FirestoreService firestoreService;
  final StorageService storageService;
  final void Function(String route)? onNavigate;

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await authService.signOut();
    }
  }

  void _openModule(BuildContext context, String route, Widget screen) {
    if (onNavigate != null) {
      onNavigate!(route);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = responsiveColumns(width, mobile: 1, tablet: 2, desktop: 2);
    final userEmail = authService.currentUser?.email ?? 'Usuario';

    final modules = [
      _ModuleCardData(
        route: 'inventory',
        title: 'Inventario',
        subtitle: 'Gestiona productos y stock',
        icon: Icons.inventory_2_outlined,
        color: AppColors.linkBlue,
        screen: InventoryScreen(
          firestoreService: firestoreService,
          storageService: storageService,
        ),
      ),
      _ModuleCardData(
        route: 'sales',
        title: 'Ventas',
        subtitle: 'Registra transacciones',
        icon: Icons.point_of_sale_outlined,
        color: AppColors.successGreen,
        screen: SalesScreen(firestoreService: firestoreService),
      ),
      _ModuleCardData(
        route: 'dashboard',
        title: 'Dashboard',
        subtitle: 'Métricas y resumen',
        icon: Icons.dashboard_outlined,
        color: AppColors.meshPurple,
        screen: DashboardScreen(firestoreService: firestoreService),
      ),
    ];

    return PymeScaffold(
      appBar: PymeAppBar(
        title: 'Inicio',
        activeRoute: 'home',
        onNavigate: onNavigate,
        onLogout: () => _logout(context),
      ),
      padding: const EdgeInsets.all(24),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Administration', style: AppTextStyles.screenTitle),
                  const SizedBox(height: 8),
                  Text(
                    'Bienvenido, $userEmail',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 32),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: width >= AppBreakpoints.tablet ? 1.6 : 1.3,
                    ),
                    itemCount: modules.length,
                    itemBuilder: (context, index) {
                      final module = modules[index];
                      return GlassCard(
                        onTap: () =>
                            _openModule(context, module.route, module.screen),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: module.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(module.icon, color: module.color, size: 28),
                            ),
                            const Spacer(),
                            Text(module.title, style: AppTextStyles.sectionTitle),
                            const SizedBox(height: 4),
                            Text(
                              module.subtitle,
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.secondaryText,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  'ABRIR',
                                  style: AppTextStyles.labelUppercase.copyWith(
                                    color: AppColors.navy,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: AppColors.navy,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (width < AppBreakpoints.tablet) ...[
                    const SizedBox(height: 24),
                    _MobileNavBar(
                      onNavigate: (route) {
                        final module = modules.firstWhere((m) => m.route == route);
                        _openModule(context, route, module.screen);
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ModuleCardData {
  const _ModuleCardData({
    required this.route,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.screen,
  });

  final String route;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget screen;
}

class _MobileNavBar extends StatelessWidget {
  const _MobileNavBar({required this.onNavigate});

  final void Function(String route) onNavigate;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MobileNavItem(
            icon: Icons.inventory_2_outlined,
            label: 'Inventario',
            onTap: () => onNavigate('inventory'),
          ),
          _MobileNavItem(
            icon: Icons.point_of_sale_outlined,
            label: 'Ventas',
            onTap: () => onNavigate('sales'),
          ),
          _MobileNavItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            onTap: () => onNavigate('dashboard'),
          ),
        ],
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  const _MobileNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.navy),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
