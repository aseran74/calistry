import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:calistenia_app/core/router/route_paths.dart';
import 'package:calistenia_app/core/widgets/app_pitch_steps_panel.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _appVersionLine;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersionLine = 'Versión ${info.version} · build ${info.buildNumber}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _appVersionLine = 'Versión 1.6.0');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider).signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    ref.listen(authControllerProvider, (previous, next) {
      if (next.busy || !next.isAuthenticated) return;
      if (previous?.isAuthenticated == true) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.go('/user');
      });
    });
    
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 850;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFF070807),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left decorative column
            Expanded(
              flex: 11,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF070807),
                      const Color(0xFF0E1310),
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative ambient lights
                    Positioned(
                      right: -60,
                      top: -60,
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -40,
                      bottom: -40,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    // Branding Content
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(
                                      colors: [
                                        theme.colorScheme.primary,
                                        theme.colorScheme.secondary,
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.fitness_center_rounded,
                                    color: theme.colorScheme.onPrimary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  'Calistry',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(flex: 2),
                            Text(
                              'Entrena al siguiente nivel.',
                              style: theme.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Organiza tu planning, crea rutinas de calistenia y realiza un seguimiento de tu progreso con tu profesor o por tu cuenta.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.65),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 40),
                            const Expanded(
                              flex: 12,
                              child: SingleChildScrollView(
                                physics: BouncingScrollPhysics(),
                                child: AppPitchStepsPanel(compact: true),
                              ),
                            ),
                            const Spacer(flex: 3),
                            Text(
                              '© ${DateTime.now().year} Calistry. Diseñado para atletas.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Right form column
            Expanded(
              flex: 9,
              child: ColoredBox(
                color: theme.scaffoldBackgroundColor,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Card(
                        color: theme.colorScheme.surface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: _buildFormChildren(context, theme, auth, isDesktop: true),
                            ),
                          ),
                        ),
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildFormChildren(context, theme, auth, isDesktop: false),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFormChildren(
    BuildContext context,
    ThemeData theme,
    AuthController auth, {
    required bool isDesktop,
  }) {
    return [
      if (!isDesktop) ...[
        Image.asset(
          'logo/Logo 3.png',
          width: 640,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            width: double.infinity,
            height: 180,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF111111), Color(0xFF1E1E1E)],
              ),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              size: 80,
              color: Color(0xFF00FF87),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Calistry',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ] else ...[
        Text(
          '¡Hola de nuevo!',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
      ],
      Text(
        'Inicia sesión para acceder a tus rutinas, progreso y perfil.',
        textAlign: isDesktop ? TextAlign.start : TextAlign.center,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      if (kIsWeb && !isDesktop) ...[
        const SizedBox(height: 20),
        const AppPitchStepsPanel(compact: true),
        const SizedBox(height: 24),
      ] else ...[
        const SizedBox(height: 24),
      ],
      TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Correo',
          prefixIcon: Icon(Icons.mail_outline),
        ),
        validator: (value) {
          final email = value?.trim() ?? '';
          if (email.isEmpty || !email.contains('@')) {
            return 'Introduce un correo válido.';
          }
          return null;
        },
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _passwordController,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'Contraseña',
          prefixIcon: Icon(Icons.lock_outline),
        ),
        validator: (value) {
          if ((value ?? '').isEmpty) {
            return 'Introduce tu contraseña.';
          }
          return null;
        },
        onFieldSubmitted: (_) => _submit(),
      ),
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: auth.busy ? null : _submit,
          icon: auth.busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.login),
          label: const Text('Entrar con correo'),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: auth.busy
              ? null
              : () => ref.read(authControllerProvider).signInWithGoogle(),
          icon: const Icon(Icons.account_circle_outlined),
          label: Text(
            auth.busy ? 'Conectando con Google...' : 'Continuar con Google',
          ),
        ),
      ),
      if (auth.errorMessage != null &&
          auth.errorMessage!.trim().isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          auth.errorMessage!,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ],
      const SizedBox(height: 16),
      Align(
        alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
        child: TextButton(
          onPressed: () => context.push(kPrivacyPath),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Política de privacidad'),
        ),
      ),
      if (kIsWeb) ...[
        const SizedBox(height: 8),
        Align(
          alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
          child: TextButton.icon(
            onPressed: () => context.go('/welcome'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Volver a la portada'),
          ),
        ),
      ],
      if (_appVersionLine != null) ...[
        const SizedBox(height: 24),
        Align(
          alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              _appVersionLine!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ],
    ];
  }
}
