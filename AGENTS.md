# Repository Guidelines

This repo contains an iOS SwiftUI app and a small FastAPI server that controls app blocking. Keep changes focused and coordinated across both parts.

## Project Structure & Module Organization
- `pokedaddy/` — iOS app (SwiftUI). Core files: `PokeDaddyApp.swift`, views, managers (`AuthenticationManager`, `ProfileManager`, `AppBlocker`), assets in `PokeDaddy/Assets.xcassets`, config in `PokeDaddy/Info.plist`.
- `pokedaddy-server/` — FastAPI service (`main.py`), deps in `requirements.txt`, local SQLite DB `pokedaddy.db` (dev only).
- `README.md` — high‑level overview; update when endpoints or flows change.

## Build, Test, and Development Commands
- iOS (Xcode):
  - Open: `open pokedaddy/PokeDaddy.xcodeproj`
  - CLI build: `xcodebuild -project pokedaddy/PokeDaddy.xcodeproj -scheme PokeDaddy -destination 'platform=iOS Simulator,name=iPhone 15' build`
- Server (FastAPI):
  - Setup: `cd pokedaddy-server && python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt`
  - Run (dev): `uvicorn main:app --reload` → docs at `http://localhost:8000/docs`

## Coding Style & Naming Conventions
- Swift: 2‑space indent, `UpperCamelCase` types, `lowerCamelCase` vars/functions. Prefer structs and protocol extensions. Keep networking in `APIService` and state in Managers. Small, focused Swift files (one primary type per file).
- Python: PEP 8, type hints, 100‑char lines. Recommended (optional) tools: Black, Ruff, MyPy. Keep DB access via SQLAlchemy models in `main.py` (or a future `models.py`).

## Testing Guidelines
- Server: Add `tests/` with PyTest (e.g., `tests/test_profiles.py`) and run `pytest`. For now, smoke test via Swagger UI and `curl` to key endpoints (`/auth/register`, `/profiles`, `/blocking/status`).
- iOS: Add `PokeDaddyTests/` and `PokeDaddyUITests/` targets; name files `*Tests.swift`. Run in Xcode or `xcodebuild test ...` with a simulator destination.

## Commit & Pull Request Guidelines
- Commits: imperative mood, concise (<72 chars). Prefix scope when helpful: `server:`, `ios:`, `docs:`. Examples: `server: add restricted-apps endpoint`, `ios: fix FamilyControls auth`.
- PRs: include purpose, screenshots for UI, and sample requests/responses for API changes. Link issues, note migrations/config changes, and update `README.md` when behavior shifts.

## Security & Configuration Tips
- Server: set `SECRET_KEY`, tighten CORS, prefer HTTPS in prod, and avoid committing local DBs.
- iOS: ensure `APIService.baseURL` points to the correct environment; maintain required entitlements (FamilyControls/ManagedSettings, Sign in with Apple).

