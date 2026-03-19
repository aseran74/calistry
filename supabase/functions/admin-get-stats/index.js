/**
 * GET admin-get-stats
 * Dashboard: total usuarios, nuevos hoy/semana, sesiones hoy/semana, top 10 ejercicios, usuarios por nivel, sesiones últimos 30 días.
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
    const admin = me && me[0];
    if (!admin || (admin.role !== 'admin' && admin.role !== 'moderator')) return new Response(JSON.stringify({ error: 'Solo admin o moderator' }), { status: 403, headers: cors });

    const now = new Date();
    const today = now.toISOString().slice(0, 10);
    const weekAgo = new Date(now - 7 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
    const monthAgo = new Date(now - 30 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);

    const range = '0-0';
    const totalUsersRes = await fetch(baseUrl + '/rest/v1/users?select=id&' + range, { headers });
    const totalUsers = totalUsersRes.headers.get('content-range') ? parseInt(totalUsersRes.headers.get('content-range').split('/')[1], 10) || 0 : 0;

    const newTodayRes = await fetch(baseUrl + '/rest/v1/users?select=id&created_at=gte.' + today + 'T00:00:00Z', { headers });
    const newToday = newTodayRes.headers.get('content-range') ? parseInt(newTodayRes.headers.get('content-range').split('/')[1], 10) || 0 : 0;
    const newWeekRes = await fetch(baseUrl + '/rest/v1/users?select=id&created_at=gte.' + weekAgo + 'T00:00:00Z', { headers });
    const newWeek = newWeekRes.headers.get('content-range') ? parseInt(newWeekRes.headers.get('content-range').split('/')[1], 10) || 0 : 0;

    const sessionsTodayRes = await fetch(baseUrl + '/rest/v1/user_progress?select=id&completed_at=gte.' + today + 'T00:00:00Z', { headers });
    const sessionsToday = sessionsTodayRes.headers.get('content-range') ? parseInt(sessionsTodayRes.headers.get('content-range').split('/')[1], 10) || 0 : 0;
    const sessionsWeekRes = await fetch(baseUrl + '/rest/v1/user_progress?select=id&completed_at=gte.' + weekAgo + 'T00:00:00Z', { headers });
    const sessionsWeek = sessionsWeekRes.headers.get('content-range') ? parseInt(sessionsWeekRes.headers.get('content-range').split('/')[1], 10) || 0 : 0;
    const sessions30Res = await fetch(baseUrl + '/rest/v1/user_progress?select=id&completed_at=gte.' + monthAgo + 'T00:00:00Z', { headers });
    const sessionsLast30 = sessions30Res.headers.get('content-range') ? parseInt(sessions30Res.headers.get('content-range').split('/')[1], 10) || 0 : 0;

    const reRes = await fetch(baseUrl + '/rest/v1/routine_exercises?select=exercise_id', { headers: { ...headers, 'Range': '0-9999' } });
    const reRows = await reRes.json();
    const countByEx = {};
    (reRows || []).forEach(function (r) { countByEx[r.exercise_id] = (countByEx[r.exercise_id] || 0) + 1; });
    const top10 = Object.entries(countByEx).sort(function (a, b) { return b[1] - a[1]; }).slice(0, 10).map(function (e) { return { exercise_id: e[0], count: e[1] }; });

    const usersRes = await fetch(baseUrl + '/rest/v1/users?select=nivel', { headers: { ...headers, 'Range': '0-9999' } });
    const usersRows = await usersRes.json();
    const byLevel = {};
    (usersRows || []).forEach(function (u) { const n = u.nivel || 'principiante'; byLevel[n] = (byLevel[n] || 0) + 1; });

    return new Response(JSON.stringify({
      data: {
        total_usuarios: totalUsers,
        nuevos_hoy: newToday,
        nuevos_semana: newWeek,
        sesiones_hoy: sessionsToday,
        sesiones_semana: sessionsWeek,
        sesiones_ultimos_30_dias: sessionsLast30,
        top_10_ejercicios: top10,
        usuarios_por_nivel: byLevel,
      },
    }), { status: 200, headers: cors });
  } catch (err) {
    return new Response(JSON.stringify({ error: 'Error interno', details: String(err) }), { status: 500, headers: cors });
  }
};
