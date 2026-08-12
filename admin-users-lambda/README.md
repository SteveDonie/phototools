# admin-users Lambda setup

Backs the `/api/admin-users` placeholder in userAdmin.html. One-time setup, all in the AWS console.

## 1. Gather three values

- **Access token**: Userbase admin panel (https://v1.userbase.com) → Account → create an Access Token. This is the secret that must never go in client-side code.
- **App ID**: `b6a8348d-da63-495e-9600-e4f3368cc3f3` (already in your pages).
- **Admin userId**: the ID shown for stevedonie in the Userbase admin panel (or on a user card in userAdmin.html once it works).

## 2. Create the function

1. AWS Console → Lambda → Create function → "Author from scratch".
2. Name: `album-admin-users`. Runtime: Node.js 22.x (or newest). Architecture: arm64 (cheaper). Everything else default.
3. In the code editor, replace the contents of `index.mjs` with the `index.mjs` in this folder. Click **Deploy**.

## 3. Environment variables

Configuration → Environment variables → add:

| Key | Value |
|---|---|
| `USERBASE_ACCESS_TOKEN` | the access token from step 1 |
| `USERBASE_APP_ID` | `b6a8348d-da63-495e-9600-e4f3368cc3f3` |
| `ADMIN_USER_ID` | stevedonie's userId |
| `USERBASE_ADMIN_EMAIL` | your v1.userbase.com admin account email (needed for Delete User) |
| `USERBASE_ADMIN_PASSWORD` | your v1.userbase.com admin account password (needed for Delete User) |
| `USERBASE_APP_NAME` | the app's name as shown in the Userbase admin panel, e.g. `Starter App` (needed for Delete User) |

Note on the delete feature: the documented access-token API has no delete
endpoint, so the Lambda signs in to the Userbase admin panel's own endpoints
(`/v1/admin/sign-in`, `/v1/admin/delete-user`, `/v1/admin/permanent-delete-user`) —
the same calls the v1.userbase.com UI makes. They're undocumented, so a future
Userbase change could break deletes (the user list would keep working). If
deletes ever start failing, fall back to deleting users manually in the
v1.userbase.com admin panel.

## 4. Function URL

Configuration → Function URL → Create function URL:

- Auth type: **NONE** (the code does its own auth via Userbase auth tokens).
- Leave the "Configure CORS" checkbox **unchecked** — the code sends its own CORS headers, and enabling both causes duplicate headers that browsers reject.

Copy the URL it gives you, e.g. `https://abc123xyz.lambda-url.us-east-1.on.aws/`.

## 5. Point userAdmin.html at it

In userAdmin.html (the phototools master copy — deployhtml.bat copies it to the album), set:

```js
const USERS_PROXY_URL = 'https://abc123xyz.lambda-url.us-east-1.on.aws/';
```

Then run deployhtml.bat / your normal deploy.

## 6. Test

1. Open https://album.donie.us/personal/userAdmin.html, sign in as stevedonie → user cards should load.
2. In a private window, `fetch` the Function URL directly with no header → should get 401. That's the point: without a valid stevedonie session token, the endpoint reveals nothing.

## Troubleshooting

- **401 in the admin panel**: your Userbase session's authToken expired — sign out/in. Auth tokens are only valid for a short window after sign-in; if this bites often, the panel could re-sign-in before fetching.
- **CORS error in console**: confirm the Function URL CORS checkbox is off, and the request origin is exactly `https://album.donie.us` (the code only allows that origin).
- **502**: check the Lambda's CloudWatch logs (Monitor → View CloudWatch logs).
