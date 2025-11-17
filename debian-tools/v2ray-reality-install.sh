#!/bin/bash

# V2Ray+XTLS+Reality Docker auto-deploy script
set -e

# Step 1: Prepare directory
WORKDIR=/home/root/v2ray-reality
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Step 2: Generate UUID
UUID=$(cat /proc/sys/kernel/random/uuid)
echo "Generated UUID: $UUID"

# Step 3: Generate Reality keypair
echo "Generating Reality private/public key via Docker..."
REA_KEYS=$(docker run --rm v2fly/v2fly-core:v4.27.0 xray x25519)
PRIVKEY=$(echo "$REA_KEYS" | grep 'Private key' | awk '{print $3}')
PUBKEY=$(echo "$REA_KEYS" | grep 'Public key' | awk '{print $3}')
echo "Reality Private key: $PRIVKEY"
echo "Reality Public key (give this to your client): $PUBKEY"

# Step 4: Use fixed shortId, can randomize if you prefer
SHORTID="7b0390ce"

# Step 5: Create config.json
cat > config.json <<EOF
{
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
          "dest": "cloudflare.com:443",
          "xver": 0,
          "serverNames": [
            "cloudflare.com"
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

echo "Config file generated at $WORKDIR/config.json."

# Step 6: Pull and run the Docker container
echo "Pulling Docker image..."
docker pull v2fly/v2fly-core:v4.27.0

echo "Launching V2Ray Reality container (listen on port 443)..."
docker run -d --name v2ray-reality -p 443:443 -v "$WORKDIR/config.json:/etc/v2ray/config.json:ro" v2fly/v2fly-core:v4.27.0

echo ""
echo "--------- Deployment Complete ---------"
echo "UUID: $UUID"
echo "Reality Public key: $PUBKEY"
echo "ShortID: $SHORTID"
echo "SNI/ServerName: cloudflare.com"
echo ""
echo "Client config: use your VPS IP, port 443, UUID above, flow xtls-rprx-vision, Security=reality, PublicKey above, ShortID $SHORTID, SNI cloudflare.com"
echo "Check logs: docker logs v2ray-reality"
echo "To stop:    docker stop v2ray-reality"
echo "To remove:  docker rm v2ray-reality"
echo ""
echo "If you need to open firewall port 443 (for nftables):"
echo "sudo nft add rule inet filter input tcp dport 443 accept; sudo nft -f /etc/nftables.conf"

### Add to Your Script: Generate Client Config and Subscription UR
# Set your server IP or domain here
SERVER_IP=www.mario8.dpdns.org # Or set manually: SERVER_IP=your.vps.ip.or.domain

# Create Client config JSON (for export/import, SagerNet, sing-box, etc.)
cat > client_config.json <<EOF
{
  "v": "2",
  "ps": "vless-reality-demo",
  "add": "$SERVER_IP",
  "port": "443",
  "id": "$UUID",
  "aid": "0",
  "scy": "",
  "net": "tcp",
  "type": "",
  "host": "cloudflare.com",
  "path": "",
  "tls": "",
  "sni": "cloudflare.com",
  "alpn": "",
  "fp": "",
  "allowInsecure": false,
  "flow": "xtls-rprx-vision",
  "protocol": "vless",
  "security": "reality",
  "pbk": "$PUBKEY",
  "sid": "$SHORTID"
}
EOF

# Create VLESS Reality subscribe URL (for v2rayN, Clash Meta, etc.)
SUB_URL="vless://$UUID@$SERVER_IP:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=cloudflare.com&fp=chrome&pbk=$PUBKEY&sid=$SHORTID&type=tcp&host=cloudflare.com#vless-reality-demo"

echo ""
echo "--------- Client Configs ---------"
echo "Client config (client_config.json):"
cat client_config.json
echo ""
echo "Subscribe URL:"
echo $SUB_URL
echo ""

