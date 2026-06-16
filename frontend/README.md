# KTMS Frontend

Flutter workspace for the KTMS web and mobile client.

## Local API

Master screens save through the FastAPI backend. Flutter does not connect to
PostgreSQL directly.

Run against a local API:

```bash
cd /Users/robert/kcastle/codex/ktms/frontend
flutter run -d chrome --dart-define=KTMS_API_BASE_URL=http://127.0.0.1:8000/api
```

For production web builds, serve the backend under the same domain `/api` or
pass the deployed API URL with `--dart-define=KTMS_API_BASE_URL=...`.
