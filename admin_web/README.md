# Calistenia Admin Web

Panel admin Flutter Web para gestionar usuarios, ejercicios, rutinas y vídeos sobre Insforge.

## Requisitos

- Flutter instalado
- Acceso a Insforge
- Un usuario con `role = 'admin'` o `role = 'moderator'` en la tabla `users`

## Ejecutar en local

```bash
cd admin_web
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=https://swd7siw3.eu-central.insforge.app
```

Si quieres pasar una `anon key`, añade también:

```bash
--dart-define=API_ANON_KEY=tu_anon_key
```

## Build web

```bash
cd admin_web
flutter build web --dart-define=API_BASE_URL=https://swd7siw3.eu-central.insforge.app
```

## Qué incluye

- Login por Google
- Login por correo y contraseña
- Persistencia de sesión
- Dashboard con métricas básicas
- Gestión de usuarios y roles
- CRUD básico de ejercicios
- Subida de vídeos a `exercises-media`
- Gestión básica de rutinas
