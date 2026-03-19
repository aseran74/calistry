# Calistenia App

App Flutter de calistenia con ejercicios, rutinas y progreso. Backend en Insforge.

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
   Las Edge Functions (get-exercises, get-exercise, toggle-favorite, etc.) deben estar desplegadas en tu proyecto Insforge Calistenia y la base de datos con el esquema de `supabase/migrations/001_calistenia_schema.sql`.

## Ejecutar

```bash
flutter pub get
flutter run
```

## Estructura (Pantallas de ejercicios)

- **ExercisesScreen**: lista en grid 2 columnas, filtros por categoría/dificultad, búsqueda con debounce 300 ms, paginación 20 ítems, shimmer de carga.
- **ExerciseDetailScreen**: Hero desde la card, sección de media (video o GIF), descripción, músculos, botón favorito, “Agregar a rutina”.

Estado con Riverpod; API en `lib/core/api/api_client.dart` (llamadas a Edge Functions de Insforge).
