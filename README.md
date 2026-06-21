# KTMS

Enterprise transportation management system workspace.

## Structure

- `frontend/`: Flutter app with KTMS login and Firebase Auth integration.
- `backend/`: FastAPI backend workspace.

## Frontend

```bash
cd frontend
flutter pub get
node tool/flutter_env.mjs run -d chrome
```

Frontend runtime configuration is read from the project root `.env` file and
passed to Flutter as client-safe `--dart-define` values. Start from
`.env.example`, then keep the real `.env` out of source control.

Firebase login is wired for email/password and Google sign-in. After creating a
Firebase project, place the Firebase/Naver values in `.env`. For mobile builds,
generate the platform config files locally:

```bash
node tool/flutter_env.mjs prepare-firebase
```

Do not commit generated Firebase platform files or `.env` values.

## Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -e .
uvicorn app.main:app --reload
```


## Deploy
프로그램 수정 및 추가 후 로컬에서 테스트 하지 말고 sFTP로 웹서버에 배포한 후에 테스트 한다.
테스트는 http://www.kcastle.net에서 확인 할 수 있게 하고 테스트도 http://www.kcastle.net에서 한다.
