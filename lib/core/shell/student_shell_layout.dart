import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Layout del shell de alumno: en web ancho se usa sidebar; en móvil / ventana estrecha, bottom bar.
abstract final class StudentShellLayout {
  /// Ancho mínimo del viewport para mostrar sidebar en web.
  static const double webSidebarBreakpoint = 900;

  /// `true` cuando debe mostrarse el [NavigationBar] inferior (móvil o web estrecho).
  static bool useBottomNavigationBar(BuildContext context) {
    if (!kIsWeb) return true;
    final w = MediaQuery.sizeOf(context).width;
    return w < webSidebarBreakpoint;
  }

  /// Padding inferior del body (espacio para bottom nav o margen con sidebar).
  static double bodyBottomPadding(BuildContext context) {
    return useBottomNavigationBar(context) ? 120 : 28;
  }

  /// Altura extra al final de listas (slivers) por la misma razón.
  static double scrollBottomSpacer(BuildContext context) {
    return useBottomNavigationBar(context) ? 120 : 32;
  }
}
