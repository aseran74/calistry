/**
 * GET admin-get-user?user_id=uuid
 * Detalle completo de un usuario con sus stats. Solo admin o moderator.
 */
module.exports = async function (request) {
  const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'Content-Type, Authorization', 'Content-Type': 'application/json' };
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (request.method !== 'GET') return new Response(JSON.stringify({ error: 'Método no permitido' }), { status: 405, headers: cors });

  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return new Response(JSON.stringify({ error: 'Falta Authorization Bearer' }), { status: 401, headers: cors });

  const baseUrl = new URL(request.url).origin;
  const apiKey = request.headers.get('x-insforge-ankey') || request.headers.get('apikey') || auth.slice(7);
  const headers = { 'apikey': apiKey, 'Authorization': auth, 'Accept': 'application/json' };

  const userId = new URL(request.url).searchParams.get('user_id');
  if (!userId) return new Response(JSON.stringify({ error: 'Falta user_id' }), { status: 400, headers: cors });

  try {
    const meRes = await fetch(baseUrl + '/rest/v1/users?select=id,role', { headers: { ...headers, 'Range': '0-0' } });
    if (!meRes.ok) return new Response(JSON.stringify({ error: 'No autorizado' }), { status: 401, headers: cors });
    const me = await meRes.json();
    if (!me[0] || (me[0].role !== 'admin' && me[0].role !== 'moderator')) return new Response(JSON.stringify({ error: 'Solo admin o moderator' }), { status: 403, headers: cors });

    const uRes = await fetch(baseUrl + '/rest/v1/users?id=eq.' + encodeURIComponent(userId) + '&select=*', { headers });
    if (!uRes.ok) return new Response(JSON.stringify({ error: 'Error al obtener usuario' }), { status: uRes.status, headers: cors });
    const users = await uRes.json();
    if (!users || !users[0]) return new Response(JSON.stringify({ error: 'Usuario no encontrado' }), { status: 404, headers: cors });

    const progressRes = await fetch(baseUrl + '/rest/v1/user_progress?user_id=eq.' + encodeURIComponent(userId) + '&select=id,completed_at,duration_seconds,routine_id', { headers: { ...headers, 'Range': '0-9999' } });
    const progress = await progressRes.json();
    const routinesRes = await fetch(baseUrl + '/rest/v1/routines?user_id=eq.' + encodeURIComponent(userId) + '&select=id', { headers: { ...headers, 'Range': '0-9999' } });
    const routines = await routinesRes.json();
    const totalSesiones = (progress || []).length;
    const tiempoTotal = (progress || []).reduce(function (s, p) { return s + (p.duration_seconds || 0); }, 0);

    return new Response(JSON.stringify({
      data: {
        user: users[0],
        stats: { total_sesiones: totalSesiones, tiempo_total_segundos: tiempoTotal, total_rutinas: (routines || []).length },
      },
    }), { status: 200, headers: cors });
  } catch (err) {
    return new Response(JSON.stringify({ error: 'Error interno', details: String(err) }), { status: 500, headers: cors });
  }
};
