-- ============================================
-- Ownership de ejercicios y propuestas pendientes
-- ============================================

CREATE OR REPLACE FUNCTION public.current_app_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select coalesce((select u.role::text from public.users u where u.id = auth.uid()), 'user');
$function$;

ALTER TABLE public.exercises
  ADD COLUMN IF NOT EXISTS owner_user_id uuid REFERENCES public.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_exercises_owner_user_id
  ON public.exercises(owner_user_id);

CREATE TABLE IF NOT EXISTS public.exercise_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  proposed_by_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  category category_enum NOT NULL,
  difficulty difficulty_enum NOT NULL,
  muscle_groups text[] DEFAULT '{}',
  video_url text,
  gif_url text,
  thumbnail_url text,
  duration_seconds integer,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  review_notes text,
  reviewed_by_user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  published_exercise_id uuid REFERENCES public.exercises(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_exercise_submissions_proposed_by
  ON public.exercise_submissions(proposed_by_user_id);

CREATE INDEX IF NOT EXISTS idx_exercise_submissions_status
  ON public.exercise_submissions(status);

CREATE INDEX IF NOT EXISTS idx_exercise_submissions_reviewed_by
  ON public.exercise_submissions(reviewed_by_user_id);

ALTER TABLE public.exercise_submissions ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'exercise_submissions'
      AND policyname = 'exercise_submissions_select_own'
  ) THEN
    CREATE POLICY "exercise_submissions_select_own"
      ON public.exercise_submissions
      FOR SELECT
      USING (proposed_by_user_id = auth.uid());
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'exercise_submissions'
      AND policyname = 'exercise_submissions_insert_own'
  ) THEN
    CREATE POLICY "exercise_submissions_insert_own"
      ON public.exercise_submissions
      FOR INSERT
      WITH CHECK (proposed_by_user_id = auth.uid());
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'exercise_submissions'
      AND policyname = 'exercise_submissions_update_own_pending'
  ) THEN
    CREATE POLICY "exercise_submissions_update_own_pending"
      ON public.exercise_submissions
      FOR UPDATE
      USING (proposed_by_user_id = auth.uid() AND status = 'pending')
      WITH CHECK (proposed_by_user_id = auth.uid() AND status = 'pending');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'exercise_submissions'
      AND policyname = 'exercise_submissions_delete_own_pending'
  ) THEN
    CREATE POLICY "exercise_submissions_delete_own_pending"
      ON public.exercise_submissions
      FOR DELETE
      USING (proposed_by_user_id = auth.uid() AND status = 'pending');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'exercise_submissions'
      AND policyname = 'exercise_submissions_admin_all'
  ) THEN
    CREATE POLICY "exercise_submissions_admin_all"
      ON public.exercise_submissions
      FOR ALL
      USING (current_app_role() = ANY (ARRAY['admin'::text, 'moderator'::text]))
      WITH CHECK (current_app_role() = ANY (ARRAY['admin'::text, 'moderator'::text]));
  END IF;
END $$;

UPDATE public.exercises
SET owner_user_id = admin_user.id
FROM (
  SELECT id
  FROM public.users
  WHERE lower(email) = lower('admin@test.com')
  LIMIT 1
) AS admin_user
WHERE public.exercises.owner_user_id IS NULL;
