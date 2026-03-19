/**
 * POST /create-routine
 * Body: { name, description?, level?, is_public?, exercises: [{ exercise_id, order_index, sets?, reps?, rest_seconds? }] }
 * Requiere: Authorization: Bearer <jwt> (user_id se obtiene del token/RLS)
 */
module.exports = async function (request) {
  const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type, Authorization', 'Content-Type': 'application/json' };
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (request.method !== 'POST') return new Response(JSON.stringify({ error: 'Método no permitido' }), { status: 405, headers: cors });

  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return new Response(JSON.stringify({ error: 'Falta Authorization Bearer' }), { status: 401, headers: cors });

  let body;
  try { body = await request.json(); } catch { return new Response(JSON.stringify({ error: 'Body JSON inválido' }), { status: 400, headers: cors }); }
  const { name, description, level, is_public, exercises } = body;
  if (!name || !Array.isArray(exercises)) return new Response(JSON.stringify({ error: 'Faltan name o exercises (array)' }), { status: 400, headers: cors });

  const baseUrl = new URL(request.url).origin;
  const apiKey = request.headers.get('x-insforge-ankey') || request.headers.get('apikey') || auth.slice(7);
  const headers = { 'Content-Type': 'application/json', 'apikey': apiKey, 'Authorization': auth, 'Accept': 'application/json', 'Prefer': 'return=representation' };

  try {
    const meRes = await fetch(baseUrl + '/rest/v1/users?select=id', { headers });
    if (!meRes.ok) return new Response(JSON.stringify({ error: 'No se pudo obtener usuario' }), { status: 401, headers: cors });
    const me = await meRes.json();
    const user_id = me && me[0] && me[0].id;
    if (!user_id) return new Response(JSON.stringify({ error: 'Usuario no encontrado' }), { status: 401, headers: cors });

    const routineRes = await fetch(baseUrl + '/rest/v1/routines', {
      method: 'POST',
      headers,
      body: JSON.stringify([{ user_id, name, description: description || null, level: level || 'principiante', is_public: !!is_public }]),
    });
    if (!routineRes.ok) return new Response(JSON.stringify({ error: 'Error al crear rutina', details: await routineRes.text() }), { status: routineRes.status, headers: cors });
    const [routine] = await routineRes.json();
    if (!routine || !routine.id) return new Response(JSON.stringify({ error: 'Rutina creada pero sin id' }), { status: 502, headers: cors });

    const rows = exercises.map((e, i) => ({
      routine_id: routine.id,
      exercise_id: e.exercise_id,
      order_index: e.order_index != null ? e.order_index : i,
      sets: e.sets ?? null,
      reps: e.reps ?? null,
      rest_seconds: e.rest_seconds ?? null,
    }));
    const exRes = await fetch(baseUrl + '/rest/v1/routine_exercises', { method: 'POST', headers, body: JSON.stringify(rows) });
    if (!exRes.ok) return new Response(JSON.stringify({ error: 'Rutina creada pero error al añadir ejercicios', details: await exRes.text() }), { status: 502, headers: cors });

    return new Response(JSON.stringify({ data: { ...routine, exercises: rows } }), { status: 201, headers: cors });
  } catch (err) {
    return new Response(JSON.stringify({ error: 'Error interno', details: String(err) }), { status: 500, headers: cors });
  }
};
