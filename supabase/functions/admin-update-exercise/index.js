/**
 * PATCH admin-update-exercise
 * Body: { exercise_id, name?, description?, category?, difficulty?, muscle_groups?, video_url?, gif_url?, thumbnail_url?, duration_seconds?, is_active? }
 * Solo admin o moderator. Registra en admin_logs.
 */
module.exports = async function (request) {
  const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'Content-Type, Authorization', 'Content-Type': 'application/json' };
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (request.method !== 'POST' && request.method !== 'PATCH') return new Response(JSON.stringify({ error: 'Método no permitido' }), { status: 405, headers: cors });

  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return new Response(JSON.stringify({ error: 'Falta Authorization Bearer' }), { status: 401, headers: cors });

  const baseUrl = new URL(request.url).origin;
  const apiKey = request.headers.get('x-insforge-ankey') || request.headers.get('apikey') || auth.slice(7);
  const headers = { 'Content-Type': 'application/json', 'apikey': apiKey, 'Authorization': auth, 'Accept': 'application/json', 'Prefer': 'return=representation' };

  let body;
  try { body = await request.json(); } catch { return new Response(JSON.stringify({ error: 'Body JSON inválido' }), { status: 400, headers: cors }); }
  const { exercise_id, name, description, category, difficulty, muscle_groups, video_url, gif_url, thumbnail_url, duration_seconds, is_active } = body || {};
  if (!exercise_id) return new Response(JSON.stringify({ error: 'Falta exercise_id' }), { status: 400, headers: cors });

  const patch = {};
  if (name !== undefined) patch.name = name;
  if (description !== undefined) patch.description = description;
  if (category !== undefined) patch.category = category;
  if (difficulty !== undefined) patch.difficulty = difficulty;
  if (muscle_groups !== undefined) patch.muscle_groups = Array.isArray(muscle_groups) ? muscle_groups : [];
  if (video_url !== undefined) patch.video_url = video_url;
  if (gif_url !== undefined) patch.gif_url = gif_url;
  if (thumbnail_url !== undefined) patch.thumbnail_url = thumbnail_url;
  if (duration_seconds !== undefined) patch.duration_seconds = duration_seconds;
  if (is_active !== undefined) patch.is_active = is_active;
  if (Object.keys(patch).length === 0) return new Response(JSON.stringify({ error: 'Nada que actualizar' }), { status: 400, headers: cors });

  try {
    const meRes = await fetch(baseUrl + '/rest/v1/users?select=id,role', { headers: { ...headers, 'Range': '0-0' } });
    if (!meRes.ok) return new Response(JSON.stringify({ error: 'No autorizado' }), { status: 401, headers: cors });
    const me = await meRes.json();
    const admin = me && me[0];
    if (!admin || (admin.role !== 'admin' && admin.role !== 'moderator')) return new Response(JSON.stringify({ error: 'Solo admin o moderator' }), { status: 403, headers: cors });

    const res = await fetch(baseUrl + '/rest/v1/exercises?id=eq.' + encodeURIComponent(exercise_id), { method: 'PATCH', headers, body: JSON.stringify(patch) });
    if (!res.ok) return new Response(JSON.stringify({ error: 'Error al actualizar ejercicio', details: await res.text() }), { status: res.status, headers: cors });
    const updated = await res.json();

    await fetch(baseUrl + '/rest/v1/admin_logs', { method: 'POST', headers, body: JSON.stringify([{ admin_id: admin.id, action: 'update_exercise', target_type: 'exercise', target_id: exercise_id, details: { patch } }]) });

    return new Response(JSON.stringify({ data: (updated && updated[0]) || { id: exercise_id, ...patch } }), { status: 200, headers: cors });
  } catch (err) {
    return new Response(JSON.stringify({ error: 'Error interno', details: String(err) }), { status: 500, headers: cors });
  }
};
