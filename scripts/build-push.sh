#!/usr/bin/env bash
# Sirve para construir y publicar las imágenes en Docker Hub
set -e
USER=${1:?usuario de Docker Hub}; VER=${2:-1.0}
cd "$(dirname "$0")/.."
docker build -t "$USER/chambapo-api:$VER" ./backend
docker build -t "$USER/chambapo-admin:$VER" ./admin-web
docker push "$USER/chambapo-api:$VER"
docker push "$USER/chambapo-admin:$VER"
sed -i.bak "s#DOCKERHUB_USER#$USER#g; s#:1.0#:$VER#g" k8s/20-api.yaml k8s/30-cronjobs.yaml k8s/40-admin-web.yaml && rm -f k8s/*.bak
echo "Imágenes publicadas y manifiestos actualizados con $USER:$VER"
