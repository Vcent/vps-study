#!/bin/bash

# vv's Xray (VLESS+XTLS+Reality) One-click Docker Deploy with Client Config & Subscribe URL

set -e

# 1. Prepare working directory
WORKDIR=/home/root/xray-reality
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# 2. Generate UUID
UUID=$(cat /proc/sys/kernel/random/uuid)
echo "Generated UUID: $UUID"

# 3. Generate Reality keypair using Xray-core (pulled via teddysun/xray image)
echo "Generating Reality keypair..."
REA_KEYS=$(docker run --rm teddysun/xray xray x25519)
PRIVKEY=$(echo "$REA_KEYS" | grep 'Private key' | awk '{print $3}')
PUBKEY=$(echo "$REA_KEYS" | grep 'Public key' | awk '{print $3}')
echo "Reality Private key: $PRIVKEY"
echo "Reality Public key (for client config): $PUBKEY"

# 4. Set other parameters
SHORTID="7b0390ce"
DEST_HOST="cloudflare.com"
SERVER_NAME="$DEST_HOST"

# 5. Detect public IP automatically (change manually if needed)
#SERVER_IP=$(curl -s api.ip.sb/ip || echo "YOUR_SERVER_IP")
SERVER_IP="www.mario8.dpdns.org"

# 6. Write Xray config.json
cat > config.json <<EOF
{
  "log": {
    "loglevel": "trace",
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
          "dest": "$DEST_HOST:443",
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

# 7. Start Xray-core with teddysun/xray Docker image
echo "Pulling and running teddysun/xray Docker image..."
docker pull teddysun/xray
docker stop xray-reality 2>/dev/null || true
docker rm xray-reality 2>/dev/null || true
docker run -d --name xray-reality \
  -v "$WORKDIR/config.json:/etc/xray/config.json:ro" \
  -p 443:443 \
  teddysun/xray

echo "Xray Reality node running in Docker!"

# 8. Create (print) client JSON config for import (v2rayN, SagerNet, sing-box, etc.)
cat > client_config.json <<EOF
{
  "v": "2",
  "ps": "vless-reality-xray",
  "add": "$SERVER_IP",
  "port": "443",
  "id": "$UUID",
  "aid": "0",
  "scy": "",
  "net": "tcp",
  "type": "",
  "host": "$DEST_HOST",
  "path": "",
  "tls": "",
  "sni": "$SERVER_NAME",
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

# 9. Make subscription URL in standard format
SUB_URL="vless://$UUID@$SERVER_IP:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SERVER_NAME&fp=chrome&pbk=$PUBKEY&sid=$SHORTID&type=tcp&host=$DEST_HOST#vless-reality-xray"

echo ""
echo "--------------- Deployment Complete ---------------"
echo "Server: $SERVER_IP"
echo "UUID: $UUID"
echo "Reality Public Key: $PUBKEY"
echo "ShortID: $SHORTID"
echo ""
echo ">>> Client subscribe URL format (for v2rayN, Clash Meta, etc):"
echo "$SUB_URL"
echo ""
echo ">>> Client config (client_config.json):"
cat client_config.json
echo ""
echo "Use these values to connect from any Reality-supporting VLESS/Xray client."
echo "If you have a custom firewall (nftables/iptables), ensure TCP 443 is open: sudo nft add rule inet filter input tcp dport 443 accept"
echo "Check logs: docker logs xray-reality"
echo "To stop:   docker stop xray-reality"
echo "To remove: docker rm xray-reality"
echo ""
