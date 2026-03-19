-- Añadir nuevas categorías y dificultades para ejercicios
-- (Taichi, Calistenia, Tercera edad / facil, moderado, dificil)

ALTER TYPE category_enum ADD VALUE IF NOT EXISTS 'taichi';
ALTER TYPE category_enum ADD VALUE IF NOT EXISTS 'calistenia';
ALTER TYPE category_enum ADD VALUE IF NOT EXISTS 'tercera_edad';

ALTER TYPE difficulty_enum ADD VALUE IF NOT EXISTS 'facil';
ALTER TYPE difficulty_enum ADD VALUE IF NOT EXISTS 'moderado';
ALTER TYPE difficulty_enum ADD VALUE IF NOT EXISTS 'dificil';
