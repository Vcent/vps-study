# Solid your vps

Combining cloudflared (Cloudflare Tunnel) with V2Ray VLESS over TLS (HTTPS) is one of the most effective ways to accelerate your servers, hide your real VPS IP, and bypass strict network policies.

## Here’s what this setup gives you:

- Cloudflared (Cloudflare Tunnel):  
  - Hides your VPS from direct exposure—clients only see a Cloudflare address, not your real IP.
  - Accelerates traffic through Cloudflare’s global network, providing better speed and stability.
  - Adds an extra security layer, protecting your infrastructure from direct attacks.
- V2Ray VLESS over TLS/HTTPS (WebSocket):  
  - Masks VPN/proxy traffic as normal secure web traffic (HTTPS), making it nearly impossible for censorship systems to identify or block it.
  - The VLESS protocol is modern, fast, and highly resistant to deep packet inspection (DPI).
  - Using port 443 (standard HTTPS) ensures connections blend in with regular web browsing.

## How to set it up:

1. Deploy a VPS with the XRay or V2Ray template from your JustHost.asia account.
2. Register a real domain and set it up in Cloudflare.
3. Install cloudflared on your VPS and create a Cloudflare Tunnel—the tunnel endpoint will be your WebSocket (e.g., `wss://yourdomain.com/ws`).
4. In your V2Ray/XRay config:
   - Transport: WebSocket
   - Protocol: VLESS
   - TLS: Enabled
   - Path: `/ws` or similar
   - Port: 443
   - Point your WebSocket host to the Cloudflare Tunnel URL.
5. On the client side, use the same config (protocol VLESS, transport WebSocket, TLS, port 443, and your domain as server address).

Extra tip: Only allow Cloudflare proxy IPs to access your VPS (block all other inbound public connections at the firewall) for maximum security.
