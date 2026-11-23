# SDG4 Study App — Prototype

Local-only demo. No hosting, no database.

## Backends
- `server-node/`  → Express on :3000 (content API + serves built client)
- `server-python/`→ FastAPI on :8000 (translation + optional TTS)

## Frontend
- `client/` → Vite + React on :5173 (dev) or served via Node on :3000 (demo)

## First run
    cd server-node && npm install && npm run seed && npm start
    cd server-python && python -m venv .venv && source .venv/bin/activate \
      && pip install -r requirements.txt && bash run.sh
    cd client && npm install && npm run dev
