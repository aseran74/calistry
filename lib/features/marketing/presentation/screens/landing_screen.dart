import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Tipografía = theme global (Poppins en [AppTheme]); evita cargar fuentes extra en web.
TextStyle _landingStyle(
  BuildContext context, {
  required double fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
}) {
  final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
  return base.copyWith(
    fontSize: fontSize,
    fontWeight: fontWeight ?? FontWeight.w500,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

TextStyle _landingDisplay(BuildContext context, double fontSize) {
  final base = Theme.of(context).textTheme.displaySmall ?? const TextStyle();
  return base.copyWith(
    fontSize: fontSize,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    height: 1.05,
  );
}

/// Landing pública (pensada para Flutter Web). Marca: Calistry — calistenia + planning.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  static const _accent = Color(0xFF3DFF9C);
  static const _accentDim = Color(0xFF1A4D35);
  static const _bg = Color(0xFF070807);
  static const _surface = Color(0xFF101210);

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _scroll = ScrollController();
  final _featuresKey = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToFeatures() {
    final ctx = _featuresKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isNarrow = w < 720;

    return Material(
      color: LandingScreen._bg,
      child: Scaffold(
        backgroundColor: LandingScreen._bg,
        body: SelectionArea(
          child: CustomScrollView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _LandingNav(isNarrow: isNarrow)),
              SliverToBoxAdapter(
                child: _Hero(
                  isNarrow: isNarrow,
                  onScrollToFeatures: _scrollToFeatures,
                ),
              ),
              SliverToBoxAdapter(
                key: _featuresKey,
                child: _FeatureGrid(isNarrow: isNarrow),
              ),
              SliverToBoxAdapter(child: _ClosingCta(isNarrow: isNarrow)),
              const SliverToBoxAdapter(child: _Footer()),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingNav extends StatelessWidget {
  const _LandingNav({required this.isNarrow});

  final bool isNarrow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isNarrow ? 20 : 48,
        isNarrow ? 20 : 28,
        isNarrow ? 20 : 48,
        12,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Row(
            children: [
              _LogoMark(),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text(
                  'Entrar',
                  style: _landingStyle(
                    context,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: LandingScreen._accent,
                  foregroundColor: const Color(0xFF04210F),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => context.go('/login'),
                child: Text(
                  'Empezar',
                  style: _landingStyle(
                    context,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF04210F),
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

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        'logo/Logo4.png',
        height: 124,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Text(
          'Calistry',
          style: _landingStyle(
            context,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.isNarrow,
    required this.onScrollToFeatures,
  });

  final bool isNarrow;
  final VoidCallback onScrollToFeatures;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 20 : 48, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  LandingScreen._surface,
                  LandingScreen._surface.withValues(alpha: 0.92),
                  const Color(0xFF0A1610),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: LandingScreen._accent.withValues(alpha: 0.08),
                  blurRadius: 60,
                  spreadRadius: -8,
                  offset: const Offset(0, 24),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  Positioned(
                    right: -40,
                    top: -60,
                    child: IgnorePointer(
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: LandingScreen._accent.withValues(alpha: 0.07),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -30,
                    bottom: -40,
                    child: IgnorePointer(
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: LandingScreen._accentDim.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(isNarrow ? 24 : 44),
                    child: isNarrow
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _HeroCopy(),
                              const SizedBox(height: 28),
                              _HeroActions(onScrollToFeatures: onScrollToFeatures),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _HeroCopy(),
                                    const SizedBox(height: 28),
                                    _HeroActions(
                                      onScrollToFeatures: onScrollToFeatures,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 32),
                              Expanded(
                                flex: 4,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: _HeroAside(),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: LandingScreen._accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: LandingScreen._accent.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            'Web · Rutinas · Planning · Profes',
            style: _landingStyle(
              context,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: LandingScreen._accent,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Tu cuerpo.\nTu plan.\nSin ruido.',
          style: _landingDisplay(context, 46),
        ),
        const SizedBox(height: 18),
        Text(
          'Organiza calistenia con rutinas propias o asignadas, planning semanal '
          'y seguimiento. Pensado para alumnos y para quien entrena en serio.',
          style: _landingStyle(
            context,
            fontSize: 17,
            height: 1.55,
            color: Colors.white.withValues(alpha: 0.62),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _HeroActions extends StatelessWidget {
  const _HeroActions({required this.onScrollToFeatures});

  final VoidCallback onScrollToFeatures;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 520;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: LandingScreen._accent,
                foregroundColor: const Color(0xFF04210F),
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 20 : 28,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => context.go('/login'),
              child: Text(
                'Crear cuenta / Entrar',
                style: _landingStyle(
                  context,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF04210F),
                ),
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.85),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 18 : 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onScrollToFeatures,
              child: Text(
                'Ver qué incluye',
                style: _landingStyle(
                  context,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            // TODO: vincular con la URL oficial de Play Store cuando esté publicada.
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'logo/google_play_badge.png',
              height: isNarrow ? 48 : 56,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroAside extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      ('Rutinas', 'Tuyas, públicas o asignadas por tu profe.'),
      ('Planning', 'Encaja entrenos en la semana sin perder el hilo.'),
      ('Progreso', 'Marca sesiones y mantén constancia visible.'),
    ];
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _StatCard(title: items[i].$1, subtitle: items[i].$2),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: LandingScreen._accent.withValues(alpha: 0.9),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _landingStyle(
                      context,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: _landingStyle(
                      context,
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.isNarrow});

  final bool isNarrow;

  @override
  Widget build(BuildContext context) {
    final cards = <({IconData icon, String t, String d})>[
      (
        icon: Icons.playlist_add_check_rounded,
        t: 'Rutinas vivas',
        d: 'Crea, explora y reproduce series con ejercicios reales.',
      ),
      (
        icon: Icons.calendar_month_rounded,
        t: 'Planning claro',
        d: 'Huecos por día y hora; copia horarios que te asigne tu profe.',
      ),
      (
        icon: Icons.school_outlined,
        t: 'Aula conectada',
        d: 'Asignaciones, mensajes y clases cuando tu centro las active.',
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(isNarrow ? 20 : 48, 8, isNarrow ? 20 : 48, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Todo en un solo flujo',
                style: _landingDisplay(context, 28),
              ),
              const SizedBox(height: 8),
              Text(
                'Menos apps sueltas. Más constancia.',
                style: _landingStyle(
                  context,
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 28),
              if (isNarrow)
                Column(
                  children: [
                    for (final c in cards) ...[
                      _FeatureTile(icon: c.icon, title: c.t, body: c.d),
                      const SizedBox(height: 14),
                    ],
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 18),
                      Expanded(
                        child: _FeatureTile(
                          icon: cards[i].icon,
                          title: cards[i].t,
                          body: cards[i].d,
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LandingScreen._surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: LandingScreen._accent, size: 30),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosingCta extends StatelessWidget {
  const _ClosingCta({required this.isNarrow});

  final bool isNarrow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isNarrow ? 20 : 48, 12, isNarrow ? 20 : 48, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  LandingScreen._accentDim.withValues(alpha: 0.55),
                  LandingScreen._surface,
                ],
              ),
              border: Border.all(
                color: LandingScreen._accent.withValues(alpha: 0.25),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(isNarrow ? 24 : 36),
              child: Column(
                children: [
                  Text(
                    '¿Listo para tu próxima sesión?',
                    textAlign: TextAlign.center,
                    style: _landingDisplay(
                      context,
                      isNarrow ? 24 : 30,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Entra con tu cuenta y sigue donde lo dejaste en móvil o web.',
                    textAlign: TextAlign.center,
                    style: _landingStyle(
                      context,
                      fontSize: 15,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: LandingScreen._accent,
                      foregroundColor: const Color(0xFF04210F),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => context.go('/login'),
                    child: Text(
                      'Ir al inicio de sesión',
                      style: _landingStyle(
                        context,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF04210F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Center(
        child: Text(
          '© ${DateTime.now().year} Calistry',
          style: _landingStyle(
            context,
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}
