const exerciseCategories = [
  'taichi',
  'calistenia',
  'tercera_edad',
];

const exerciseDifficulties = [
  'facil',
  'moderado',
  'dificil',
];

String exerciseCategoryLabel(String value) {
  switch (value.toLowerCase()) {
    case 'taichi':
      return 'Taichi';
    case 'calistenia':
      return 'Calistenia';
    case 'tercera_edad':
      return 'Tercera edad';
    case 'fuerza':
      return 'Fuerza';
    case 'movilidad':
      return 'Movilidad';
    case 'cardio':
      return 'Cardio';
    case 'flexibilidad':
      return 'Flexibilidad';
    default:
      return value;
  }
}

String exerciseDifficultyLabel(String value) {
  switch (value.toLowerCase()) {
    case 'facil':
      return 'Facil';
    case 'moderado':
      return 'Moderado';
    case 'dificil':
      return 'Dificil';
    case 'principiante':
      return 'Facil';
    case 'intermedio':
      return 'Moderado';
    case 'avanzado':
      return 'Dificil';
    default:
      return value;
  }
}
