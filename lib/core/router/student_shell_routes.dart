/// Rutas del dashboard de alumno / usuario (misma UX que la app, bajo prefijo `/user`).
abstract final class StudentShellRoutes {
  static const home = '/user';
  static const exercises = '/user/exercises';
  static const routines = '/user/routines';
  static const planning = '/user/planning';
  static const profile = '/user/profile';

  static String exerciseDetail(String id) => '/user/exercises/$id';

  static String routinePlay(String id) => '/user/routines/$id/play';

  static const routineCreate = '/user/routines/create';

  static String exercisesWithCategory(String category) =>
      '/user/exercises?category=$category';
}
