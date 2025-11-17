#!/bin/bash

# vv's one-click VLESS+XTLS+Reality Xray node with IPv4 only, port 8443, full bing.com camouflage

set -e

WORKDIR=/home/root/xray-reality
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# 1. Generate UUID
UUID=$(cat /proc/sys/kernel/random/uuid)
echo "Generated UUID: $UUID"

# 2. Generate Reality keypair (prompt if fails)
KEYS=$(docker run --rm teddysun/xray xray x25519)
PRIVKEY=$(echo "$KEYS" | grep -i 'PrivateKey' | awk '{print $2}')
PUBKEY=$(echo "$KEYS" | grep -i 'Password' | awk '{print $2}')
if [[ -z "$PRIVKEY" || -z "$PUBKEY" ]]; then
  echo "Key generation failed, please run: docker run --rm teddysun/xray xray x25519"
  exit 1
fi
echo "Reality PrivateKey: $PRIVKEY"
echo "Reality Client PublicKey: $PUBKEY"

# 3. Parameters
SHORTID="7b0390ce"
CAMO_DOMAIN="www.bing.com"
DEST_DOMAIN="${CAMO_DOMAIN}:443"
PORT=8443 # Listen port, IPv4 only

SERVER_IP=$(curl -4s api.ip.sb/ip || echo "YOUR_IPV4")

# 4. Generate config.json for Xray Reality
cat > config.json <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/dev/stdout",
    "error": "/dev/stderr"
  },
  "inbounds": [
    {
      "port": $PORT,
      "listen": "0.0.0.0",
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
          "dest": "$DEST_DOMAIN",
          "xver": 0,
          "serverNames": [
            "$CAMO_DOMAIN"
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

echo "Xray config.json generated (listening on IPv4, port $PORT for VLESS+XTLS+Reality)."

# 5. Run Docker container
docker pull teddysun/xray
docker stop xray-reality 2>/dev/null || true
docker rm xray-reality 2>/dev/null || true
docker run -d --name xray-reality \
  -v "$WORKDIR/config.json:/etc/xray/config.json:ro" \
  -p $PORT:$PORT \
  teddysun/xray

echo "Xray VLESS+XTLS+Reality (IPv4 only) is up on $SERVER_IP:$PORT"

# 6. Generate client JSON config and subscribe URL
cat > client_config.json <<EOF
{
  "v": "2",
  "ps": "$CAMO_DOMAIN-reality",
  "add": "$SERVER_IP",
  "port": "$PORT",
  "id": "$UUID",
  "aid": "0",
  "scy": "",
  "net": "tcp",
  "type": "",
  "host": "$CAMO_DOMAIN",
  "path": "",
  "tls": "",
  "sni": "$CAMO_DOMAIN",
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

SUB_URL="vless://$UUID@$SERVER_IP:$PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$CAMO_DOMAIN&fp=chrome&pbk=$PUBKEY&sid=$SHORTID&type=tcp&host=$CAMO_DOMAIN#$CAMO_DOMAIN-reality"

echo ""
echo "-----------------------------"
echo "Deployment finished!"
echo ""
echo "Camouflage domain (SNI/dest/serverName): $CAMO_DOMAIN"
echo "UUID: $UUID"
echo "Reality Client PublicKey: $PUBKEY"
echo "ShortID: $SHORTID"
echo ""
echo "---- Subscribe URL ----"
echo "$SUB_URL"
echo ""
echo "---- Client JSON ----"
cat client_config.json
echo ""
echo "Open port $PORT (TCP) on your firewall if needed."
echo "To check logs: docker logs xray-reality"
echo "To stop:       docker stop xray-reality"
echo "To remove:     docker rm xray-reality"
echo "-----------------------------"

