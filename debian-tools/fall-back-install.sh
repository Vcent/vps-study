#!/bin/bash
# vv's fallback Nginx server: HTTP+HTTPS on 127.0.0.1 only (ports 2443/2080)

set -e

# 1. Install nginx & openssl
sudo apt update
sudo apt install nginx openssl -y

# 2. Generate self-signed certificate for HTTPS on 2443
CERT_DIR="/etc/ssl/fallback"
sudo mkdir -p $CERT_DIR

sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout ${CERT_DIR}/fallback.key \
  -out ${CERT_DIR}/fallback.crt \
  -subj "/CN=localhost"

# 3. Create simple index.html
echo "<h1>Welcome to my org </h1><p>Continue to access global.</p>" | sudo tee /var/www/html/index.nginx.html

# 4. Configure nginx HTTP/HTTPS on 127.0.0.1:2080 and 127.0.0.1:2443
NG_CFG="/etc/nginx/sites-available/fallback"
sudo tee $NG_CFG > /dev/null <<EOF
server {
    listen 127.0.0.1:2080 default_server;
    server_name _;
    root /var/www/html;
    index index.nginx.html;
}
server {
    listen 127.0.0.1:2443 ssl default_server;
    server_name _;
    root /var/www/html;
    index index.nginx.html;
    ssl_certificate $CERT_DIR/fallback.crt;
    ssl_certificate_key $CERT_DIR/fallback.key;
    ssl_protocols TLSv1.2 TLSv1.3;
}
EOF

# 5. Enable config (disable default), restart nginx
sudo ln -sf $NG_CFG /etc/nginx/sites-enabled/fallback
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx

echo ""
echo "------------------------------------------------------"
echo "Fallback Nginx is running on:"
echo "  - HTTP:  127.0.0.1:2080"
echo "  - HTTPS: 127.0.0.1:2443 (self-signed cert)"
echo ""
echo "Test locally: curl 127.0.0.1:2080/"
echo "Test HTTPS:   curl -k 127.0.0.1:2443/"
echo ""
echo "Now point your Xray fallback to 127.0.0.1:2080 (HTTP) or 127.0.0.1:2443 (HTTPS) as needed."
echo "------------------------------------------------------"
