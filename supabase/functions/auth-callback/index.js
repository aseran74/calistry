/**
 * Edge Function: auth-callback
 * Sincroniza el usuario de auth (OAuth/Email) con la tabla public.users.
 * El cliente debe llamar a esta función después de signInWithOAuth o signUp
 * pasando los datos del usuario de la sesión.
 *
 * POST body: { id, email, username?, avatar_url? }
 * Headers: Authorization: Bearer <anon_key> (o session token si el backend lo inyecta)
 * Respuesta: { success, user } o { error }
 */
module.exports = async function (request) {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Content-Type': 'application/json',
  };

  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (request.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Método no permitido. Use POST.' }),
      { status: 405, headers: corsHeaders }
    );
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return new Response(
      JSON.stringify({ error: 'Body JSON inválido' }),
      { status: 400, headers: corsHeaders }
    );
  }

  const { id, email, username, avatar_url } = body;
  if (!id || !email) {
    return new Response(
      JSON.stringify({ error: 'Faltan id o email en el body' }),
      { status: 400, headers: corsHeaders }
    );
  }

  const baseUrl = new URL(request.url).origin;
  const apiKey = request.headers.get('x-insforge-ankey') || request.headers.get('apikey') || request.headers.get('Authorization')?.replace(/^Bearer\s+/i, '') || '';

  const userRow = {
    id,
    email,
    username: username || null,
    avatar_url: avatar_url || null,
  };

  try {
    const res = await fetch(`${baseUrl}/rest/v1/users`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': apiKey || '',
        'Authorization': `Bearer ${apiKey || ''}`,
        'Prefer': 'resolution=merge-duplicates',
      },
      body: JSON.stringify([userRow]),
    });

    if (!res.ok) {
      const text = await res.text();
      return new Response(
        JSON.stringify({ error: 'Error al sincronizar usuario', details: text }),
        { status: 502, headers: corsHeaders }
      );
    }

    const location = res.headers.get('Content-Location');
    return new Response(
      JSON.stringify({
        success: true,
        user: { id, email, username: userRow.username, avatar_url: userRow.avatar_url },
        message: 'Usuario creado o actualizado en public.users',
      }),
      { status: 200, headers: corsHeaders }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: 'Error interno', details: String(err) }),
      { status: 500, headers: corsHeaders }
    );
  }
};
