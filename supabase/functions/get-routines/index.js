/**
 * GET /get-routines
 * Rutinas públicas + las del usuario autenticado (RLS). Requiere: Authorization: Bearer <jwt>
 */
module.exports = async function (request) {
  const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type, Authorization', 'Content-Type': 'application/json' };
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (request.method !== 'GET') return new Response(JSON.stringify({ error: 'Método no permitido' }), { status: 405, headers: cors });

  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return new Response(JSON.stringify({ error: 'Falta Authorization Bearer' }), { status: 401, headers: cors });

  const url = new URL(request.url);
  const limit = Math.min(Number(url.searchParams.get('limit')) || 50, 100);
  const offset = Number(url.searchParams.get('offset')) || 0;

  const baseUrl = url.origin;
  const apiKey = request.headers.get('x-insforge-ankey') || request.headers.get('apikey') || auth.slice(7);
  const params = 'select=*&order=created_at.desc&limit=' + limit + '&offset=' + offset;
  try {
    const res = await fetch(baseUrl + '/rest/v1/routines?' + params, {
      headers: { 'apikey': apiKey, 'Authorization': auth, 'Accept': 'application/json' },
    });
    if (!res.ok) return new Response(JSON.stringify({ error: 'Error al listar rutinas', details: await res.text() }), { status: res.status, headers: cors });
    const data = await res.json();
    return new Response(JSON.stringify({ data, limit, offset }), { status: 200, headers: cors });
  } catch (err) {
    return new Response(JSON.stringify({ error: 'Error interno', details: String(err) }), { status: 500, headers: cors });
  }
};
