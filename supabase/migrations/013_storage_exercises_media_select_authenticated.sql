-- ============================================
-- Storage policies: exercises-media select
-- Motivo: el admin_web recibe 403 al listar
--   /api/storage/buckets/exercises-media/objects
-- ============================================

-- Asegura RLS en storage.objects (tabla provista por Supabase).
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Limpia políticas previas con el mismo objetivo (si existían).
DROP POLICY IF EXISTS exercises_media_select_authenticated ON storage.objects;

-- Permite leer/listar objetos del bucket solo para usuarios autenticados.
-- El admin_web trabaja con Authorization: Bearer <accessToken>, por lo que auth.uid() no es NULL.
CREATE POLICY exercises_media_select_authenticated
ON storage.objects
FOR SELECT
USING (
  bucket = 'exercises-media'
  AND auth.uid() IS NOT NULL
);

