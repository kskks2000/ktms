# KTMS Backend

FastAPI backend workspace for KTMS.

Planned responsibilities:

- Verify Firebase ID tokens issued to Flutter clients.
- Expose APIs backed by the PostgreSQL `ktms` schema.
- Serve transport order, shipment, tracking, dispatch, settlement, and invoice workflows.

## Local API

The backend reads database settings from the project root `.env` file. Keep
secrets out of source control.

Required keys:

- `APP_ENV`
- `KTMS_CORS_ORIGINS`
- `KTMS_DB_HOST`
- `KTMS_DB_PORT`
- `KTMS_DB_NAME`
- `KTMS_DB_USER`
- `KTMS_DB_PASSWORD`
- `KTMS_DB_SCHEMA`

Optional tenant/company scoping keys:

- `KTMS_DEFAULT_TENANT_CODE`
- `KTMS_DEFAULT_COMPANY_CODE`

Run the API locally:

```bash
cd /Users/robert/kcastle/codex/ktms
/opt/homebrew/bin/python3.12 -m venv .venv
. .venv/bin/activate
python -m pip install -e backend
uvicorn app.main:app --app-dir backend --host www.kcastle.net --port 8000
```

Master save endpoints are available under `/api/masters/*`.
