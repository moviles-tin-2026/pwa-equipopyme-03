import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'app_theme.dart';

/// Pantalla de autenticación (login y registro).
///
/// **Integración con [AuthService]:**
/// - `signInWithEmailAndPassword(email, password)`
/// - `registerWithEmailAndPassword(email, password)`
/// - `sendPasswordResetEmail(email)`
///
/// La navegación post-login la gestiona `main.dart` vía [onAuthSuccess]
/// o escuchando `authService.authStateChanges`.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authService,
    this.onAuthSuccess,
  });

  final AuthService authService;
  final VoidCallback? onAuthSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoginMode = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _feedbackMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
      _isSuccess = false;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isLoginMode) {
        await widget.authService.signInWithEmailAndPassword(email, password);
      } else {
        await widget.authService.registerWithEmailAndPassword(email, password);
      }

      if (!mounted) return;
      setState(() {
        _isSuccess = true;
        _feedbackMessage = _isLoginMode
            ? 'Sesión iniciada correctamente.'
            : 'Cuenta creada. Redirigiendo...';
      });
      widget.onAuthSuccess?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedbackMessage = _parseAuthError(e);
        _isSuccess = false;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _feedbackMessage = 'Ingresa un email válido para recuperar.');
      return;
    }

    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
    });

    try {
      await widget.authService.sendPasswordResetEmail(email);
      if (!mounted) return;
      setState(() {
        _isSuccess = true;
        _feedbackMessage = 'Enlace de recuperación enviado a $email.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedbackMessage = _parseAuthError(e);
        _isSuccess = false;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseAuthError(Object error) {
    final message = error.toString();
    if (message.contains('wrong-password') || message.contains('invalid-credential')) {
      return 'Email o contraseña incorrectos.';
    }
    if (message.contains('email-already-in-use')) {
      return 'Este email ya está registrado.';
    }
    if (message.contains('weak-password')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (message.contains('invalid-email')) {
      return 'El formato del email no es válido.';
    }
    if (message.contains('user-not-found')) {
      return 'No existe una cuenta con ese email.';
    }
    return 'Error de autenticación. Intenta de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = width >= AppBreakpoints.tablet ? 440.0 : width * 0.92;

    return PymeScaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              Text('PYME', style: AppTextStyles.brandTitle),
              const SizedBox(height: 8),
              Text('WORKSPACE OF CLARITY', style: AppTextStyles.brandSubtitle),
              const SizedBox(height: 40),
              GlassCard(
                width: cardWidth,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isLoginMode ? 'Welcome' : 'Create account',
                        style: AppTextStyles.sectionTitle,
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 24),
                        height: 1,
                        width: 48,
                        color: AppColors.secondaryText.withValues(alpha: 0.4),
                      ),
                      if (_feedbackMessage != null)
                        _isSuccess
                            ? StatusBanner.success(message: _feedbackMessage!)
                            : StatusBanner.error(message: _feedbackMessage!),
                      GlassTextField(
                        controller: _emailController,
                        label: 'EMAIL ADDRESS',
                        hint: 'name@company.com',
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoading,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El email es obligatorio';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Ingresa un email válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      GlassTextField(
                        controller: _passwordController,
                        label: 'PASSWORD',
                        hint: '........',
                        obscureText: _obscurePassword,
                        enabled: !_isLoading,
                        suffix: _isLoginMode
                            ? TextButton(
                                onPressed: _isLoading ? null : _resetPassword,
                                child: const Text(
                                  'Forgot?',
                                  style: TextStyle(
                                    color: AppColors.linkBlue,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : null,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'La contraseña es obligatoria';
                          }
                          if (value.length < 6) {
                            return 'Mínimo 6 caracteres';
                          }
                          return null;
                        },
                      ),
                      if (!_isLoginMode) ...[
                        const SizedBox(height: 20),
                        GlassTextField(
                          controller: _confirmPasswordController,
                          label: 'CONFIRM PASSWORD',
                          obscureText: _obscurePassword,
                          enabled: !_isLoading,
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return 'Las contraseñas no coinciden';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      PymeOutlinedButton(
                        label: _isLoginMode ? 'LOGIN →' : 'REGISTER →',
                        isLoading: _isLoading,
                        onPressed: _submit,
                        icon: Icons.arrow_forward_rounded,
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => setState(() {
                                    _isLoginMode = !_isLoginMode;
                                    _feedbackMessage = null;
                                  }),
                          child: RichText(
                            text: TextSpan(
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.secondaryText,
                              ),
                              children: [
                                TextSpan(
                                  text: _isLoginMode
                                      ? 'Don\'t have an account? '
                                      : 'Already have an account? ',
                                ),
                                TextSpan(
                                  text: _isLoginMode
                                      ? 'Request access'
                                      : 'Sign in',
                                  style: const TextStyle(
                                    color: AppColors.linkBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
              Text(
                '© 2025 ETHOS CRM. HIGH-PERFORMANCE DIGITAL ENVIRONMENTS.',
                textAlign: TextAlign.center,
                style: AppTextStyles.brandSubtitle.copyWith(fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
