-- Nombre de grupo por enlace profesor-alumno (Insforge)
-- El profesor puede asignar un nombre de grupo al aceptar o después

ALTER TABLE public.teacher_student_links
  ADD COLUMN IF NOT EXISTS group_name text;

-- Permitir al profesor actualizar enlaces aprobados (p. ej. para editar group_name)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'teacher_student_links'
      AND policyname = 'teacher_student_links_update_teacher_approved'
  ) THEN
    CREATE POLICY "teacher_student_links_update_teacher_approved"
      ON public.teacher_student_links FOR UPDATE
      USING (teacher_user_id = auth.uid() AND status = 'approved')
      WITH CHECK (teacher_user_id = auth.uid() AND status = 'approved');
  END IF;
END $$;
