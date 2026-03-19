/**
 * POST admin-delete-user
 * Body: { user_id }. Requiere header X-Confirm-Delete: true. Elimina usuario (y cascadas). Solo admin. Registra en admin_logs.
 */
module.exports = async function (request) {
  const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Confirm-Delete', 'Content-Type': 'application/json' };
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (request.method !== 'POST') return new Response(JSON.stringify({ error: 'Método no permitido' }), { status: 405, headers: cors });
  if (request.headers.get('X-Confirm-Delete') !== 'true') return new Response(JSON.stringify({ error: 'Requiere header X-Confirm-Delete: true' }), { status: 400, headers: cors });

  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return new Response(JSON.stringify({ error: 'Falta Authorization Bearer' }), { status: 401, headers: cors });

  const baseUrl = new URL(request.url).origin;
  const apiKey = request.headers.get('x-insforge-ankey') || request.headers.get('apikey') || auth.slice(7);
  const headers = { 'Content-Type': 'application/json', 'apikey': apiKey, 'Authorization': auth, 'Accept': 'application/json' };

  let body;
  try { body = await request.json(); } catch { return new Response(JSON.stringify({ error: 'Body JSON inválido' }), { status: 400, headers: cors }); }
  const user_id = body && body.user_id;
  if (!user_id) return new Response(JSON.stringify({ error: 'Falta user_id' }), { status: 400, headers: cors });

  try {
    const meRes = await fetch(baseUrl + '/rest/v1/users?select=id,role', { headers: { ...headers, 'Range': '0-0' } });
    if (!meRes.ok) return new Response(JSON.stringify({ error: 'No autorizado' }), { status: 401, headers: cors });
    const me = await meRes.json();
    const admin = me && me[0];
    if (!admin || admin.role !== 'admin') return new Response(JSON.stringify({ error: 'Solo admin puede eliminar usuarios' }), { status: 403, headers: cors });

    const res = await fetch(baseUrl + '/rest/v1/users?id=eq.' + encodeURIComponent(user_id), { method: 'DELETE', headers });
    if (!res.ok) return new Response(JSON.stringify({ error: 'Error al eliminar usuario', details: await res.text() }), { status: res.status, headers: cors });

    await fetch(baseUrl + '/rest/v1/admin_logs', {
      method: 'POST',
      headers: { ...headers, 'Prefer': 'return=minimal' },
      body: JSON.stringify([{ admin_id: admin.id, action: 'delete_user', target_type: 'user', target_id: user_id, details: {} }]),
    });

    return new Response(JSON.stringify({ data: { user_id, deleted: true } }), { status: 200, headers: cors });
  } catch (err) {
    return new Response(JSON.stringify({ error: 'Error interno', details: String(err) }), { status: 500, headers: cors });
  }
};
