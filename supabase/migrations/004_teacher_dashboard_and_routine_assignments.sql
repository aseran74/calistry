-- ============================================
-- Teacher dashboard permissions and routine assignments
-- ============================================

CREATE TABLE IF NOT EXISTS public.routine_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  routine_id uuid NOT NULL REFERENCES public.routines(id) ON DELETE CASCADE,
  teacher_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  student_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'completed', 'archived')),
  notes text,
  start_date date,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (routine_id, student_user_id)
);

CREATE INDEX IF NOT EXISTS idx_routine_assignments_teacher
  ON public.routine_assignments(teacher_user_id, status, assigned_at DESC);
CREATE INDEX IF NOT EXISTS idx_routine_assignments_student
  ON public.routine_assignments(student_user_id, status, assigned_at DESC);
CREATE INDEX IF NOT EXISTS idx_routine_assignments_routine
  ON public.routine_assignments(routine_id);

ALTER TABLE public.routine_assignments ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'exercises'
      AND policyname = 'exercises_select_owner'
  ) THEN
    CREATE POLICY "exercises_select_owner"
      ON public.exercises
      FOR SELECT
      USING (owner_user_id = auth.uid());
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'exercises'
      AND policyname = 'exercises_teacher_insert'
  ) THEN
    CREATE POLICY "exercises_teacher_insert"
      ON public.exercises
      FOR INSERT
      WITH CHECK (
        current_app_role() = 'teacher'
        AND owner_user_id = auth.uid()
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'exercises'
      AND policyname = 'exercises_teacher_update_own'
  ) THEN
    CREATE POLICY "exercises_teacher_update_own"
      ON public.exercises
      FOR UPDATE
      USING (owner_user_id = auth.uid())
      WITH CHECK (owner_user_id = auth.uid());
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'exercises'
      AND policyname = 'exercises_teacher_delete_own'
  ) THEN
    CREATE POLICY "exercises_teacher_delete_own"
      ON public.exercises
      FOR DELETE
      USING (owner_user_id = auth.uid());
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'routines'
      AND policyname = 'routines_select_assigned_student'
  ) THEN
    CREATE POLICY "routines_select_assigned_student"
      ON public.routines
      FOR SELECT
      USING (
        EXISTS (
          SELECT 1
          FROM public.routine_assignments ra
          WHERE ra.routine_id = routines.id
            AND ra.student_user_id = auth.uid()
        )
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'routine_exercises'
      AND policyname = 'routine_exercises_select_assigned_student'
  ) THEN
    CREATE POLICY "routine_exercises_select_assigned_student"
      ON public.routine_exercises
      FOR SELECT
      USING (
        EXISTS (
          SELECT 1
          FROM public.routine_assignments ra
          WHERE ra.routine_id = routine_exercises.routine_id
            AND ra.student_user_id = auth.uid()
        )
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'routine_assignments'
      AND policyname = 'routine_assignments_select_related'
  ) THEN
    CREATE POLICY "routine_assignments_select_related"
      ON public.routine_assignments
      FOR SELECT
      USING (
        teacher_user_id = auth.uid()
        OR student_user_id = auth.uid()
        OR current_app_role() = ANY (ARRAY['admin', 'moderator'])
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'routine_assignments'
      AND policyname = 'routine_assignments_insert_teacher'
  ) THEN
    CREATE POLICY "routine_assignments_insert_teacher"
      ON public.routine_assignments
      FOR INSERT
      WITH CHECK (
        teacher_user_id = auth.uid()
        AND EXISTS (
          SELECT 1
          FROM public.routines r
          WHERE r.id = routine_id
            AND r.user_id = auth.uid()
        )
        AND EXISTS (
          SELECT 1
          FROM public.teacher_student_links l
          WHERE l.teacher_user_id = auth.uid()
            AND l.student_user_id = routine_assignments.student_user_id
            AND l.status = 'approved'
        )
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'routine_assignments'
      AND policyname = 'routine_assignments_update_teacher'
  ) THEN
    CREATE POLICY "routine_assignments_update_teacher"
      ON public.routine_assignments
      FOR UPDATE
      USING (teacher_user_id = auth.uid())
      WITH CHECK (teacher_user_id = auth.uid());
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'routine_assignments'
      AND policyname = 'routine_assignments_delete_teacher'
  ) THEN
    CREATE POLICY "routine_assignments_delete_teacher"
      ON public.routine_assignments
      FOR DELETE
      USING (teacher_user_id = auth.uid());
  END IF;
END $$;
