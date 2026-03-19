# Auth con Google – Proyecto Calistenia (Insforge)

## 1. Providers habilitados

En el backend **Calistenia** ya tienes:

- **Email/Password**: registro e inicio de sesión con email y contraseña.
- **Google OAuth**: ya aparece en `oAuthProviders` (junto con GitHub).

Si en el dashboard de Insforge no ves Email/Password o quieres cambiar algo:

- Entra en el proyecto **Calistenia** → **Authentication** (o **Auth**).
- Activa **Email/Password** y **Google** (y opcionalmente GitHub).
- Ajusta **requireEmailVerification** si quieres obligar a verificar el email.

---

## 2. URLs de callback para Google Cloud Console

Para que el login con Google funcione, en **Google Cloud Console** (APIs & Services → Credentials → tu OAuth 2.0 Client ID) configura:

### Authorized JavaScript origins

- `https://swd7siw3.eu-central.insforge.app`
- `http://localhost:3000` (o el puerto que uses en desarrollo)
- El dominio de tu app en producción (ej: `https://tudominio.com`)

### Authorized redirect URIs

- `https://swd7siw3.eu-central.insforge.app/auth/v1/callback`
- `http://localhost:3000/auth/v1/callback` (si usas redirect en local)

(Si Insforge usa otra ruta de callback, en el dashboard de Auth suele indicarla; sustituye `/auth/v1/callback` por la que te muestre.)

---

## 3. Sincronizar auth con la tabla `public.users`

Cada vez que un usuario se registre (Email/Password o OAuth), conviene tener un registro en `public.users` (nivel, role, etc.).

### Opción A: Llamar a la Edge Function desde el cliente (recomendado)

Después de que el usuario inicie sesión (por ejemplo con `signInWithOAuth({ provider: 'google' })` o `signUp`), obtén la sesión y llama a la función **auth-callback** con los datos del usuario:

```javascript
const { data } = await insforge.auth.getCurrentSession();
if (data?.session?.user) {
  const u = data.session.user;
  await insforge.functions.invoke('auth-callback', {
    body: {
      id: u.id,
      email: u.email,
      username: u.profile?.name ?? u.email?.split('@')[0],
      avatar_url: u.profile?.avatar_url ?? null,
    },
  });
}
```

La función hace **upsert** en `public.users` por `id`.

### Opción B: Trigger en base de datos (si tu backend lo permite)

Si tu instancia expone el esquema `auth` y puedes crear triggers, en el SQL Editor del proyecto puedes ejecutar algo como:

```sql
-- Solo si existe auth.users y tienes permisos
CREATE OR REPLACE FUNCTION public.sync_auth_user_to_public()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, username)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1))
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    username = COALESCE(EXCLUDED.username, public.users.username),
    updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.sync_auth_user_to_public();
```

Si no tienes tabla `auth.users` o el trigger no está permitido, usa solo la Opción A.

---

## 4. Edge Function `auth-callback`

- **Método**: `POST`
- **Body**: `{ id, email, username?, avatar_url? }`
- **Respuesta**: `{ success: true, user: { id, email, username, avatar_url } }` o `{ error, details? }`

La función hace upsert en `public.users` por `id`. Si en tu proyecto la API REST usa otro path o headers, ajusta la URL y el `apikey` dentro de la función (o usa la variable de entorno que te indique Insforge para las funciones).

---

## 5. Resumen

| Qué | Dónde |
|-----|--------|
| Activar Email/Password y Google | Dashboard Insforge → Proyecto Calistenia → Auth |
| Orígenes y redirects OAuth | Google Cloud Console → Credentials → OAuth 2.0 Client |
| Sincronizar auth → `public.users` | Llamar a la Edge Function `auth-callback` tras el login (o usar trigger si está disponible) |

Si quieres, el siguiente paso puede ser conectar el botón “Iniciar con Google” en tu app Flutter/React y llamar a `auth-callback` justo después de obtener la sesión.
