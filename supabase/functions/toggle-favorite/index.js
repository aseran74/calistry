/**
 * POST /toggle-favorite
 * Body: { exercise_id }
 * Añade o quita favorito según si ya existe. Requiere: Authorization: Bearer <jwt>
 */
module.exports = async function (request) {
  const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type, Authorization', 'Content-Type': 'application/json' };
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (request.method !== 'POST') return new Response(JSON.stringify({ error: 'Método no permitido' }), { status: 405, headers: cors });

  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return new Response(JSON.stringify({ error: 'Falta Authorization Bearer' }), { status: 401, headers: cors });

  let body;
  try { body = await request.json(); } catch { return new Response(JSON.stringify({ error: 'Body JSON inválido' }), { status: 400, headers: cors }); }
  const exercise_id = body && body.exercise_id;
  if (!exercise_id) return new Response(JSON.stringify({ error: 'Falta exercise_id' }), { status: 400, headers: cors });

  const baseUrl = new URL(request.url).origin;
  const apiKey = request.headers.get('x-insforge-ankey') || request.headers.get('apikey') || auth.slice(7);
  const headers = { 'Content-Type': 'application/json', 'apikey': apiKey, 'Authorization': auth, 'Accept': 'application/json' };

  try {
    const listRes = await fetch(baseUrl + '/rest/v1/user_favorites?exercise_id=eq.' + encodeURIComponent(exercise_id) + '&select=id', { headers });
    if (!listRes.ok) return new Response(JSON.stringify({ error: 'Error al comprobar favoritos', details: await listRes.text() }), { status: listRes.status, headers: cors });
    const existing = await listRes.json();
    if (existing && existing.length > 0) {
      const delRes = await fetch(baseUrl + '/rest/v1/user_favorites?id=eq.' + encodeURIComponent(existing[0].id), { method: 'DELETE', headers });
      if (!delRes.ok) return new Response(JSON.stringify({ error: 'Error al quitar favorito', details: await delRes.text() }), { status: delRes.status, headers: cors });
      return new Response(JSON.stringify({ data: { exercise_id, favorito: false } }), { status: 200, headers: cors });
    }
    const insRes = await fetch(baseUrl + '/rest/v1/user_favorites', {
      method: 'POST',
      headers: { ...headers, 'Prefer': 'return=representation' },
      body: JSON.stringify([{ exercise_id }]),
    });
    if (!insRes.ok) return new Response(JSON.stringify({ error: 'Error al añadir favorito', details: await insRes.text() }), { status: insRes.status, headers: cors });
    const created = await insRes.json();
    return new Response(JSON.stringify({ data: { exercise_id, favorito: true, id: created[0] && created[0].id } }), { status: 201, headers: cors });
  } catch (err) {
    return new Response(JSON.stringify({ error: 'Error interno', details: String(err) }), { status: 500, headers: cors });
  }
};
