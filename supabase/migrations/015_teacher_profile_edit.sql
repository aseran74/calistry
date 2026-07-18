-- Permitir al profesor editar su perfil aprobado (nombre, especialidad, bio, redes)

ALTER TABLE public.teacher_applications
  ADD COLUMN IF NOT EXISTS instagram_url text,
  ADD COLUMN IF NOT EXISTS tiktok_url text,
  ADD COLUMN IF NOT EXISTS facebook_url text;

DROP POLICY IF EXISTS teacher_applications_update_own_approved ON public.teacher_applications;
CREATE POLICY teacher_applications_update_own_approved
  ON public.teacher_applications FOR UPDATE
  USING (
    user_id = auth.uid()
    AND status = 'approved'
    AND current_app_role() = 'teacher'
  )
  WITH CHECK (
    user_id = auth.uid()
    AND status = 'approved'
    AND current_app_role() = 'teacher'
  );
