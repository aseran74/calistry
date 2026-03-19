-- ============================================
-- Esquema completo Calistenia (PostgreSQL)
-- Ejecutar en el proyecto Calistenia (Insforge/Supabase)
-- ============================================

-- ENUMs
CREATE TYPE nivel_enum AS ENUM ('principiante', 'intermedio', 'avanzado');
CREATE TYPE role_enum AS ENUM ('user', 'admin', 'moderator');
CREATE TYPE category_enum AS ENUM ('fuerza', 'movilidad', 'cardio', 'flexibilidad');
CREATE TYPE difficulty_enum AS ENUM ('principiante', 'intermedio', 'avanzado');

-- Tablas
CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE NOT NULL,
  username text,
  avatar_url text,
  nivel nivel_enum DEFAULT 'principiante',
  role role_enum DEFAULT 'user',
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE exercises (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  category category_enum NOT NULL,
  difficulty difficulty_enum NOT NULL,
  muscle_groups text[] DEFAULT '{}',
  video_url text,
  gif_url text,
  thumbnail_url text,
  duration_seconds integer,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE routines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  level nivel_enum DEFAULT 'principiante',
  is_public boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE routine_exercises (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  routine_id uuid NOT NULL REFERENCES routines(id) ON DELETE CASCADE,
  exercise_id uuid NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  order_index integer NOT NULL DEFAULT 0,
  sets integer,
  reps integer,
  rest_seconds integer
);

CREATE TABLE user_progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  routine_id uuid NOT NULL REFERENCES routines(id) ON DELETE CASCADE,
  completed_at timestamptz DEFAULT now(),
  duration_seconds integer,
  notes text
);

CREATE TABLE user_favorites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  exercise_id uuid NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, exercise_id)
);

CREATE TABLE admin_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  action text NOT NULL,
  target_type text,
  target_id text,
  details jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

-- Índices
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_exercises_category ON exercises(category);
CREATE INDEX idx_exercises_difficulty ON exercises(difficulty);
CREATE INDEX idx_exercises_name ON exercises(name);
CREATE INDEX idx_exercises_is_active ON exercises(is_active);
CREATE INDEX idx_routines_user_id ON routines(user_id);
CREATE INDEX idx_routines_is_public ON routines(is_public);
CREATE INDEX idx_routine_exercises_routine_id ON routine_exercises(routine_id);
CREATE INDEX idx_user_progress_user_id ON user_progress(user_id);
CREATE INDEX idx_user_progress_completed_at ON user_progress(completed_at);
CREATE INDEX idx_user_favorites_user_id ON user_favorites(user_id);
CREATE INDEX idx_admin_logs_admin_id ON admin_logs(admin_id);
CREATE INDEX idx_admin_logs_created_at ON admin_logs(created_at);

-- Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE routines ENABLE ROW LEVEL SECURITY;
ALTER TABLE routine_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_logs ENABLE ROW LEVEL SECURITY;

-- Policies: usuarios ven/modifican solo sus datos; admins ven/modifican todo
CREATE POLICY "users_select_own" ON users FOR SELECT USING (id = auth.uid());
CREATE POLICY "users_select_admin" ON users FOR SELECT USING ((SELECT role FROM users WHERE id = auth.uid()) IN ('admin','moderator'));
CREATE POLICY "users_insert" ON users FOR INSERT WITH CHECK (true);
CREATE POLICY "users_update_own" ON users FOR UPDATE USING (id = auth.uid());
CREATE POLICY "users_update_admin" ON users FOR UPDATE USING ((SELECT role FROM users WHERE id = auth.uid()) IN ('admin','moderator'));

CREATE POLICY "exercises_select" ON exercises FOR SELECT USING (is_active = true);
CREATE POLICY "exercises_all_admin" ON exercises FOR ALL USING ((SELECT role FROM users WHERE id = auth.uid()) IN ('admin','moderator'));

