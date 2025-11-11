# v2ray with VLESS + WS + TLS

Here’s your tailored step-by-step guide for maximum-security deployment:

---

### 1. Prepare system and Docker (if not done):

bash

```shell
sudo apt update
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker
```


---

### 2. Get a UUID for client authentication:

bash

```shell
sudo apt install -y uuid-runtime
uuidgen
```

Keep this UUID for your client later.

---

### 3. Obtain a TLS certificate (Let’s Encrypt example):

Install certbot and get a certificate (your domain must point to your server’s IP):
bash

```shell
sudo apt install -y certbot
sudo certbot certonly --standalone -d <your domain>
```

- Your certs will be at `/etc/letsencrypt/live/<your domain>ullchain.pem` and `/etc/letsencrypt/live/<your domain>/privkey.pem`

- certbot 安装默认会自动更新，否则就加入 contable

  ```bash
  root@r1065313:/home/vv# openssl s_client -connect localhost:443 -servername cdn.vcmario.dpdns.org 2>/dev/null | openssl x509 -noout -dates
  notBefore=Nov 10 12:19:59 2025 GMT
  notAfter=Feb  8 12:19:58 2026 GMT
  root@r1065313:/home/vv# sudo systemctl list-timers | grep certbot
  Tue 2025-11-11 01:13:35 UTC 10h left      n/a                         n/a    certbot.timer                certbot.service
  
  0 */12 * * * root test -x /usr/bin/certbot -a \! -d /run/systemd/system && perl -e 'sleep int(rand(43200))' && certbot -q renew
   
  sudo certbot renew --dry-run @测试续期
  ```

- 查看证书有效期

- ```bash
  openssl s_client -connect localhost:443 -servername <your domain> 2>/dev/null | openssl x509 -noout -dates
  ```


---

### 4. Create V2Ray config with VLESS + WS + TLS:

```shell
bash
mkdir -p ~/v2ray
cd ~/v2ray
nano config.json

Paste the following (replace UUID and paths):
json
{
  "inbounds": [{
    "port": 443,
    "protocol": "vless",
    "settings": {
      "clients": [{
        "id": "<your uuid>",
        "level": 0,
        "email": "user@vless"
      }],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": {
        "path": "/vless"
      },
      "security": "tls",
      "tlsSettings": {
        "certificates": [{
          "certificateFile": "/etc/letsencrypt/live/<your domain>/fullchain.pem",
          "keyFile": "/etc/letsencrypt/live/<your domain>/privkey.pem"
        }]
      }
    }
  }],
  "outbounds": [{
    "protocol": "freedom"
  }]
}
```

- Replace `"YOUR-GENERATED-UUID"` with the one you created above.
- You can adjust the `"path"` if you prefer (just stay consistent for client config).

---

### 5. Run V2Ray with Docker:

```shell
bash
sudo docker run -d \
  --name v2ray-vless-ws-tls \
  -v $(PWD)/v2ray/config.json:/etc/v2ray/config.json \
  -v /etc/letsencrypt:/etc/letsencrypt:ro \
  -p 443:443 \
  v2fly/v2fly-core:v4.27.0
```


---

### 6. Configure your client (example for V2RayN, Shadowrocket, or Qv2ray):

- Protocol: VLESS
- Address: ray.vcmario.dpdns.org
- Port: 443
- UUID: <your uuid>
- Encryption/Flow: none
- Transport: WebSocket
- WebSocket Path: /vless
- TLS: enabled
- SNI/Server Name: <your domain>

---

Important notes for security:

- Never share your UUID publicly.
- Always keep your certificate up to date for uninterrupted TLS.

# v2Ray QR gen

### 1. Construct your VLESS URI

Use the following format (replace capitalized values with your actual config):

```url
vless://<your uuid>@<your domain>:443?encryption=none&security=tls&type=ws&host=<your domain>&path=%2Fvless#YourLabel
```

- `UUID` — your actual UUID
- `xxxx.dpdns.org` — your domain
- `443` — port
- `path=%2Fvless` — URL-encoded path, replace if you set a different path in config
- `YourLabel` — optional, just a name for easy identification

Example:

```url
vless://xxxx-xxxx-xxxx-bfee-xxxx@xxxx.dpdns.org:443?encryption=none&security=tls&type=ws&host=xxxx.dpdns.org&path=%2Fvless#RayVLESS
```


---

### 2. Generate the QR Code

- Visit a QR code generator that supports long text/URI, such as www.qr-code-generator.com/ or cli.im/text.
- Paste your full VLESS URI (from above) into the generator.
- Click “Generate QR Code” and download or display the image.

---

### 3. Import the QR in your client app

On iOS (Shadowrocket, Kitsunebi, or other):

- Open the app.
- Tap “+” for a new server or find “Scan QR Code” option.
- Point your camera at the generated QR code on your screen.
- Confirm import; all server info will fill automatically.

On Android (v2rayNG, Clash, etc.):

- Usually tap the “+” > “Scan QR code” and follow the same process.

# v2Ray webui

vv, the official V2Ray core does not come with a built-in web UI, but there are several popular community projects that provide a web control panel for managing V2Ray and Xray servers.

If you want a web-based interface for easy configuration and user management, here are the most common options you can run on Ubuntu (many also support Docker):

1. V2Board:  

   - A feature-rich web panel for managing V2Ray/Xray servers, user accounts, subscriptions, traffic, and more.
   - Best for multi-user and commercial use.
   - Open source: github.com/v2board/v2board

2. Sspanel-Uim / Sspanel / alike:  

   - Classic web UIs originally created for Shadowsocks, many have been updated to support V2Ray/Xray and VLESS protocols.

3. X-UI:  

   - A modern, lightweight web panel with support for V2Ray/Xray, VLESS, VMess, Trojan, and Shadowsocks.

   - Easy installation with Docker:
     bash

   - ```shell
     sudo docker run -d --name x-ui --restart=always \
     -p 54321:54321 -p 443:443 \
     --privileged=true \
     --network=host \
     enwaiax/x-ui
     ```

   - Details and setup: https://hub.docker.com/r/enwaiax/x-ui

     - http://ss.vcmario.dpdns.org:54321/xui/
       - sudo docker exec -it x-ui
         - x-ui setting -username admino -password marion@2025
           - mario:mario@2025
           - admin:mario@2025

4. 3x-ui:  

   - Similar to x-ui but with enhanced features and an active developer community.
   - github.com/MHSanaei/3x-ui

Summary for your needs: 
If you want a quick, all-in-one web panel, I recommend starting with x-ui or 3x-ui—both support VLESS/V2Ray and are straightforward to install and use on Ubuntu and Docker.

If you need a full-feature commercial-grade system (with payment, subscription management, analytics), consider V2Board.

