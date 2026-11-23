#!/usr/bin/env bash
# Prepara el proyecto recién clonado para trabajar en local
set -e
cd "$(dirname "$0")/.."
[ -f .env ] || { cp .env.example .env; echo "→ .env creado; complétalo con tus valores de Supabase/Firebase"; }
[ -f admin-web/.env ] || cp admin-web/.env.example admin-web/.env
( cd admin-web && npm install --no-audit --no-fund )
if command -v flutter >/dev/null; then
  ( cd mobile && [ -d android ] || flutter create . --org co.chambapo --project-name chambapo )
  ( cd mobile && flutter pub get )
  echo "→ Recuerda copiar los snippets de permisos (mobile/android/.../AndroidManifest.snippet.xml e ios/Info.plist.snippet.xml)"
else
  echo "→ Flutter no está instalado: omito la app móvil"
fi
( cd backend && python -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt -r requirements-dev.txt )
echo "Listo. Siguiente: completa el .env y ejecuta las migraciones en Supabase (ver README)."
