import 'package:flutter/material.dart';

/// Paso de valor (texto + icono) en landing, home y login.
class AppPitchStep {
  const AppPitchStep({required this.text, required this.icon});

  final String text;
  final IconData icon;
}

/// Una sola fuente de verdad para los 5 pasos.
const List<AppPitchStep> kAppPitchStepsList = [
  AppPitchStep(
    text: 'Busca tus ejercicios',
    icon: Icons.sports_gymnastics_rounded,
  ),
  AppPitchStep(
    text: 'Crea tu rutina',
    icon: Icons.playlist_add_check_rounded,
  ),
  AppPitchStep(
    text: 'Crea tu planning',
    icon: Icons.calendar_month_rounded,
  ),
  AppPitchStep(
    text: 'Contacta con los mejores profesores y clases',
    icon: Icons.school_outlined,
  ),
  AppPitchStep(
    text: 'Haz amigos fitness',
    icon: Icons.groups_2_rounded,
  ),
];
