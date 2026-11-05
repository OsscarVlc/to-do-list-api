#!/bin/bash
# Se ejecuta UNA vez, como root, en el primer arranque de la instancia.
exec > /var/log/user-data.log 2>&1
set -euxo pipefail

# 1. Dependencias del sistema (postgresql-client para poder revisar la BD con psql)
apt-get update -y
apt-get install -y git curl postgresql-client

# 2. Node.js 22
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# 3. Clonar, instalar y compilar la app
git clone ${repo_url} /opt/todo-api
cd /opt/todo-api
npm ci
npm run build
chown -R ubuntu:ubuntu /opt/todo-api

# 4. Servicio systemd para que la app arranque sola y se reinicie si se cae
cat > /etc/systemd/system/todo-api.service <<'EOF'
[Unit]
Description=To-do list API
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/opt/todo-api
Environment=PORT=${app_port}
Environment=DB_SECRET_NAME=${db_secret_name}
Environment=AWS_REGION=${region}
ExecStart=/usr/bin/node dist/server.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now todo-api