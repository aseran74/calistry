-- Planning semanal/mensual: rutinas asignadas a día de la semana y hora
-- day_of_week 1 = lunes, 7 = domingo

CREATE TABLE IF NOT EXISTS public.planning_slots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  day_of_week smallint NOT NULL CHECK (day_of_week >= 1 AND day_of_week <= 7),
  hour smallint NOT NULL CHECK (hour >= 0 AND hour <= 23),
  minute smallint NOT NULL DEFAULT 0 CHECK (minute >= 0 AND minute <= 59),
  routine_id uuid NOT NULL REFERENCES public.routines(id) ON DELETE CASCADE,
  routine_name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_planning_slots_user_id
  ON public.planning_slots(user_id);

CREATE INDEX IF NOT EXISTS idx_planning_slots_user_day_hour
  ON public.planning_slots(user_id, day_of_week, hour, minute);

ALTER TABLE public.planning_slots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "planning_slots_select_own" ON public.planning_slots;
CREATE POLICY "planning_slots_select_own"
  ON public.planning_slots FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "planning_slots_insert_own" ON public.planning_slots;
CREATE POLICY "planning_slots_insert_own"
  ON public.planning_slots FOR INSERT
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "planning_slots_delete_own" ON public.planning_slots;
CREATE POLICY "planning_slots_delete_own"
  ON public.planning_slots FOR DELETE
  USING (user_id = auth.uid());
