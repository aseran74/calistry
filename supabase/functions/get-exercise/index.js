/**
 * GET /get-exercise?id=uuid
 * Detalle de un ejercicio por id. Requiere: Authorization: Bearer <jwt>
 */
module.exports = async function (request) {
  const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type, Authorization', 'Content-Type': 'application/json' };
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (request.method !== 'GET') return new Response(JSON.stringify({ error: 'Método no permitido' }), { status: 405, headers: cors });

  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return new Response(JSON.stringify({ error: 'Falta Authorization Bearer' }), { status: 401, headers: cors });

  const url = new URL(request.url);
  const id = url.searchParams.get('id');
  if (!id) return new Response(JSON.stringify({ error: 'Falta query id' }), { status: 400, headers: cors });

  const baseUrl = url.origin;
  const apiKey = request.headers.get('x-insforge-ankey') || request.headers.get('apikey') || auth.slice(7);
  try {
    const res = await fetch(baseUrl + '/rest/v1/exercises?id=eq.' + encodeURIComponent(id) + '&select=*', {
      headers: { 'apikey': apiKey, 'Authorization': auth, 'Accept': 'application/json' },
    });
    if (!res.ok) return new Response(JSON.stringify({ error: 'Error al obtener ejercicio', details: await res.text() }), { status: res.status, headers: cors });
    const data = await res.json();
    if (!data || data.length === 0) return new Response(JSON.stringify({ error: 'Ejercicio no encontrado' }), { status: 404, headers: cors });
    return new Response(JSON.stringify({ data: data[0] }), { status: 200, headers: cors });
  } catch (err) {
    return new Response(JSON.stringify({ error: 'Error interno', details: String(err) }), { status: 500, headers: cors });
  }
};