CREATE POLICY "routines_select_own" ON routines FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "routines_select_public" ON routines FOR SELECT USING (is_public = true);
CREATE POLICY "routines_insert" ON routines FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "routines_update_own" ON routines FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "routines_delete_own" ON routines FOR DELETE USING (user_id = auth.uid());

CREATE POLICY "routine_exercises_select" ON routine_exercises FOR SELECT USING (
  EXISTS (SELECT 1 FROM routines r WHERE r.id = routine_exercises.routine_id AND (r.user_id = auth.uid() OR r.is_public = true))
);
CREATE POLICY "routine_exercises_insert" ON routine_exercises FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM routines r WHERE r.id = routine_exercises.routine_id AND r.user_id = auth.uid())
);
CREATE POLICY "routine_exercises_update" ON routine_exercises FOR UPDATE USING (
  EXISTS (SELECT 1 FROM routines r WHERE r.id = routine_exercises.routine_id AND r.user_id = auth.uid())
);
CREATE POLICY "routine_exercises_delete" ON routine_exercises FOR DELETE USING (
  EXISTS (SELECT 1 FROM routines r WHERE r.id = routine_exercises.routine_id AND r.user_id = auth.uid())
);

CREATE POLICY "user_progress_own" ON user_progress FOR ALL USING (user_id = auth.uid());
CREATE POLICY "user_favorites_own" ON user_favorites FOR ALL USING (user_id = auth.uid());

CREATE POLICY "admin_logs_select" ON admin_logs FOR SELECT USING ((SELECT role FROM users WHERE id = auth.uid()) IN ('admin','moderator'));
CREATE POLICY "admin_logs_insert" ON admin_logs FOR INSERT WITH CHECK (admin_id = auth.uid());

-- Seed: 10 ejercicios de calistenia
INSERT INTO exercises (name, description, category, difficulty, muscle_groups, duration_seconds) VALUES
('Flexiones (Push-ups)', 'Ejercicio básico de empuje horizontal. Mantén el cuerpo recto y baja el pecho hasta casi tocar el suelo.', 'fuerza', 'principiante', ARRAY['pecho', 'tríceps', 'hombros'], 60),
('Dominadas (Pull-ups)', 'Tirón vertical agarre prono. Sube hasta que la barbilla supere la barra.', 'fuerza', 'intermedio', ARRAY['espalda', 'bíceps'], 45),
('Fondos en paralelas (Dips)', 'Descenso entre barras paralelas. Trabaja tríceps y pecho.', 'fuerza', 'intermedio', ARRAY['tríceps', 'pecho', 'hombros'], 45),
('Plancha (Plank)', 'Mantén posición de flexión apoyado en antebrazos. Core estático.', 'fuerza', 'principiante', ARRAY['core', 'abdominales'], 60),
('Sentadilla con peso corporal', 'Sentadilla profunda sin carga externa. Piernas y glúteos.', 'fuerza', 'principiante', ARRAY['cuádriceps', 'glúteos', 'isquiotibiales'], 60),
('Burpees', 'Flexión + salto + sentadilla. Ejercicio completo de cuerpo entero y cardio.', 'cardio', 'intermedio', ARRAY['cuerpo completo'], 45),
('L-sit', 'Mantén piernas en L apoyado en paralelas o suelo. Fuerza de core y flexores de cadera.', 'fuerza', 'avanzado', ARRAY['core', 'flexores cadera', 'tríceps'], 30),
('Muscle-up', 'Transición de dominada a fondo en barra. Requiere fuerza y técnica.', 'fuerza', 'avanzado', ARRAY['espalda', 'bíceps', 'tríceps', 'hombros'], 30),
('Puente (Bridge)', 'Arqueo dorsal desde el suelo. Mejora movilidad y extensión de columna.', 'movilidad', 'principiante', ARRAY['espalda', 'cuádriceps'], 60),
('Pino contra la pared (Handstand)', 'Vertical contra la pared. Fuerza de hombros y control.', 'fuerza', 'avanzado', ARRAY['hombros', 'core'], 45);
