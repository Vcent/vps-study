# Mask-your-vps

In strict network environments, masking VPN or proxy protocols as HTTPS over WebSocket is one of the most effective methods to bypass detection and filtering.

For your use case, here’s what I recommend and how you can set it up:

### 1. Use V2Ray (or XRay) with WebSocket + TLS (HTTPS)
- V2Ray/XRay allows you to run the VMess or VLESS protocols over WebSocket, and then secure this traffic with TLS encryption—making all VPN/proxy data look like regular HTTPS WebSocket browsing.
- This approach is highly resistant to deep packet inspection (DPI) and is much less likely to be identified or blocked.

### 2. Deployment Steps
- When deploying your VPS at JustHost.asia, select the V2Ray or XRay template.
- In the configuration, set:
  - Transport protocol: WebSocket (ws)
  - TLS: Enabled (get an SSL certificate via Let’s Encrypt or Cloudflare)
  - Port: 443 (standard HTTPS) for best camouflage
  - Path: e.g., `/ws` (configurable to anything)
- Set your domain to point to your VPS IP, and (optionally) use Cloudflare proxy to add another obfuscation layer and extra protection.

### 3. On the Client Side
- Use a compatible client (v2rayN, NekoRay, v2rayNG, Shadowrocket, etc.) and import your server config.
- Make sure:
  - Protocol: VMess or VLESS
  - Transport: WebSocket
  - TLS: Yes (tick “Enable TLS” or similar)
  - Port: 443

### 4. Extra Tips
- You can use Cloudflared (Cloudflare Tunnel) for even more advanced masking, routing WebSocket traffic completely inside Cloudflare’s protected network—no direct IP exposure.
- Always use a real domain with a valid SSL certificate for the best results.
- Regularly test connectivity from different networks to ensure stability and stealth.

