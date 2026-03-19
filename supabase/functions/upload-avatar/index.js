/**
 * POST (multipart) upload-avatar
 * Cualquier usuario autenticado. Sube foto de perfil al bucket avatars (privado).
 * Campo: file o avatar. Retorna { avatar_url }.
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
    const formData = await request.formData();
    const file = formData.get('file') || formData.get('avatar');
    if (!file || !file.size) return new Response(JSON.stringify({ error: 'Falta archivo en el campo file o avatar' }), { status: 400, headers: cors });

    const type = (file.type || '').toLowerCase();
    const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
    if (!allowed.includes(type)) return new Response(JSON.stringify({ error: 'Solo imágenes: jpeg, png, webp, gif' }), { status: 400, headers: cors });
    const maxSize = 5 * 1024 * 1024;
    if (file.size > maxSize) return new Response(JSON.stringify({ error: 'Máximo 5MB' }), { status: 400, headers: cors });

    const ext = type === 'image/jpeg' ? '.jpg' : type === 'image/png' ? '.png' : type === 'image/webp' ? '.webp' : '.gif';
    const key = crypto.randomUUID() + ext;

    const uploadRes = await fetch(baseUrl + '/api/storage/buckets/avatars/objects/' + encodeURIComponent(key), {
      method: 'POST',
      headers: { ...headers, 'Content-Type': file.type || 'image/jpeg' },
      body: file,
    });
    if (!uploadRes.ok) {
      const text = await uploadRes.text();
      return new Response(JSON.stringify({ error: 'Error al subir avatar', details: text }), { status: uploadRes.status, headers: cors });
    }
    const uploadData = await uploadRes.json().catch(() => ({}));
    const avatar_url = uploadData.url || baseUrl + '/api/storage/buckets/avatars/objects/' + encodeURIComponent(key);

    return new Response(JSON.stringify({ data: { avatar_url } }), { status: 200, headers: cors });
  } catch (err) {
    return new Response(JSON.stringify({ error: 'Error interno', details: String(err) }), { status: 500, headers: cors });
  }
};
