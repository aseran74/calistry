/**
 * POST /save-progress
 * Body: { routine_id, duration_seconds?, notes? }
 * Guarda sesión completada en user_progress. user_id vía RLS/token.
 */
module.exports = async function (request) {
  const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type, Authorization', 'Content-Type': 'application/json' };
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (request.method !== 'POST') return new Response(JSON.stringify({ error: 'Método no permitido' }), { status: 405, headers: cors });

  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return new Response(JSON.stringify({ error: 'Falta Authorization Bearer' }), { status: 401, headers: cors });

  let body;
  try { body = await request.json(); } catch { return new Response(JSON.stringify({ error: 'Body JSON inválido' }), { status: 400, headers: cors }); }
  const { routine_id, duration_seconds, notes } = body || {};
  if (!routine_id) return new Response(JSON.stringify({ error: 'Falta routine_id' }), { status: 400, headers: cors });

  const baseUrl = new URL(request.url).origin;
  const apiKey = request.headers.get('x-insforge-ankey') || request.headers.get('apikey') || auth.slice(7);
  const headers = { 'Content-Type': 'application/json', 'apikey': apiKey, 'Authorization': auth, 'Accept': 'application/json', 'Prefer': 'return=representation' };

  try {
    const res = await fetch(baseUrl + '/rest/v1/user_progress', {
      method: 'POST',
      headers,
      body: JSON.stringify([{ routine_id, duration_seconds: duration_seconds ?? null, notes: notes || null }]),
    });
    if (!res.ok) return new Response(JSON.stringify({ error: 'Error al guardar progreso', details: await res.text() }), { status: res.status, headers: cors });
    const data = await res.json();
    return new Response(JSON.stringify({ data: data[0] || { routine_id, duration_seconds, notes } }), { status: 201, headers: cors });
  } catch (err) {
    return new Response(JSON.stringify({ error: 'Error interno', details: String(err) }), { status: 500, headers: cors });
  }
};
