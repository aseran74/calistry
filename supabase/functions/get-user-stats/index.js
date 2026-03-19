/**
 * GET /get-user-stats
 * Estadísticas: total sesiones, tiempo total, racha actual, racha máxima.
 * Requiere: Authorization: Bearer <jwt>
 */
module.exports = async function (request) {
  const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type, Authorization', 'Content-Type': 'application/json' };
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (request.method !== 'GET') return new Response(JSON.stringify({ error: 'Método no permitido' }), { status: 405, headers: cors });

  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return new Response(JSON.stringify({ error: 'Falta Authorization Bearer' }), { status: 401, headers: cors });

  const baseUrl = new URL(request.url).origin;
  const apiKey = request.headers.get('x-insforge-ankey') || request.headers.get('apikey') || auth.slice(7);
  const headers = { 'apikey': apiKey, 'Authorization': auth, 'Accept': 'application/json' };

  try {
    const res = await fetch(baseUrl + '/rest/v1/user_progress?select=completed_at,duration_seconds&order=completed_at.desc', { headers });
    if (!res.ok) return new Response(JSON.stringify({ error: 'Error al obtener progreso', details: await res.text() }), { status: res.status, headers: cors });
    const rows = await res.json();
    const totalSesiones = rows.length;
    const tiempoTotal = rows.reduce((s, r) => s + (r.duration_seconds || 0), 0);
    function toDateStr(d) { const x = new Date(d); return x.getFullYear() + '-' + String(x.getMonth() + 1).padStart(2, '0') + '-' + String(x.getDate()).padStart(2, '0'); }
    let rachaActual = 0;
    let rachaMaxima = 0;
    let cur = 0;
    let lastDate = null;
    const today = toDateStr(new Date());
    for (const r of rows) {
      const d = toDateStr(r.completed_at);
      if (d === lastDate) continue;
      lastDate = d;
      const diff = lastDate ? (new Date(today) - new Date(lastDate)) / (24 * 60 * 60 * 1000) : 0;
      if (cur === 0 && d !== today) break;
      if (d === today || (cur > 0 && diff === 1)) { cur++; if (d !== today) rachaActual = cur; rachaMaxima = Math.max(rachaMaxima, cur); } else if (cur > 0) break;
    }
    if (rows[0] && toDateStr(rows[0].completed_at) === today) rachaActual = cur;

    return new Response(JSON.stringify({
      data: { total_sesiones: totalSesiones, tiempo_total_segundos: tiempoTotal, racha_actual: rachaActual, racha_maxima: rachaMaxima },
    }), { status: 200, headers: cors });
  } catch (err) {
    return new Response(JSON.stringify({ error: 'Error interno', details: String(err) }), { status: 500, headers: cors });
  }
};
