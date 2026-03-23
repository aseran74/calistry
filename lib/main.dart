import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:calistenia_app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Vercel / hosting estático: URLs con hash (#/welcome) evitan 404 en rutas profundas.
  if (kIsWeb) {
    setUrlStrategy(const HashUrlStrategy());
  }
  runApp(
    const ProviderScope(
      child: CalisteniaApp(),
    ),
  );
}
