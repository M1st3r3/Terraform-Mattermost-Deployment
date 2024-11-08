#!/bin/bash

# Set the hostname
HOSTNAME="!_DNS_HOSTNAME_!"

# Update the system
apt update -y
apt upgrade -y

# Install required packages
apt install -y apt-transport-https ca-certificates curl software-properties-common nginx certbot python3-certbot-nginx

# Add Docker repository and install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update -y
apt install -y docker-ce

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Install docker-compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create Mattermost directories
mkdir -p /opt/mattermost/{config,data,logs,plugins,client/plugins}

# Set correct permissions for Mattermost directories
chown -R 2000:2000 /opt/mattermost/{config,data,logs,plugins,client/plugins}

# Create initial Nginx configuration without SSL
cat > /etc/nginx/sites-available/mattermost <<EOF
server {
    listen 80;
    server_name $HOSTNAME;

    location / {
        proxy_pass http://localhost:8065;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable the site and remove default
ln -s /etc/nginx/sites-available/mattermost /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
nginx -t

# Restart Nginx
systemctl restart nginx

# Generate SSL certificate
certbot --nginx -d $HOSTNAME --non-interactive --agree-tos --email admin@$HOSTNAME

# Update Nginx configuration with SSL
cat > /etc/nginx/sites-available/mattermost <<EOF
server {
    listen 80;
    server_name $HOSTNAME;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $HOSTNAME;

    ssl_certificate /etc/letsencrypt/live/$HOSTNAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$HOSTNAME/privkey.pem;

    location / {
        proxy_pass http://localhost:8065;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Test Nginx configuration again
nginx -t

# Restart Nginx
systemctl restart nginx

# Create docker-compose.yml
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
      MM_SERVICESETTINGS_SITEURL: https://$HOSTNAME
    volumes:
      - ./config:/mattermost/config
      - ./data:/mattermost/data
      - ./logs:/mattermost/logs
      - ./plugins:/mattermost/plugins
      - ./client/plugins:/mattermost/client/plugins
    ports:
      - "127.0.0.1:8065:8065"
    networks:
      - mm-network

networks:
  mm-network:
    driver: bridge
EOF

# Start Mattermost containers
cd /opt/mattermost
docker-compose up -d

echo "Installation complete!"
echo "Please access Mattermost at https://$HOSTNAME"
