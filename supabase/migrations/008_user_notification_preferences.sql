-- Preferencias de notificaciones del usuario (Insforge / Supabase)
-- Usado por la pantalla Notificaciones para respuestas a mensajes y rutinas asignadas

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS notify_message_reply boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_routine_proposed boolean DEFAULT true;
