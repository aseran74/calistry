-- ============================================
-- BORRAR SOLO EL ESQUEMA DE CALISTENIA
-- Usar ÚNICAMENTE en el proyecto "My first project"
-- donde se creó por error. No ejecutar en Calistenia.
-- ============================================

-- 1. Tablas (orden por dependencias; CASCADE quita políticas e índices)
DROP TABLE IF EXISTS admin_logs CASCADE;
DROP TABLE IF EXISTS user_favorites CASCADE;
DROP TABLE IF EXISTS user_progress CASCADE;
DROP TABLE IF EXISTS routine_exercises CASCADE;
DROP TABLE IF EXISTS routines CASCADE;
DROP TABLE IF EXISTS exercises CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- 2. Tipos ENUM usados solo por las tablas de Calistenia
DROP TYPE IF EXISTS nivel_enum CASCADE;
DROP TYPE IF EXISTS role_enum CASCADE;
DROP TYPE IF EXISTS category_enum CASCADE;
DROP TYPE IF EXISTS difficulty_enum CASCADE;
