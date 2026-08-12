// index.mjs — AWS Lambda handler backing userAdmin.html.
//
// GET  -> list users (proxies the documented Userbase Admin List Users API)
// POST {action:'deleteUser', userId, username}
//      -> delete + permanently delete a user. The access-token API has no
//         delete endpoint, so this signs in to the Userbase admin panel's own
//         (undocumented) endpoints — the same calls the v1.userbase.com UI makes.
//
// Every request must carry the Userbase authToken of the signed-in admin user
// (stevedonie); it is verified via the Verify Auth Token API.
//
// Environment variables:
//   USERBASE_ACCESS_TOKEN   - Admin API access token (admin panel > Account)
//   USERBASE_APP_ID         - b6a8348d-da63-495e-9600-e4f3368cc3f3
//   ADMIN_USER_ID           - the Userbase userId of the stevedonie account
//   USERBASE_ADMIN_EMAIL    - email of your v1.userbase.com admin account   (deletes only)
//   USERBASE_ADMIN_PASSWORD - password of your v1.userbase.com admin account (deletes only)
//   USERBASE_APP_NAME       - the app's name shown in the admin panel, e.g. "Starter App" (deletes only)

const UB = 'https://v1.userbase.com/v1/admin';

const CORS = {
  'Access-Control-Allow-Origin': 'https://album.donie.us',
  'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization,Content-Type',
};

const json = (statusCode, obj) => ({
  statusCode,
  headers: { 'Content-Type': 'application/json', ...CORS },
  body: JSON.stringify(obj),
});

// ---------- caller verification (both GET and POST) ----------

async function verifyCallerIsAdmin(event, accessToken, adminUserId) {
  const authHeader = event.headers?.authorization || '';
  const authToken  = authHeader.replace(/^Bearer\s+/i, '');
  if (!authToken) return json(401, { error: 'Missing auth token' });

  const verify = await fetch(`${UB}/auth-tokens/${encodeURIComponent(authToken)}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!verify.ok) return json(401, { error: 'Invalid or expired auth token' });

  const { userId } = await verify.json();
  if (userId !== adminUserId) return json(403, { error: 'Not authorized' });

  return null; // caller is the admin
}

// ---------- GET: list users ----------

async function listUsers(accessToken, appId) {
  let users = [];
  let nextPageToken;
  do {
    const url = new URL(`${UB}/apps/${appId}/users`);
    if (nextPageToken) url.searchParams.set('nextPageToken', nextPageToken);

    const resp = await fetch(url, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!resp.ok) throw new Error(`Userbase API returned ${resp.status}`);

    const data = await resp.json();
    users = users.concat(data.users || []);
    nextPageToken = data.nextPageToken;
  } while (nextPageToken);

  return json(200, { users: users.filter(u => !u.deleted) });
}

// ---------- POST: delete user ----------

// Signs in to the Userbase admin panel and returns the session cookie.
async function adminPanelSignIn(email, password) {
  const resp = await fetch(`${UB}/sign-in`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  if (!resp.ok) throw new Error(`Admin panel sign-in failed (${resp.status})`);

  const setCookies = typeof resp.headers.getSetCookie === 'function'
    ? resp.headers.getSetCookie()
    : [resp.headers.get('set-cookie')];
  const cookie = (setCookies || []).find(c => c && c.startsWith('adminSessionId='));
  if (!cookie) throw new Error('Admin panel sign-in returned no session cookie');

  return cookie.split(';')[0]; // "adminSessionId=..."
}

async function deleteUser(body, env) {
  const { userId, username } = body;
  if (!userId || !username) return json(400, { error: 'Missing userId or username' });

  const cookie = await adminPanelSignIn(env.adminEmail, env.adminPassword);
  const post = (path) => fetch(`${UB}/${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Cookie: cookie },
    body: JSON.stringify({ appName: env.appName, username, userId }),
  });

  try {
    // Soft delete first (marks the account deleted)...
    const del = await post('delete-user');
    if (!del.ok && del.status !== 409) {
      throw new Error(`delete-user failed (${del.status}): ${await del.text()}`);
    }

    // ...then purge it permanently.
    const pdel = await post('permanent-delete-user');
    if (!pdel.ok && pdel.status !== 409) {
      throw new Error(`permanent-delete-user failed (${pdel.status}): ${await pdel.text()}`);
    }

    return json(200, { deleted: username });
  } finally {
    // Best-effort: don't leave the admin session lying around.
    await fetch(`${UB}/sign-out`, { method: 'POST', headers: { Cookie: cookie } })
      .catch(() => {});
  }
}

// ---------- handler ----------

export const handler = async (event) => {
  const method = event.requestContext?.http?.method;

  if (method === 'OPTIONS') {
    return { statusCode: 204, headers: CORS };
  }

  const accessToken = process.env.USERBASE_ACCESS_TOKEN;
  const appId       = process.env.USERBASE_APP_ID;
  const adminUserId = process.env.ADMIN_USER_ID;

  if (!accessToken || !appId || !adminUserId) {
    return json(500, { error: 'Lambda environment variables not configured' });
  }

  try {
    const authFailure = await verifyCallerIsAdmin(event, accessToken, adminUserId);
    if (authFailure) return authFailure;

    if (method === 'GET') {
      return await listUsers(accessToken, appId);
    }

    if (method === 'POST') {
      const raw = event.isBase64Encoded
        ? Buffer.from(event.body || '', 'base64').toString('utf8')
        : (event.body || '{}');
      const body = JSON.parse(raw);

      if (body.action === 'deleteUser') {
        const env = {
          adminEmail:    process.env.USERBASE_ADMIN_EMAIL,
          adminPassword: process.env.USERBASE_ADMIN_PASSWORD,
          appName:       process.env.USERBASE_APP_NAME,
        };
        if (!env.adminEmail || !env.adminPassword || !env.appName) {
          return json(500, { error: 'Delete env vars not configured (USERBASE_ADMIN_EMAIL / USERBASE_ADMIN_PASSWORD / USERBASE_APP_NAME)' });
        }
        return await deleteUser(body, env);
      }

      return json(400, { error: `Unknown action: ${body.action}` });
    }

    return json(405, { error: `Method ${method} not allowed` });

  } catch (err) {
    console.error(err);
    return json(502, { error: err.message });
  }
};
