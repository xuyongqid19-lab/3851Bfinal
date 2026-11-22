@echo off
cd /d "%~dp0"
REM Serves the prebuilt production web bundle (build\web) on http://localhost:7357
REM IMPORTANT: if lib/ changed, rebuild first with ALL four dart-defines:
REM flutter build web --dart-define=GOOGLE_WEB_CLIENT_ID=848686154651-a5lrjn63ggqj83g5ob4bms7imqd6jkth.apps.googleusercontent.com --dart-define=AUTH_API_BASE_URL=http://localhost:3002 --dart-define=FAMILY_API_BASE_URL=http://localhost:3003 --dart-define=CHAT_API_BASE_URL=http://localhost:3004

REM Ensure all backends are up (requires Docker Desktop running)
docker compose -f docker-compose.yml up -d
docker compose -f docker-compose.auth.yml up -d
docker compose -f docker-compose.family.yml up -d
docker compose -f docker-compose.chat.yml up -d

REM Seed demo accounts, friendships and group (idempotent - safe on every run)
docker cp "%~dp0tools\seed-demo-auth.sql" global-village-auth-db:/tmp/seed.sql
docker exec global-village-auth-db psql -U global_village_auth -d global_village_auth -v ON_ERROR_STOP=0 -f /tmp/seed.sql
docker cp "%~dp0tools\seed-demo-chat.sql" global-village-chat-db:/tmp/seed.sql
docker exec global-village-chat-db psql -U global_village_chat -d global_village_chat -v ON_ERROR_STOP=0 -f /tmp/seed.sql

docker rm -f global-village-web >nul 2>&1
docker run -d --name global-village-web -p 7357:80 -v "%~dp0build\web:/usr/share/nginx/html:ro" nginx:alpine

start "" "http://localhost:7357"
echo Global Village is running at http://localhost:7357
pause
