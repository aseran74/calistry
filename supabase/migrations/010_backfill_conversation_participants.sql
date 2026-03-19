-- Rellena conversation_participants para conversaciones que no tienen los 2 participantes.
-- Sin esto, los usuarios no pueden enviar mensajes (can_access_conversation exige estar en participants).

INSERT INTO public.conversation_participants (conversation_id, user_id, participant_role)
SELECT c.id, c.teacher_user_id, 'teacher'
FROM public.conversations c
WHERE NOT EXISTS (
  SELECT 1 FROM public.conversation_participants cp
  WHERE cp.conversation_id = c.id AND cp.user_id = c.teacher_user_id
)
ON CONFLICT (conversation_id, user_id) DO NOTHING;

INSERT INTO public.conversation_participants (conversation_id, user_id, participant_role)
SELECT c.id, c.student_user_id, 'student'
FROM public.conversations c
WHERE NOT EXISTS (
  SELECT 1 FROM public.conversation_participants cp
  WHERE cp.conversation_id = c.id AND cp.user_id = c.student_user_id
)
ON CONFLICT (conversation_id, user_id) DO NOTHING;
