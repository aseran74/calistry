import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:calistenia_app/core/router/route_paths.dart';

/// Página pública de política de privacidad (web y app). Estilo alineado con la landing.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _bg = Color(0xFF070807);
  static const _surface = Color(0xFF101210);
  static const _accent = Color(0xFF3DFF9C);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(kIsWeb ? kLandingPath : '/login');
            }
          },
        ),
        title: Text(
          'Política de privacidad',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Última actualización: ${DateTime.now().year}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Heading('1. Introducción'),
                        const SizedBox(height: 8),
                        _Body(
                          'Calistry (“la aplicación”) respeta tu privacidad. Esta política '
                          'describe qué datos podemos tratar, con qué finalidades y qué '
                          'derechos tienes cuando usas el servicio.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Heading('2. Responsable del tratamiento'),
                        const SizedBox(height: 8),
                        _Body(
                          'El responsable del tratamiento de los datos personales asociados '
                          'al uso de Calistry es quien publique y mantenga la aplicación en '
                          'cada entorno (por ejemplo, el titular de la cuenta de desarrollador '
                          'en las tiendas de aplicaciones). Para ejercer tus derechos, puedes '
                          'utilizar los canales de contacto indicados al final de este documento.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Heading('3. Datos que podemos tratar'),
                        const SizedBox(height: 8),
                        _Body(
                          'Según cómo utilices la aplicación, podemos tratar, entre otros:',
                        ),
                        const SizedBox(height: 10),
                        _Bullet('Datos de cuenta e identificación: correo electrónico, '
                            'identificador de usuario, nombre o alias.'),
                        _Bullet('Datos de uso y dispositivo: registros técnicos, tipo de '
                            'dispositivo, sistema operativo, idioma, fecha y hora de acceso.'),
                        _Bullet('Contenidos que generes en la app: rutinas, ejercicios, '
                            'mensajes, preferencias o información de perfil que decidas '
                            'compartir.'),
                        _Bullet('Datos de comunicaciones: mensajes o notificaciones '
                            'gestionadas a través de la plataforma, cuando corresponda.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Heading('4. Finalidades'),
                        const SizedBox(height: 8),
                        _Bullet('Prestar el servicio: autenticación, sincronización de datos, '
                            'funcionalidades de entrenamiento y comunicación entre usuarios '
                            'cuando la app lo permita.'),
                        _Bullet('Seguridad e integridad: prevención de abusos, detección de '
                            'incidentes y mejora de la fiabilidad del servicio.'),
                        _Bullet('Cumplimiento legal: atender obligaciones aplicables cuando '
                            'proceda.'),
                        _Bullet('Mejora del producto: estadísticas agregadas o analítica '
                            'interna, preferiblemente sin identificarte de forma directa '
                            'cuando sea posible.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Heading('5. Base legal'),
                        const SizedBox(height: 8),
                        _Body(
                          'Tratamos datos según la base legal que corresponda en cada caso: '
                          'ejecución del contrato o condiciones de uso del servicio, interés '
                          'legítimo en la seguridad y mejora del servicio (con equilibrio con '
                          'tus derechos), o consentimiento cuando sea necesario para '
                          'funcionalidades opcionales o comunicaciones no esenciales.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Heading('6. Conservación'),
                        const SizedBox(height: 8),
                        _Body(
                          'Conservamos la información el tiempo necesario para cumplir las '
                          'finalidades descritas y las obligaciones legales. Cuando ya no sea '
                          'necesaria, se suprimirá o anonimizará según proceda.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Heading('7. Encargados y transferencias'),
                        const SizedBox(height: 8),
                        _Body(
                          'Podemos utilizar proveedores de alojamiento, bases de datos, '
                          'autenticación o infraestructura en la nube. Estos encargados tratan '
                          'datos siguiendo instrucciones y medidas de seguridad adecuadas. '
                          'Si hubiera transferencias internacionales, se aplicarán las '
                          'garantías exigidas por la normativa aplicable.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Heading('8. Tus derechos'),
                        const SizedBox(height: 8),
                        _Body(
                          'Puedes solicitar acceso, rectificación, supresión, limitación del '
                          'tratamiento, portabilidad u oposición cuando la normativa aplicable '
                          'lo permita. También puedes retirar el consentimiento en los casos en '
                          'que el tratamiento se base en él.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Heading('9. Seguridad'),
                        const SizedBox(height: 8),
                        _Body(
                          'Aplicamos medidas técnicas y organizativas razonables para proteger '
                          'tus datos. Ningún sistema es 100 % seguro; si detectas un problema, '
                          'contacta con nosotros.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Heading('10. Menores'),
                        const SizedBox(height: 8),
                        _Body(
                          'El servicio no está dirigido a menores sin el consentimiento o '
                          'autorización de quien ejerce la patria potestad o tutela, según '
                          'corresponda. Si tienes conocimiento de datos de menores recogidos '
                          'sin autorización, infórmanos.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Heading('11. Cambios en esta política'),
                        const SizedBox(height: 8),
                        _Body(
                          'Podemos actualizar esta política para reflejar cambios legales o '
                          'del producto. Publicaremos la versión vigente en la aplicación o en '
                          'la web. El uso continuado del servicio tras la actualización puede '
                          'implicar la aceptación de los cambios cuando la ley lo permita.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Heading('12. Contacto'),
                        const SizedBox(height: 8),
                        _Body(
                          'Para consultas sobre privacidad o para ejercer tus derechos, '
                          'puedes contactarnos a través del correo indicado a continuación '
                          'o por los canales publicados en la ficha de la aplicación en la '
                          'tienda (Google Play, etc.).',
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          'privacidad@calistry.app',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _accent,
                            fontWeight: FontWeight.w700,
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PrivacyPolicyScreen._surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.88),
            height: 1.45,
          ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: PrivacyPolicyScreen._accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
