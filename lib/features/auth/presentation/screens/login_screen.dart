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

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _appVersionLine;
  late final AnimationController _enter;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));
    _enter.forward();
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
    _enter.dispose();
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
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final isDesktop = width >= 900;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFF070807),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            // En pantallas muy anchas el layout no se estira de borde a borde.
            final shellMax = w >= 1600 ? 1480.0 : (w >= 1200 ? 1280.0 : w);
            final brandPadH = w >= 1200 ? 64.0 : 48.0;
            final formPadH = w >= 1200 ? 56.0 : 40.0;
            final outerGap = ((w - shellMax) / 2).clamp(0.0, 120.0);

            return ColoredBox(
              color: const Color(0xFF050605),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: outerGap),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: shellMax),
                    child: ClipRRect(
                      borderRadius: outerGap > 0
                          ? BorderRadius.circular(28)
                          : BorderRadius.zero,
                      child: SizedBox(
                        height: constraints.maxHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 11,
                              child: _BrandPanel(
                                horizontalPadding: brandPadH,
                              ),
                            ),
                            Expanded(
                              flex: 9,
                              child: ColoredBox(
                                color: theme.scaffoldBackgroundColor,
                                child: FadeTransition(
                                  opacity: _fade,
                                  child: SlideTransition(
                                    position: _slide,
                                    child: Center(
                                      child: SingleChildScrollView(
                                        padding: EdgeInsets.fromLTRB(
                                          formPadH,
                                          40,
                                          formPadH,
                                          40,
                                        ),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 400,
                                          ),
                                          child: Form(
                                            key: _formKey,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: _buildFormChildren(
                                                context,
                                                theme,
                                                auth,
                                                isDesktop: true,
                                              ),
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
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: width >= 600 ? 40 : 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _buildFormChildren(
                        context,
                        theme,
                        auth,
                        isDesktop: false,
                      ),
                    ),
                  ),
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
          width: 280,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            width: double.infinity,
            height: 140,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF111111), Color(0xFF1E1E1E)],
              ),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              size: 64,
              color: Color(0xFF00FF87),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Calistry',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
      ] else ...[
        Text(
          'Calistry',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '¡Hola de nuevo!',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
      ],
      Text(
        'Inicia sesión para acceder a tus rutinas, progreso y perfil.',
        textAlign: isDesktop ? TextAlign.start : TextAlign.center,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.45,
        ),
      ),
      if (kIsWeb && !isDesktop) ...[
        const SizedBox(height: 20),
        const AppPitchStepsPanel(compact: true),
        const SizedBox(height: 28),
      ] else ...[
        const SizedBox(height: 28),
      ],
      TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
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
        textInputAction: TextInputAction.done,
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
      const SizedBox(height: 22),
      SizedBox(
        width: double.infinity,
        height: 48,
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
              : const Icon(Icons.login_rounded),
          label: const Text('Entrar con correo'),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        height: 48,
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
          textAlign: isDesktop ? TextAlign.start : TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ],
      const SizedBox(height: 20),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
        children: [
          TextButton(
            onPressed: () => context.push(kPrivacyPath),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Política de privacidad'),
          ),
          if (kIsWeb)
            TextButton.icon(
              onPressed: () => context.go('/welcome'),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Volver a la portada'),
            ),
        ],
      ),
      if (_appVersionLine != null) ...[
        const SizedBox(height: 28),
        Text(
          _appVersionLine!,
          textAlign: isDesktop ? TextAlign.start : TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
          ),
        ),
      ],
    ];
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.horizontalPadding});

  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF070807),
            const Color(0xFF0C1210),
            theme.colorScheme.primaryContainer.withValues(alpha: 0.22),
          ],
        ),
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -80,
            top: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            left: -50,
            bottom: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                44,
                horizontalPadding,
                36,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
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
                        'Entrena al\nsiguiente nivel.',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.08,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Organiza tu planning, crea rutinas de calistenia y sigue tu progreso con tu profesor o por tu cuenta.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.68),
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Expanded(
                        flex: 12,
                        child: SingleChildScrollView(
                          physics: BouncingScrollPhysics(),
                          child: AppPitchStepsPanel(compact: true),
                        ),
                      ),
                      const Spacer(flex: 2),
                      Text(
                        '© ${DateTime.now().year} Calistry · Diseñado para atletas',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
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
