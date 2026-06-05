# KTMS

Enterprise transportation management system workspace.

## Structure

- `frontend/`: Flutter app with KTMS login and Firebase Auth integration.
- `backend/`: FastAPI backend workspace.

## Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

Firebase login is wired for email/password and Google sign-in. After creating a Firebase project, run:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Allow FlutterFire to replace `frontend/lib/firebase_options.dart`.

## Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -e .
uvicorn app.main:app --reload
```
