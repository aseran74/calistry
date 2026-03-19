-- Enlaces a redes sociales del profesor (Instagram, TikTok, Facebook)

ALTER TABLE public.teacher_applications
  ADD COLUMN IF NOT EXISTS instagram_url text,
  ADD COLUMN IF NOT EXISTS tiktok_url text,
  ADD COLUMN IF NOT EXISTS facebook_url text;

-- Permitir al profesor actualizar su perfil aprobado (p. ej. redes sociales)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'teacher_applications'
      AND policyname = 'teacher_applications_update_own_approved'
  ) THEN
    CREATE POLICY "teacher_applications_update_own_approved"
      ON public.teacher_applications FOR UPDATE
      USING (user_id = auth.uid() AND status = 'approved')
      WITH CHECK (user_id = auth.uid());
  END IF;
END $$;
