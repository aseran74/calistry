-- Teacher social likes & follows (independent of teacher_student_links)

CREATE TABLE IF NOT EXISTS public.teacher_likes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  teacher_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE (user_id, teacher_user_id),
  CHECK (user_id <> teacher_user_id)
);

CREATE TABLE IF NOT EXISTS public.teacher_follows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  teacher_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE (user_id, teacher_user_id),
  CHECK (user_id <> teacher_user_id)
);

CREATE INDEX IF NOT EXISTS idx_teacher_likes_teacher
  ON public.teacher_likes (teacher_user_id);
CREATE INDEX IF NOT EXISTS idx_teacher_likes_user
  ON public.teacher_likes (user_id);
CREATE INDEX IF NOT EXISTS idx_teacher_follows_teacher
  ON public.teacher_follows (teacher_user_id);
CREATE INDEX IF NOT EXISTS idx_teacher_follows_user
  ON public.teacher_follows (user_id);

ALTER TABLE public.teacher_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_follows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS teacher_likes_select ON public.teacher_likes;
CREATE POLICY teacher_likes_select
  ON public.teacher_likes FOR SELECT
  USING (true);

DROP POLICY IF EXISTS teacher_likes_insert_student ON public.teacher_likes;
CREATE POLICY teacher_likes_insert_student
  ON public.teacher_likes FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND current_app_role() = 'user'
    AND user_id <> teacher_user_id
    AND public.is_teacher_user(teacher_user_id)
  );

DROP POLICY IF EXISTS teacher_likes_delete_own ON public.teacher_likes;
CREATE POLICY teacher_likes_delete_own
  ON public.teacher_likes FOR DELETE
  USING (user_id = auth.uid() AND current_app_role() = 'user');

DROP POLICY IF EXISTS teacher_likes_admin_all ON public.teacher_likes;
CREATE POLICY teacher_likes_admin_all
  ON public.teacher_likes FOR ALL
  USING (current_app_role() = ANY (ARRAY['admin'::text, 'moderator'::text]))
  WITH CHECK (current_app_role() = ANY (ARRAY['admin'::text, 'moderator'::text]));

DROP POLICY IF EXISTS teacher_follows_select ON public.teacher_follows;
CREATE POLICY teacher_follows_select
  ON public.teacher_follows FOR SELECT
  USING (true);

DROP POLICY IF EXISTS teacher_follows_insert_student ON public.teacher_follows;
CREATE POLICY teacher_follows_insert_student
  ON public.teacher_follows FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND current_app_role() = 'user'
    AND user_id <> teacher_user_id
    AND public.is_teacher_user(teacher_user_id)
  );

DROP POLICY IF EXISTS teacher_follows_delete_own ON public.teacher_follows;
CREATE POLICY teacher_follows_delete_own
  ON public.teacher_follows FOR DELETE
  USING (user_id = auth.uid() AND current_app_role() = 'user');

DROP POLICY IF EXISTS teacher_follows_admin_all ON public.teacher_follows;
CREATE POLICY teacher_follows_admin_all
  ON public.teacher_follows FOR ALL
  USING (current_app_role() = ANY (ARRAY['admin'::text, 'moderator'::text]))
  WITH CHECK (current_app_role() = ANY (ARRAY['admin'::text, 'moderator'::text]));

CREATE OR REPLACE FUNCTION public.get_top_teachers(p_limit integer DEFAULT 10)
RETURNS TABLE (
  teacher_user_id uuid,
  display_name text,
  specialty text,
  bio text,
  followers_count bigint,
  likes_count bigint,
  liked_by_me boolean,
  followed_by_me boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  WITH ranked AS (
    SELECT
      ta.user_id,
      ta.display_name,
      ta.specialty,
      ta.bio,
      COALESCE(f.cnt, 0)::bigint AS followers_count,
      COALESCE(l.cnt, 0)::bigint AS likes_count
    FROM public.teacher_applications ta
    LEFT JOIN (
      SELECT tf.teacher_user_id, count(*)::bigint AS cnt
      FROM public.teacher_follows tf
      GROUP BY tf.teacher_user_id
    ) f ON f.teacher_user_id = ta.user_id
    LEFT JOIN (
      SELECT tl.teacher_user_id, count(*)::bigint AS cnt
      FROM public.teacher_likes tl
      GROUP BY tl.teacher_user_id
    ) l ON l.teacher_user_id = ta.user_id
    WHERE ta.status = 'approved'
  )
  SELECT
    r.user_id AS teacher_user_id,
    r.display_name,
    r.specialty,
    r.bio,
    r.followers_count,
    r.likes_count,
    EXISTS (
      SELECT 1
      FROM public.teacher_likes tl
      WHERE tl.teacher_user_id = r.user_id
        AND tl.user_id = auth.uid()
    ) AS liked_by_me,
    EXISTS (
      SELECT 1
      FROM public.teacher_follows tf
      WHERE tf.teacher_user_id = r.user_id
        AND tf.user_id = auth.uid()
    ) AS followed_by_me
  FROM ranked r
  ORDER BY r.followers_count DESC, r.likes_count DESC, r.display_name ASC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 10), 50));
$function$;

GRANT EXECUTE ON FUNCTION public.get_top_teachers(integer) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_teacher_social_stats(p_teacher_user_id uuid)
RETURNS TABLE (
  teacher_user_id uuid,
  followers_count bigint,
  likes_count bigint,
  liked_by_me boolean,
  followed_by_me boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT
    p_teacher_user_id AS teacher_user_id,
    (
      SELECT count(*)::bigint
      FROM public.teacher_follows tf
      WHERE tf.teacher_user_id = p_teacher_user_id
    ) AS followers_count,
    (
      SELECT count(*)::bigint
      FROM public.teacher_likes tl
      WHERE tl.teacher_user_id = p_teacher_user_id
    ) AS likes_count,
    EXISTS (
      SELECT 1
      FROM public.teacher_likes tl
      WHERE tl.teacher_user_id = p_teacher_user_id
        AND tl.user_id = auth.uid()
    ) AS liked_by_me,
    EXISTS (
      SELECT 1
      FROM public.teacher_follows tf
      WHERE tf.teacher_user_id = p_teacher_user_id
        AND tf.user_id = auth.uid()
    ) AS followed_by_me;
$function$;

GRANT EXECUTE ON FUNCTION public.get_teacher_social_stats(uuid) TO anon, authenticated;
