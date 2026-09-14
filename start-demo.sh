#!/usr/bin/env bash
# One-click personal demo: start local stack + Cloudflare quick tunnel, print public URL.
# Ctrl+C stops the tunnel and app processes (Postgres/Qdrant/Redis/Ollama left running).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_DIR="${ROOT}/.run"
PORT="${DEMO_PORT:-5173}"
TUNNEL_PID=""

mkdir -p "${RUN_DIR}"

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

ensure_docker() {
  if ! docker info >/dev/null 2>&1; then
    if [[ -S /var/run/docker.sock ]]; then
      die "Docker socket exists but not usable (try: sudo chmod 666 /var/run/docker.sock or add user to docker group)"
    fi
    log "starting dockerd..."
    sudo dockerd >/tmp/dockerd.log 2>&1 &
    local i
    for i in $(seq 1 40); do
      docker info >/dev/null 2>&1 && return 0
      sleep 0.5
    done
    die "dockerd did not become ready; see /tmp/dockerd.log"
  fi
}

ensure_ollama() {
  command -v ollama >/dev/null 2>&1 || die "ollama not found"
  if ! curl -fsS -o /dev/null --max-time 2 "http://127.0.0.1:11434/api/tags" 2>/dev/null; then
    log "starting ollama serve..."
    OLLAMA_HOST=127.0.0.1:11434 nohup ollama serve >/tmp/ollama.log 2>&1 &
    local i
    for i in $(seq 1 40); do
      curl -fsS -o /dev/null --max-time 2 "http://127.0.0.1:11434/api/tags" 2>/dev/null && return 0
      sleep 0.5
    done
    die "Ollama did not become ready; see /tmp/ollama.log"
  fi
}

cloudflared_bin() {
  if command -v cloudflared >/dev/null 2>&1; then
    command -v cloudflared
    return 0
  fi
  if [[ -x "${RUN_DIR}/cloudflared" ]]; then
    printf '%s\n' "${RUN_DIR}/cloudflared"
    return 0
  fi
  return 1
}

ensure_cloudflared() {
  if cloudflared_bin >/dev/null; then
    return 0
  fi
  command -v curl >/dev/null 2>&1 || die "curl not found"
  log "downloading cloudflared..."
  curl -fsSL -o "${RUN_DIR}/cloudflared" \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
  chmod +x "${RUN_DIR}/cloudflared"
}

read_tunnel_url() {
  [[ -f "${RUN_DIR}/demo-tunnel.log" ]] || return 1
  grep -oE 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' "${RUN_DIR}/demo-tunnel.log" | tail -n 1
}

wait_tunnel_url() {
  local tries="${1:-80}" i url
  for i in $(seq 1 "${tries}"); do
    url="$(read_tunnel_url || true)"
    if [[ -n "${url}" ]]; then
      printf '%s\n' "${url}"
      return 0
    fi
    if [[ -n "${TUNNEL_PID}" ]] && ! kill -0 "${TUNNEL_PID}" 2>/dev/null; then
      die "cloudflared exited; see ${RUN_DIR}/demo-tunnel.log"
    fi
    sleep 0.5
  done
  die "tunnel URL not found; see ${RUN_DIR}/demo-tunnel.log"
}

cleanup() {
  local code=$?
  trap - EXIT INT TERM
  log ""
  log "cleaning up..."
  if [[ -n "${TUNNEL_PID}" ]] && kill -0 "${TUNNEL_PID}" 2>/dev/null; then
    kill "${TUNNEL_PID}" 2>/dev/null || true
    wait "${TUNNEL_PID}" 2>/dev/null || true
  fi
  rm -f "${RUN_DIR}/demo-tunnel.pid" "${RUN_DIR}/demo-tunnel.url"
  if [[ -x "${ROOT}/start.sh" ]]; then
    "${ROOT}/start.sh" stop || true
  fi
  log "stopped demo (infra/Ollama left running)."
  exit "${code}"
}

main() {
  command -v docker >/dev/null 2>&1 || die "docker not found"
  ensure_docker
  ensure_ollama
  ensure_cloudflared

  trap cleanup EXIT INT TERM

  log "=== starting local stack (frontend :${PORT} proxies /api → :8000) ==="
  "${ROOT}/start.sh" start

  local bin url
  bin="$(cloudflared_bin)" || die "cloudflared not found"

  : >"${RUN_DIR}/demo-tunnel.log"
  log "=== starting Cloudflare quick tunnel (no login) ==="
  "${bin}" tunnel --url "http://127.0.0.1:${PORT}" --no-autoupdate \
    >"${RUN_DIR}/demo-tunnel.log" 2>&1 &
  TUNNEL_PID=$!
  echo "${TUNNEL_PID}" >"${RUN_DIR}/demo-tunnel.pid"

  url="$(wait_tunnel_url 80)"
  printf '%s\n' "${url}" >"${RUN_DIR}/demo-tunnel.url"

  log ""
  log "============================================"
  log "  DEMO READY"
  log "  Public URL : ${url}"
  log "  Local UI   : http://127.0.0.1:${PORT}"
  log "  API docs   : http://127.0.0.1:8000/docs"
  log "  Tenant     : sdnu-demo"
  log "  Press Ctrl+C to stop tunnel + apps"
  log "============================================"
  log ""

  # Stay foreground so Ctrl+C triggers cleanup
  while kill -0 "${TUNNEL_PID}" 2>/dev/null; do
    sleep 2
  done
  die "cloudflared exited unexpectedly; see ${RUN_DIR}/demo-tunnel.log"
}

main "$@"
