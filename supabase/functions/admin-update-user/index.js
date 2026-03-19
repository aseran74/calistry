/**
 * PATCH/PUT admin-update-user
 * Body: { user_id, role?, is_active?, email?, username?, avatar_url?, nivel? }
 * Solo admin puede cambiar role. Solo admin o moderator.
 * Registra en admin_logs.
 */
module.exports = async function (request) {
  const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Confirm-Delete', 'Content-Type': 'application/json' };
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (request.method !== 'POST' && request.method !== 'PATCH') return new Response(JSON.stringify({ error: 'Método no permitido' }), { status: 405, headers: cors });

  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return new Response(JSON.stringify({ error: 'Falta Authorization Bearer' }), { status: 401, headers: cors });

  const baseUrl = new URL(request.url).origin;
  const apiKey = request.headers.get('x-insforge-ankey') || request.headers.get('apikey') || auth.slice(7);
  const headers = { 'Content-Type': 'application/json', 'apikey': apiKey, 'Authorization': auth, 'Accept': 'application/json', 'Prefer': 'return=representation' };

  let body;
  try { body = await request.json(); } catch { return new Response(JSON.stringify({ error: 'Body JSON inválido' }), { status: 400, headers: cors }); }
  const { user_id, role, is_active, email, username, avatar_url, nivel } = body || {};
  if (!user_id) return new Response(JSON.stringify({ error: 'Falta user_id' }), { status: 400, headers: cors });

  try {
    const meRes = await fetch(baseUrl + '/rest/v1/users?select=id,role', { headers: { ...headers, 'Range': '0-0' } });
    if (!meRes.ok) return new Response(JSON.stringify({ error: 'No autorizado' }), { status: 401, headers: cors });
    const me = await meRes.json();
    const admin = me && me[0];
    if (!admin || (admin.role !== 'admin' && admin.role !== 'moderator')) return new Response(JSON.stringify({ error: 'Solo admin o moderator' }), { status: 403, headers: cors });
    if (role !== undefined && role !== null && admin.role !== 'admin') return new Response(JSON.stringify({ error: 'Solo admin puede cambiar role' }), { status: 403, headers: cors });

    const patch = {};
    if (role !== undefined) patch.role = role;
    if (is_active !== undefined) patch.is_active = !!is_active;
    if (email !== undefined) patch.email = email;
    if (username !== undefined) patch.username = username;
    if (avatar_url !== undefined) patch.avatar_url = avatar_url;
    if (nivel !== undefined) patch.nivel = nivel;
    if (Object.keys(patch).length === 0) return new Response(JSON.stringify({ error: 'Nada que actualizar' }), { status: 400, headers: cors });

    const res = await fetch(baseUrl + '/rest/v1/users?id=eq.' + encodeURIComponent(user_id), { method: 'PATCH', headers, body: JSON.stringify(patch) });
    if (!res.ok) return new Response(JSON.stringify({ error: 'Error al actualizar usuario', details: await res.text() }), { status: res.status, headers: cors });
    const updated = await res.json();

    await fetch(baseUrl + '/rest/v1/admin_logs', {
      method: 'POST',
      headers,
      body: JSON.stringify([{ admin_id: admin.id, action: 'update_user', target_type: 'user', target_id: user_id, details: { patch } }]),
    });

    return new Response(JSON.stringify({ data: (updated && updated[0]) || { id: user_id, ...patch } }), { status: 200, headers: cors });
  } catch (err) {
    return new Response(JSON.stringify({ error: 'Error interno', details: String(err) }), { status: 500, headers: cors });
  }
};
