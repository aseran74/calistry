/**
 * POST (multipart) upload-exercise-media
 * Solo admin o moderator. Acepta video (mp4/webm max 100MB) o gif (max 15MB).
 * Sube a bucket exercises-media con nombre uuid+ext. Retorna { video_url, gif_url, thumbnail_url }.
 */
module.exports = async function (request) {
  const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type, Authorization', 'Content-Type': 'application/json' };
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (request.method !== 'POST') return new Response(JSON.stringify({ error: 'Método no permitido' }), { status: 405, headers: cors });

  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return new Response(JSON.stringify({ error: 'Falta Authorization Bearer' }), { status: 401, headers: cors });

  const baseUrl = new URL(request.url).origin;
  const apiKey = request.headers.get('x-insforge-ankey') || request.headers.get('apikey') || auth.slice(7);
  const headers = { apikey: apiKey, Authorization: auth, Accept: 'application/json' };

  try {
    const meRes = await fetch(baseUrl + '/rest/v1/users?select=role', { headers });
    if (!meRes.ok) return new Response(JSON.stringify({ error: 'No autorizado' }), { status: 401, headers: cors });
    const me = await meRes.json();
    const role = me && me[0] && me[0].role;
    if (role !== 'admin' && role !== 'moderator') return new Response(JSON.stringify({ error: 'Solo admin o moderator' }), { status: 403, headers: cors });

    const formData = await request.formData();
    const file = formData.get('file') || formData.get('video') || formData.get('gif');
    if (!file || !file.size) return new Response(JSON.stringify({ error: 'Falta archivo en el campo file, video o gif' }), { status: 400, headers: cors });

    const type = (file.type || '').toLowerCase();
    const isVideo = type === 'video/mp4' || type === 'video/webm';
    const isGif = type === 'image/gif';
    if (!isVideo && !isGif) return new Response(JSON.stringify({ error: 'Tipo no permitido. Use video mp4/webm o gif' }), { status: 400, headers: cors });

    const maxVideo = 100 * 1024 * 1024;
    const maxGif = 15 * 1024 * 1024;
    if (isVideo && file.size > maxVideo) return new Response(JSON.stringify({ error: 'Video máximo 100MB' }), { status: 400, headers: cors });
    if (isGif && file.size > maxGif) return new Response(JSON.stringify({ error: 'Gif máximo 15MB' }), { status: 400, headers: cors });

    const ext = isVideo ? (type === 'video/webm' ? '.webm' : '.mp4') : '.gif';
    const key = crypto.randomUUID() + ext;

    const uploadRes = await fetch(baseUrl + '/api/storage/buckets/exercises-media/objects/' + encodeURIComponent(key), {
      method: 'POST',
      headers: { ...headers, 'Content-Type': file.type || (isVideo ? 'video/mp4' : 'image/gif') },
      body: file,
    });
    if (!uploadRes.ok) {
      const text = await uploadRes.text();
      return new Response(JSON.stringify({ error: 'Error al subir archivo', details: text }), { status: uploadRes.status, headers: cors });
    }
    const uploadData = await uploadRes.json().catch(() => ({}));
    const url = uploadData.url || baseUrl + '/api/storage/buckets/exercises-media/objects/' + encodeURIComponent(key);

    const out = { video_url: null, gif_url: null, thumbnail_url: null };
    if (isVideo) out.video_url = url;
    else if (isGif) out.gif_url = url;

    return new Response(JSON.stringify({ data: out }), { status: 200, headers: cors });
  } catch (err) {
    return new Response(JSON.stringify({ error: 'Error interno', details: String(err) }), { status: 500, headers: cors });
  }
};
