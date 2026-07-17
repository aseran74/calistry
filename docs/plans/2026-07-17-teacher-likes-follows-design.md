# Top 10 profesores: likes y follows sociales

## Resumen
- Likes y follows sociales independientes del flujo alumno (`teacher_student_links`).
- Solo alumnos (`role = user`) pueden like/follow.
- Top 10 ordenado por seguidores sociales; desempate por likes y nombre.
- Visible en Home y pantalla Profesores; acciones también en perfil.

## Datos
- `teacher_likes(user_id, teacher_user_id)` unique
- `teacher_follows(user_id, teacher_user_id)` unique
- RLS: SELECT abierto (conteos); INSERT/DELETE solo propio alumno
- RPC/helper o agregación cliente para ranking + `liked_by_me` / `followed_by_me`

## UI
- Bloque Top 10 (ranking, contadores, Like, Seguir)
- Perfil: Like / Seguir social + “Solicitar ser alumno” existente
