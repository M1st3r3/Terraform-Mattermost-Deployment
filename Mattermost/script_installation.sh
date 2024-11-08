#!/bin/bash
# scripts/install_mattermost.sh

# Mise à jour du système
apt update -y
apt upgrade -y

# Installation de Docker
apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update -y
apt install -y docker-ce

# Démarrage de Docker
systemctl start docker
systemctl enable docker

# Installation de docker-compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Création du répertoire pour Mattermost
mkdir -p /opt/mattermost/config
mkdir -p /opt/mattermost/data
mkdir -p /opt/mattermost/logs
mkdir -p /opt/mattermost/plugins
mkdir -p /opt/mattermost/client/plugins

# Set correct permissions for Mattermost directories
chown -R 2000:2000 /opt/mattermost/config
chown -R 2000:2000 /opt/mattermost/data
chown -R 2000:2000 /opt/mattermost/logs
chown -R 2000:2000 /opt/mattermost/plugins
chown -R 2000:2000 /opt/mattermost/client/plugins

# Création du docker-compose.yml
cat > /opt/mattermost/docker-compose.yml <<EOF
version: "3"
services:
  db:
    image: postgres:13
    restart: always
    environment:
      POSTGRES_USER: mmuser
      POSTGRES_PASSWORD: mmuser-password
      POSTGRES_DB: mattermost
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
    networks:
      - mm-network

  mattermost:
    image: mattermost/mattermost-team-edition:latest
    restart: always
    depends_on:
      - db
    environment:
      MM_USERNAME: mmuser
      MM_PASSWORD: mmuser-password
      MM_DBNAME: mattermost
      MM_SQLSETTINGS_DRIVERNAME: postgres
      MM_SQLSETTINGS_DATASOURCE: postgres://mmuser:mmuser-password@db:5432/mattermost?sslmode=disable
    volumes:
      - ./config:/mattermost/config
      - ./data:/mattermost/data
      - ./logs:/mattermost/logs
      - ./plugins:/mattermost/plugins
      - ./client/plugins:/mattermost/client/plugins
    ports:
      - "8065:8065"
    networks:
      - mm-network

networks:
  mm-network:
    driver: bridge
EOF

# Démarrage des conteneurs
cd /opt/mattermost
docker-compose up -d
