# KTMS Frontend

Flutter workspace for the KTMS web and mobile client.

## Local API

Master screens save through the FastAPI backend. Flutter does not connect to
PostgreSQL directly.

Put frontend-safe values in the project root `.env` file:

- `KTMS_API_BASE_URL`
- `KTMS_NAVER_MAP_CLIENT_ID`
- `KTMS_FIREBASE_*`

Run against a local API:

```bash
cd /Users/robert/kcastle/codex/ktms/frontend
node tool/flutter_env.mjs run -d chrome
```

For production web builds, serve the backend under the same domain `/api` or
set `KTMS_API_BASE_URL` in `.env`, then build with:

```bash
node tool/flutter_env.mjs build web --release
```

`node tool/flutter_env.mjs test` intentionally omits `KTMS_API_BASE_URL` so
widget tests keep using the local no-API path. Set `KTMS_ENABLE_API_IN_TESTS=true`
only for tests that explicitly mock or allow API calls.

For mobile Firebase builds, generate platform files locally from `.env`:

```bash
node tool/flutter_env.mjs prepare-firebase
```
