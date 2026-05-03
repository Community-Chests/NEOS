#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "Starting NEOS development environment..."
echo "  Backend:  http://localhost:8000"
echo "  Frontend: http://localhost:5173"
echo ""

# Start backend in background
bash neos-operating-system/start-dev.sh &
API_PID=$!

# Start frontend in background
bash charting-the-course/start-dev.sh &
FE_PID=$!

echo "Backend PID: $API_PID | Frontend PID: $FE_PID"
echo "Press Ctrl+C to stop both."

trap "kill $API_PID $FE_PID 2>/dev/null" EXIT
wait
