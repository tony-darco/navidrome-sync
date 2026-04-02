#!/bin/bash
set -a
source .env
set +a

cleanup() {
  if [ -n "$VITE_PID" ]; then
    echo "stopping vite (pid $VITE_PID)"
    # Send SIGTERM to the process group so npm + vite both exit
    [ -n "$VITE_PID" ] && pkill -P "$VITE_PID" 2>/dev/null
    wait "$VITE_PID" 2>/dev/null
  fi
  if [ -n "$GO_PID" ]; then
    echo "stopping go (pid $GO_PID)"
    [ -n "$GO_PID" ] && pkill -P "$GO_PID" 2>/dev/null
    wait "$GO_PID" 2>/dev/null
  fi
}
trap cleanup EXIT INT TERM

# Start Vite dev server
(cd web && npm run dev) &
VITE_PID=$!

# Start Go backend
go run . &
GO_PID=$!

echo "Go backend on :${PORT:-8080}, Vite on :5173"
echo "Open http://localhost:5173 for dev (with hot reload)"

wait
