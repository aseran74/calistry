-- ============================================
-- Live classes: enlaces + audiencia (grupo o alumno)
-- ============================================

-- Nuevas columnas para clases programadas con enlace
ALTER TABLE public.live_classes
  ADD COLUMN IF NOT EXISTS platform text,
  ADD COLUMN IF NOT EXISTS meeting_url text,
  ADD COLUMN IF NOT EXISTS scheduled_at timestamptz,
  ADD COLUMN IF NOT EXISTS audience_type text,
  ADD COLUMN IF NOT EXISTS group_id uuid REFERENCES public.teacher_groups(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS student_user_id uuid REFERENCES public.users(id) ON DELETE SET NULL;

-- Defaults/validaciones
ALTER TABLE public.live_classes
  ALTER COLUMN status SET DEFAULT 'scheduled';

DO $$
BEGIN
  -- platform
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'live_classes_platform_check'
  ) THEN
    ALTER TABLE public.live_classes
      ADD CONSTRAINT live_classes_platform_check
      CHECK (platform IN ('zoom', 'google_meet', 'instagram_live', 'tiktok_live'));
  END IF;

  -- audience_type
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'live_classes_audience_type_check'
  ) THEN
    ALTER TABLE public.live_classes
      ADD CONSTRAINT live_classes_audience_type_check
      CHECK (audience_type IN ('group', 'student'));
  END IF;

  -- exactly one target based on audience_type
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'live_classes_audience_target_check'
  ) THEN
    ALTER TABLE public.live_classes
      ADD CONSTRAINT live_classes_audience_target_check
      CHECK (
        (audience_type = 'group' AND group_id IS NOT NULL AND student_user_id IS NULL)
        OR
        (audience_type = 'student' AND student_user_id IS NOT NULL AND group_id IS NULL)
        OR
        -- filas antiguas (antes de esta migración): permitimos todo NULL
        (audience_type IS NULL AND group_id IS NULL AND student_user_id IS NULL)
      );
  END IF;
END $$;

-- Índices para filtrar por audiencia/agenda
CREATE INDEX IF NOT EXISTS idx_live_classes_scheduled
  ON public.live_classes(teacher_user_id, scheduled_at DESC);
CREATE INDEX IF NOT EXISTS idx_live_classes_group
  ON public.live_classes(group_id, scheduled_at DESC);
CREATE INDEX IF NOT EXISTS idx_live_classes_student
  ON public.live_classes(student_user_id, scheduled_at DESC);

-- Reemplaza la función de acceso para respetar audiencia
CREATE OR REPLACE FUNCTION public.can_access_live_class(target_live_class_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select exists(
    select 1
    from public.live_classes lc
    where lc.id = target_live_class_id
      and (
        -- el profesor siempre
        lc.teacher_user_id = auth.uid()
        -- alumno asignado directo (y aprobado)
        or (
          lc.audience_type = 'student'
          and lc.student_user_id = auth.uid()
          and exists (
            select 1
            from public.teacher_student_links l
            where l.teacher_user_id = lc.teacher_user_id
              and l.student_user_id = auth.uid()
              and l.status = 'approved'
          )
        )
        -- alumno miembro del grupo asignado
        or (
          lc.audience_type = 'group'
          and exists (
            select 1
            from public.teacher_group_members m
            join public.teacher_groups g on g.id = m.group_id
            where m.group_id = lc.group_id
              and m.student_user_id = auth.uid()
              and g.teacher_user_id = lc.teacher_user_id
          )
        )
      )
  );
$function$;

