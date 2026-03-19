/**
 * GET admin-list-users
 * Lista usuarios con filtros: role, is_active, search (email/username). Paginación limit/offset.
 * Solo admin o moderator.
 */
module.exports = async function (request) {
  const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'Content-Type, Authorization', 'Content-Type': 'application/json' };
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (request.method !== 'GET') return new Response(JSON.stringify({ error: 'Método no permitido' }), { status: 405, headers: cors });

  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return new Response(JSON.stringify({ error: 'Falta Authorization Bearer' }), { status: 401, headers: cors });

  const baseUrl = new URL(request.url).origin;
  const apiKey = request.headers.get('x-insforge-ankey') || request.headers.get('apikey') || auth.slice(7);
  const headers = { 'apikey': apiKey, 'Authorization': auth, 'Accept': 'application/json', 'Prefer': 'count=exact' };

  try {
    const meRes = await fetch(baseUrl + '/rest/v1/users?select=id,role', { headers: { ...headers, 'Range': '0-0' } });
    if (!meRes.ok) return new Response(JSON.stringify({ error: 'No autorizado' }), { status: 401, headers: cors });
    const me = await meRes.json();
    if (!me[0] || (me[0].role !== 'admin' && me[0].role !== 'moderator')) return new Response(JSON.stringify({ error: 'Solo admin o moderator' }), { status: 403, headers: cors });

    const url = new URL(request.url);
    const role = url.searchParams.get('role');
    const is_active = url.searchParams.get('is_active');
    const search = url.searchParams.get('search');
    const limit = Math.min(Number(url.searchParams.get('limit')) || 20, 100);
    const offset = Number(url.searchParams.get('offset')) || 0;

    let q = 'select=*&order=created_at.desc&limit=' + limit + '&offset=' + offset;
    if (role) q += '&role=eq.' + encodeURIComponent(role);
    if (is_active !== null && is_active !== undefined && is_active !== '') q += '&is_active=eq.' + (is_active === 'true' || is_active === '1');
    if (search) q += '&or=(email.ilike.*' + encodeURIComponent(search) + '*,username.ilike.*' + encodeURIComponent(search) + '*)';

    const res = await fetch(baseUrl + '/rest/v1/users?' + q, { headers });
    if (!res.ok) return new Response(JSON.stringify({ error: 'Error al listar usuarios', details: await res.text() }), { status: res.status, headers: cors });
    const data = await res.json();
    const total = res.headers.get('content-range') ? parseInt(res.headers.get('content-range').split('/')[1], 10) : data.length;
    return new Response(JSON.stringify({ data, total, limit, offset }), { status: 200, headers: cors });
  } catch (err) {
    return new Response(JSON.stringify({ error: 'Error interno', details: String(err) }), { status: 500, headers: cors });
  }
};
