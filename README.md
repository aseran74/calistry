# Calistenia App

App Flutter de calistenia con ejercicios, rutinas y progreso. Backend en Insforge.

## Raíz del proyecto

Todo el código vive bajo **`C:\Proyectos\Caliosteniaflutter`** (esta carpeta).  
Ahí es donde debes abrir el workspace en el IDE y donde arrancas **la app principal** (`flutter run`).

## Web desde la raíz: landing, login y tres dashboards

Desde **`C:\Proyectos\Caliosteniaflutter`** puedes levantar **la misma app** en Chrome.

- **Portada (solo web):** ruta **`/welcome`**. En el navegador verás **`#/welcome`** (estrategia **hash**), igual que en `flutter run -d chrome`; en **Vercel** la URL por defecto queda así y no hace falta rewrite por ruta. **`/`** redirige a la landing. Mientras hidrata la sesión puedes quedarte en la portada (no obliga a pasar solo por `/auth-loading`). Landing con enlaces a **Entrar** (`/login`).
- **Login:** `/login`
- Tras iniciar sesión, el destino depende del **rol** en la tabla `users` (el rol se hidrata en login, ver `hydrateSessionRole`):

| Rol (Insforge / `users.role`) | Pantalla principal |
|-------------------------------|--------------------|
| **`admin`** o **`moderator`** | Panel de administración (`/admin`, `AdminDashboardScreen`) — solo en **web** (`kIsWeb`). |
| **`teacher`** (y no admin en web) | Espacio de profesor (`/teacher` y rutas de alumnos, grupos, ejercicios, etc.). |
| **`user`** / alumno (u otros) | Dashboard en **`#/user`**. En **web** con ventana ≥ **900px** de ancho: **sidebar** izquierdo + área de contenido; si la ventana es más estrecha o es móvil, se mantiene la **barra inferior** (misma navegación). Rutas: `/user/exercises`, `/user/routines`, etc. |

Comando típico (mismas `dart-define` que en móvil si las usas):

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=https://TU_INSTANCIA.insforge.app --dart-define=API_ANON_KEY=tu_anon_key
```

**Importante:** sustituye `TU_INSTANCIA` por el host **real** de tu proyecto (copiado del panel de Insforge). Debe ser algo como `https://abcd1234.eu-central.insforge.app` (palabra **insforge**, no “instorga” ni dominios inventados). Si dejas un placeholder, en web verás `ClientException: Failed to fetch` al pulsar Google o al llamar a la API.

Si la URL es correcta y sigue fallando en **Chrome**: configura **CORS** en Insforge para permitir el origen de tu dev server (`http://localhost:PUERTO`).

La lógica de redirección está en `lib/core/router/app_router.dart`; en web, admin/moderador no usan el shell de alumno porque `auth.isAdmin` es verdadero solo en web (`lib/features/auth/presentation/providers/auth_controller.dart`).

### `admin_web/` (opcional)

Carpeta **`admin_web/`**: subproyecto Flutter web **alternativo** con otra estructura de código. **No hace falta** para el flujo unificado anterior: la raíz ya incluye un panel admin integrado. Si aún lo usas, ver **[`admin_web/README.md`](admin_web/README.md)**.

## Requisitos

- Flutter 3.19+
- Cuenta Insforge con proyecto Calistenia

## Configuración

1. **Clave anónima (anon key)**  
   En `lib/core/config/api_config.dart` puedes definir la anon key por defecto o usar variables de entorno:

   ```bash
   flutter run --dart-define=API_BASE_URL=https://swd7siw3.eu-central.insforge.app --dart-define=API_ANON_KEY=tu_anon_key
   ```

2. **Backend**  
   Las Edge Functions (get-exercises, get-exercise, toggle-favorite, etc.) deben estar desplegadas en tu proyecto Insforge Calistenia y la base de datos con el esquema de `supabase/migrations/001_calistenia_schema.sql` (y migraciones posteriores).  
   Para **horarios en rutinas asignadas** (días + hora), aplica también `supabase/migrations/013_routine_assignment_schedule.sql` en Insforge.

## Ejecutar (app principal, desde la raíz)

En **`C:\Proyectos\Caliosteniaflutter`**:

```bash
flutter pub get
flutter run                    # dispositivo por defecto (móvil / escritorio)
flutter run -d chrome          # web: login único y dashboard según rol (ver arriba)
```

## Estructura (Pantallas de ejercicios)

- **ExercisesScreen**: lista en grid 2 columnas, filtros por categoría/dificultad, búsqueda con debounce 300 ms, paginación 20 ítems, shimmer de carga.
- **ExerciseDetailScreen**: Hero desde la card, sección de media (video o GIF), descripción, músculos, botón favorito, “Agregar a rutina”.

Estado con Riverpod; API en `lib/core/api/api_client.dart` (llamadas a Edge Functions de Insforge).
