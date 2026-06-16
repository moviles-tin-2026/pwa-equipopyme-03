import 'dart:ui';

import 'package:flutter/material.dart';

/// Identidad visual compartida para todos los screens de PYME.
/// Paleta glassmorphism alineada con los mockups de referencia.
class AppColors {
  AppColors._();

  static const Color navy = Color(0xFF1A2B48);
  static const Color primaryText = Color(0xFF000000);
  static const Color secondaryText = Color(0xFF666666);
  static const Color linkBlue = Color(0xFF4A90E2);
  static const Color successGreen = Color(0xFF2ECC71);
  static const Color errorRed = Color(0xFFE74C3C);
  static const Color glassFill = Color(0x99FFFFFF);
  static const Color glassBorder = Color(0xCCFFFFFF);
  static const Color inputFill = Color(0x33FFFFFF);
  static const Color tagBackground = Color(0xFFE8E8E8);

  static const Color meshBlue = Color(0xFFA0C4FF);
  static const Color meshPurple = Color(0xFFBDB2FF);
  static const Color meshPink = Color(0xFFFFC6FF);
  static const Color meshPeach = Color(0xFFFFE5B4);
}

/// Ruta del fondo mesh. El equipo debe registrar el asset en pubspec.yaml:
/// ```yaml
/// flutter:
///   assets:
///     - assets/images/mesh_background.png
/// ```
const String kMeshBackgroundAsset = 'assets/images/mesh_background.png';

class AppBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

class AppTextStyles {
  static const TextStyle brandTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.navy,
    letterSpacing: 2,
  );

  static const TextStyle brandSubtitle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.secondaryText,
    letterSpacing: 4,
  );

  static const TextStyle screenTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryText,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
  );

  static const TextStyle labelUppercase = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.secondaryText,
    letterSpacing: 1.2,
  );

  static const TextStyle metricValue = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryText,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.primaryText,
  );
}

/// Fondo mesh con imagen de asset y fallback a gradiente pintado.
class MeshBackground extends StatelessWidget {
  const MeshBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          kMeshBackgroundAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _MeshGradientFallback(),
        ),
        child,
      ],
    );
  }
}

class _MeshGradientFallback extends StatelessWidget {
  const _MeshGradientFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.meshBlue,
            AppColors.meshPurple,
            AppColors.meshPink,
            AppColors.meshPeach,
          ],
        ),
      ),
      child: CustomPaint(
        painter: _MeshOverlayPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _MeshOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = AppColors.meshPeach.withValues(alpha: 0.45);
    canvas.drawCircle(
      Offset(size.width * 0.42, size.height * 0.38),
      size.shortestSide * 0.35,
      paint,
    );

    paint.color = AppColors.meshPink.withValues(alpha: 0.35);
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.22),
      size.shortestSide * 0.28,
      paint,
    );

    paint.color = AppColors.meshBlue.withValues(alpha: 0.4);
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.75),
      size.shortestSide * 0.32,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Scaffold base con fondo mesh y barra superior opcional.
class PymeScaffold extends StatelessWidget {
  const PymeScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.padding,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: appBar != null,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      backgroundColor: Colors.transparent,
      body: MeshBackground(
        child: SafeArea(
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: body,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta con efecto glassmorphism.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.margin,
    this.width,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: width,
          margin: margin,
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: card,
    );
  }
}

/// Campo de texto estilizado para formularios glass.
class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.suffix,
    this.maxLines = 1,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final int maxLines;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: AppTextStyles.labelUppercase),
            ),
            if (suffix != null) suffix!,
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          enabled: enabled,
          style: AppTextStyles.body.copyWith(color: AppColors.navy),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.inputFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.errorRed),
            ),
          ),
        ),
      ],
    );
  }
}

/// Botón outlined al estilo PYME.
class PymeOutlinedButton extends StatelessWidget {
  const PymeOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.expanded = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool expanded;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        side: const BorderSide(color: AppColors.navy, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, size: 18),
                ],
              ],
            ),
    );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Barra de navegación superior reutilizable.
class PymeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PymeAppBar({
    super.key,
    required this.title,
    this.activeRoute,
    this.onNavigate,
    this.onLogout,
    this.showNavLinks = true,
    this.leading,
  });

  final String title;
  final String? activeRoute;
  final void Function(String route)? onNavigate;
  final VoidCallback? onLogout;
  final bool showNavLinks;
  final Widget? leading;

  static const routes = <String, String>{
    'home': 'INICIO',
    'inventory': 'INVENTARIO',
    'sales': 'VENTAS',
    'dashboard': 'DASHBOARD',
  };

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;

    return AppBar(
      backgroundColor: Colors.white.withValues(alpha: 0.35),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: leading,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading == null) ...[
            Icon(Icons.menu_rounded, color: AppColors.navy.withValues(alpha: 0.8)),
            const SizedBox(width: 8),
          ],
          Text(
            'PYME',
            style: AppTextStyles.brandTitle.copyWith(fontSize: 20),
          ),
          if (title.isNotEmpty && title != 'PYME') ...[
            const SizedBox(width: 12),
            Text(
              title,
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
            ),
          ],
        ],
      ),
      actions: [
        if (showNavLinks && isWide && onNavigate != null)
          ...routes.entries.map(
            (entry) => _NavLink(
              label: entry.value,
              isActive: activeRoute == entry.key,
              onTap: () => onNavigate!(entry.key),
            ),
          ),
        if (onLogout != null)
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, color: AppColors.navy),
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: isActive ? AppColors.primaryText : AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 48,
            color: isActive ? AppColors.primaryText : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

/// Indicador de estado reutilizable (loading, error, vacío).
class StatusBanner extends StatelessWidget {
  const StatusBanner.loading({super.key, this.message = 'Cargando...'})
      : type = _StatusType.loading;

  const StatusBanner.error({super.key, required this.message})
      : type = _StatusType.error;

  const StatusBanner.success({super.key, required this.message})
      : type = _StatusType.success;

  final _StatusType type;
  final String message;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;

    switch (type) {
      case _StatusType.loading:
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(message, style: AppTextStyles.body),
            ],
          ),
        );
      case _StatusType.error:
        color = AppColors.errorRed;
        icon = Icons.error_outline_rounded;
      case _StatusType.success:
        color = AppColors.successGreen;
        icon = Icons.check_circle_outline_rounded;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}

enum _StatusType { loading, error, success }

/// Utilidad responsive: columnas según ancho disponible.
int responsiveColumns(double width, {int mobile = 1, int tablet = 2, int desktop = 3}) {
  if (width >= AppBreakpoints.desktop) return desktop;
  if (width >= AppBreakpoints.tablet) return tablet;
  return mobile;
}
