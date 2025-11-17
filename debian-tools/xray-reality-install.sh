#!/bin/bash

# vv's Xray Reality One-Click Auto Deploy Script for custom Cloudflare domain

set -e

WORKDIR=~/xray-reality
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# 1. Generate UUID
UUID=$(cat /proc/sys/kernel/random/uuid)
echo "Generated UUID: $UUID"

# 2. Prompt for (or manually paste) pre-generated Reality keys for predictable compatibility
echo ""
echo "Paste your Reality PrivateKey (from: docker run --rm teddysun/xray xray x25519), or leave blank to generate with script:"
read -p "PrivateKey: " PRIVKEY

if [[ -z "$PRIVKEY" ]]; then
  echo "Generating Reality keypair via Docker..."
  REA_KEYS=$(docker run --rm teddysun/xray xray x25519)
  PRIVKEY=$(echo "$REA_KEYS" | grep 'PrivateKey:' | awk '{print $2}')
  PUBKEY=$(echo "$REA_KEYS" | grep 'Password:' | awk '{print $2}')
else
  echo "Paste your Reality PublicKey for client config (same output as above):"
  read -p "PublicKey: " PUBKEY
fi

SHORTID="7b0390ce"
CF_DOMAIN="www.mario8.dpdns.org"
SERVER_NAME="$CF_DOMAIN"
DEST="$CF_DOMAIN:443"
SERVER_IP=$(curl -s api.ip.sb/ip || echo "YOUR_SERVER_IP")

# 3. Write Xray config.json
cat > config.json <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/dev/stdout",
    "error": "/dev/stderr"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$DEST",
          "xver": 0,
          "serverNames": [
            "$SERVER_NAME"
          ],
          "privateKey": "$PRIVKEY",
          "shortIds": [
            "$SHORTID"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

echo "Xray config.json generated."

# 4. Pull and run Docker container
echo "Pulling and starting teddysun/xray container..."
docker pull teddysun/xray
docker stop xray-reality 2>/dev/null || true
docker rm xray-reality 2>/dev/null || true
docker run -d --name xray-reality \
    -v "$WORKDIR/config.json:/etc/xray/config.json:ro" \
    -p 443:443 \
    teddysun/xray

# 5. Generate client JSON config and subscribe URL
cat > client_config.json <<EOF
{
  "v": "2",
  "ps": "$CF_DOMAIN-reality",
  "add": "$SERVER_IP",
  "port": "443",
  "id": "$UUID",
  "aid": "0",
  "scy": "",
  "net": "tcp",
  "type": "",
  "host": "$CF_DOMAIN",
  "path": "",
  "tls": "",
  "sni": "$CF_DOMAIN",
  "alpn": "",
  "fp": "chrome",
  "allowInsecure": false,
  "flow": "xtls-rprx-vision",
  "protocol": "vless",
  "security": "reality",
  "pbk": "$PUBKEY",
  "sid": "$SHORTID"
}
EOF

SUB_URL="vless://$UUID@$SERVER_IP:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$CF_DOMAIN&fp=chrome&pbk=$PUBKEY&sid=$SHORTID&type=tcp&host=$CF_DOMAIN#$CF_DOMAIN-reality"

echo ""
echo "---------------------------"
echo "Deployment finished!"
echo ""
echo "Cloudflare SNI/ServerName/dest: $CF_DOMAIN"
echo "UUID: $UUID"
echo "Reality Public Key for client: $PUBKEY"
echo "ShortID: $SHORTID"
echo ""
echo "---- Subscribe URL ----"
echo "$SUB_URL"
echo ""
echo "---- Client JSON ----"
cat client_config.json
echo ""
echo "If you have a firewall, allow incoming TCP 443."
echo "Check logs: docker logs xray-reality"
echo "To stop:   docker stop xray-reality"
echo "To remove: docker rm xray-reality"
echo "---------------------------"
