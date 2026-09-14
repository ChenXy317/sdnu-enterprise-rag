# Demo / small-server quick start (this box)

## One-click (recommended)

```bash
/workspace/sdnu-enterprise-rag/start-demo.sh
# or: /workspace/start-demo-sdnu-rag.sh
```

Starts Postgres+Qdrant+Redis (Docker), Ollama models, backend `:8000`, frontend `:5173`, then
`cloudflared tunnel --url http://127.0.0.1:5173` (trycloudflare.com, no login).
Prints the temporary public HTTPS URL. **Ctrl+C** stops tunnel + apps (infra/Ollama stay up).

## Local only (no public URL)

```bash
cd /workspace/sdnu-enterprise-rag
./start.sh start          # or: ./start.sh tunnel
./start.sh stop
```

## Manual cloudflared (if apps already running)

```bash
cloudflared tunnel --url http://127.0.0.1:5173 --no-autoupdate
```

## URLs / ports

| What | Where |
|------|--------|
| Frontend (unified UI+API proxy) | http://127.0.0.1:5173 |
| Backend OpenAPI | http://127.0.0.1:8000/docs |
| Health | http://127.0.0.1:8000/api/v1/health |
| Postgres / Redis / Qdrant / Ollama | 5432 / 6379 / 6333 / 11434 (localhost) |
| Demo tenant | `sdnu-demo` |

## Secrets to fill (optional for local Ollama demo)

Files already created from examples:

- `/workspace/sdnu-enterprise-rag/.env` — `JWT_SECRET` (change before public share)
- `/workspace/sdnu-enterprise-rag/backend/.env` — `JWT_SECRET`; optional `OPENAI_*` if not using local Ollama
- `/workspace/sdnu-enterprise-rag/frontend/.env` — `VITE_DEFAULT_TENANT=sdnu-demo` (ok as-is)

Paid API keys **not required** when using host Ollama (`qwen2.5:1.5b` + `qwen3-embedding:0.6b`).

## Box notes after reboot

```bash
sudo dockerd >/tmp/dockerd.log 2>&1 &
# if needed: sudo chmod 666 /var/run/docker.sock
OLLAMA_HOST=127.0.0.1:11434 ollama serve >/tmp/ollama.log 2>&1 &
```

Then run `start-demo.sh` again.
