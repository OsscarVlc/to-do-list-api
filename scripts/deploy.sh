#!/bin/bash
# Se ejecuta DENTRO de la EC2 (vía SSH desde GitHub Actions).
# Uso: deploy.sh <tag> <owner/repo>
set -euo pipefail

TAG="$1"
REPO="$2"
APP_DIR="/opt/todo-api"
WORK_DIR="$HOME/releases/$TAG"
ZIP_NAME="to-do-list-api-$TAG.zip"
ZIP_URL="https://github.com/$REPO/releases/download/$TAG/$ZIP_NAME"

echo "==> Desplegando $TAG"

# 1. Herramienta para descomprimir (si ya está instalada, no hace nada)
sudo apt-get install -y -qq unzip > /dev/null

# 2. Descargar el artefacto del release
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
curl -fsSL -o "/tmp/$ZIP_NAME" "$ZIP_URL"
unzip -q "/tmp/$ZIP_NAME" -d "$WORK_DIR"
rm "/tmp/$ZIP_NAME"

# 3. Instalar dependencias y compilar la nueva versión
cd "$WORK_DIR"
npm ci
npm run build

# 4. Reemplazar la versión actual (la anterior se guarda como respaldo)
sudo rm -rf "$APP_DIR.old"
sudo mv "$APP_DIR" "$APP_DIR.old"
sudo mv "$WORK_DIR" "$APP_DIR"

# 5. Pasarle la versión a la app con un drop-in de systemd
sudo mkdir -p /etc/systemd/system/todo-api.service.d
echo -e "[Service]\nEnvironment=APP_VERSION=$TAG" | sudo tee /etc/systemd/system/todo-api.service.d/version.conf > /dev/null

# 6. Reiniciar el servidor con la nueva versión
sudo systemctl daemon-reload
sudo systemctl restart todo-api

# 7. Verificar que la versión nueva responde
for i in $(seq 1 10); do
  if curl -fs http://localhost:3000/version | grep -q "\"$TAG\""; then
    echo "==> $TAG desplegada correctamente"
    exit 0
  fi
  sleep 3
done

echo "==> ERROR: la app no respondió con la versión $TAG"
sudo journalctl -u todo-api -n 30 --no-pager
exit 1