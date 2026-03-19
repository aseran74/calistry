/**
 * GET /get-exercises
 * Lista ejercicios con filtros: category, difficulty, muscle_group, search. Paginación limit/offset.
 * Requiere: Authorization: Bearer <jwt>
 */
module.exports = async function (request) {
  const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type, Authorization', 'Content-Type': 'application/json' };
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (request.method !== 'GET') return new Response(JSON.stringify({ error: 'Método no permitido' }), { status: 405, headers: cors });

  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return new Response(JSON.stringify({ error: 'Falta Authorization Bearer' }), { status: 401, headers: cors });

  const url = new URL(request.url);
  const category = url.searchParams.get('category');
  const difficulty = url.searchParams.get('difficulty');
  const muscle_group = url.searchParams.get('muscle_group');
  const search = url.searchParams.get('search');
  const limit = Math.min(Number(url.searchParams.get('limit')) || 20, 100);
  const offset = Number(url.searchParams.get('offset')) || 0;

  const baseUrl = url.origin;
  const apiKey = request.headers.get('x-insforge-ankey') || request.headers.get('apikey') || auth.slice(7);
  const params = new URLSearchParams({ select: '*', is_active: 'eq.true', order: 'name.asc', limit: String(limit), offset: String(offset) });
  if (category) params.set('category', 'eq.' + category);
  if (difficulty) params.set('difficulty', 'eq.' + difficulty);
  if (muscle_group) params.set('muscle_groups', 'cs.{"' + muscle_group + '"}');
  if (search) params.set('or', '(name.ilike.*' + search + '*,description.ilike.*' + search + '*)');

  try {
    const res = await fetch(baseUrl + '/rest/v1/exercises?' + params.toString(), {
      headers: { 'apikey': apiKey, 'Authorization': auth, 'Accept': 'application/json' },
    });
    if (!res.ok) return new Response(JSON.stringify({ error: 'Error al listar ejercicios', details: await res.text() }), { status: res.status, headers: cors });
    const data = await res.json();
    return new Response(JSON.stringify({ data, limit, offset }), { status: 200, headers: cors });
  } catch (err) {
    return new Response(JSON.stringify({ error: 'Error interno', details: String(err) }), { status: 500, headers: cors });
  }
};
