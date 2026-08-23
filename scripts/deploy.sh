#!/usr/bin/env bash
set -e

echo "=== [1/4] Pulling and building Docker images ==="
docker compose build

echo "=== [2/4] Starting PostgreSQL database ==="
docker compose up -d postgres

echo "=== [3/4] Running Alembic database migrations ==="
docker compose run --rm backend alembic upgrade head

echo "=== [4/4] Starting Backend & Web Admin services ==="
docker compose up -d backend web_admin

echo "=== Deployment completed successfully! ==="
echo "Backend:   http://localhost:8000/api/v1/health"
echo "Web Admin: http://localhost:3000"
