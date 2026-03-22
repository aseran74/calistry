# Calistenia Admin Web

Panel admin Flutter Web para gestionar usuarios, ejercicios, rutinas y vídeos sobre Insforge.

> **Importante:** la raíz del repositorio es **`Caliosteniaflutter`** (la carpeta padre), no `admin_web`.  
> Abre el proyecto en `C:\Proyectos\Caliosteniaflutter` y, para este panel, entra a `admin_web` solo al ejecutar comandos.

> **Flujo recomendado (admin + profe + alumno):** desde la raíz del repo ejecuta `flutter run -d chrome` sobre la **app principal** (`calistenia_app`): un solo login y el router te lleva a `/admin`, `/teacher` o al shell de alumno según el rol. Este subproyecto `admin_web` es una variante aparte; no es obligatoria para ese flujo. Ver **[README en la raíz](../README.md)** (sección «Web desde la raíz: un login, tres dashboards»).

## Requisitos

- Flutter instalado
- Acceso a Insforge
- Un usuario con `role = 'admin'` o `role = 'moderator'` en la tabla `users`

## Ejecutar en local

Desde la raíz del repo (`C:\Proyectos\Caliosteniaflutter`):

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

Desde la raíz del repo (`C:\Proyectos\Caliosteniaflutter`):

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
