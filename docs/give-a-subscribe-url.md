# How to make a subscribe in Shadowrocket ?

## Do a subscribe URL

To provide a subscription URL for Shadowrocket, you need to generate and host a “subscription” (sub) link containing your V2Ray, VLESS, or Shadowsocks server configuration in a compatible format.

Here’s how you can do this:

### 1. Prepare Your Configuration (V2Ray, VLESS, or Shadowsocks)
- Write your server config(s) in the “Clash” or “Quantumult X/Shadowrocket” YAML format, or prepare multiple single-line links if using just VMess/VLESS SS URLs.

### 2. Create the Subscription File
- Place the config file (for example, `sub.txt` or `sub.yaml`) on a public web server, your VPS web directory, or a GitHub Gist (as a raw link).
- The file can contain:
  - Multiple single-line links, each for one server (VMess, VLESS, SS, Trojan, etc.).
  - Or, for advanced usage, the full YAML format supporting nodes and rules.

Simple example of a subscription file (sub.txt):

vmess://base64-encoded-config1
vmess://base64-encoded-config2
ss://base64-encoded-config3

Or as YAML for Clash/Shadowrocket advanced subscriptions.

### 3. Host the File Publicly
- Upload to your VPS’s web server (e.g., `https://yourdomain.com/sub.txt`)
- Or save as a Gist/raw on GitHub (e.g., `https://gist.githubusercontent.com/username/raw/xxx/sub.txt`)
- Or use a paste/share service with direct/raw output (be careful with privacy).

### 4. Share the Subscription Link
- In Shadowrocket, go to “Subscribe” > “Add Subscription” and paste your URL (e.g., `https://yourdomain.com/sub.txt`).
- Now any changes you make to the file are updated automatically in the app for all users who have subscribed to that URL.

## Protect Node

To protect your node subscription txt file (such as ssrsub.txt) from leaks and unauthorized access, you should secure both the server and the file itself using several effective strategies.

Here’s how you can prevent your node txt from leaking:

### 1. Password Protection (HTTP Basic Auth)
- Configure your web server (Nginx or Apache) to require a username and password for access to the subscription file.
- In Nginx, add:
  
  location /ssrsub.txt {
      auth_basic "Restricted";
      auth_basic_user_file /etc/nginx/.htpasswd;
  }
  
  Use `htpasswd` to generate user/password pairs.

### 2. IP Whitelisting
- Limit access to the file based on client IP addresses. Only trusted users’ IPs are allowed.
- In Nginx:
  
  location /ssrsub.txt {
      allow 1.2.3.4;
      allow 5.6.7.8;
      deny all;
  }
  

### 3. Private Hosting (Tokenized or Temporary URLs)
- Host the file on a backend or cloud with time-limited, token-based links—only users with a valid token can fetch it, and the link expires after use.

### 4. Encrypt or Obfuscate the File
- Before upload, encrypt the file and share the decryption key securely to authorized users.
- Alternatively, use a backend script that verifies the user and generates the txt dynamically for each request.

### 5. Monitor Access Logs
- Regularly check your server logs for unusual or unauthorized requests and rotate credentials if suspicious activity is detected.

### 6. Share Privately
- Never post your subscription URL in public places, forums, or social media.
- Distribute only to users you trust via secure channels (like encrypted messengers or email).

## URL Rotate

Rotating the subscription URL file means changing its URL periodically to prevent unauthorized sharing and access, increasing your nodes' security.

Here's how you can rotate your subscription file URL step by step:

### 1. Change the Filename or Path Regularly
- Rename your subscription file (for example, from `ssrsub1.txt` to `ssrsubX.txt` or use a randomized string, e.g., `ssrsub-20240612-abc123.txt`).
- Move it to a different directory or subfolder on your server (e.g., from `/public/` to `/private/`).

### 2. Update the Access URL for Your Users
- Each time you rotate, share the new subscription link with trusted users only.
- Ask users to update their subscription in their respective SSR/Shadowrocket clients to the new URL.
- Immediately delete or restrict access to the old URL or file.

### 3. Automate with Scripts (Optional)
- Write a small script that creates a new file or copies to a new random filename, updates permissions, and cleans up old files.
- Example Bash steps:
  bash
  NEWURL="ssrsub-$(date +%Y%m%d-%s).txt"
  cp ssrsub.txt /var/www/html/$NEWURL
  
  Remove or archive old files
  
  find /var/www/html/ -name "ssrsub-*.txt" -mtime +7 -exec rm {} \;
  

### 4. Use Short-Link or Token Service (Extra Security)
- Serve the subscription file via a script that generates a new random token link at each interval (daily/weekly).
- Share only the fresh short-link with users (e.g., `https://yourdomain.com/getsub?token=abc123`).
- Invalidate old tokens automatically.

### 5. Notify Users to Refresh
- Notify your trusted users on each rotation so they can update their clients quickly.
- Encourage using secure/private communication channels for sending new links.

---

## Node Rotate

You are correct—if a user downloads and saves a node’s connection config (SSR, V2Ray, etc.), that config will keep working as long as the server itself is online and the node details (IP, port, password, etc.) stay unchanged, regardless of any subscription URL rotation.

Here’s why and what you can do about it:

- Once the node info is imported, the app connects directly to your node using saved credentials. Subscription URL rotation only controls access to future config updates, not the usable lifespan of an already-downloaded node.
- If you want to truly “expire” or disable old configs, you need to take action on the server side. Consider these methods:
  - Change the node password or port: Immediately invalidates old configs. Only users with the updated subscription will stay connected.
  - Stop or reconfigure the node: Disable or remove the SSR/XRay instance whose info was leaked or is no longer authorized.
  - Automate credential changes: Use scripting or management panels to regularly rotate passwords/ports and update your subscription txt. Users must refresh their subscription to stay connected.
  - Monitor and block by user/IP: Track connections and block unauthorized or suspicious IPs.

The key point:  
Rotating the subscription URL increases control, but true access management always depends on changing the underlying server configuration. If permanent access expiration is needed, automate server-side changes—client configs that aren’t updated will stop working.

## A webui to do this

For easy web-based management of node accounts (create, disable, change passwords, rotate, and generate subscriptions), I recommend using a specialized WebUI panel for your proxy type.

Here are top choices depending on your backend:

### For XRay/V2Ray:
- X-UI (most popular, feature-rich, open source)
  - Manage accounts, ports, passwords, protocols (VLESS, VMess), expiration, and subscription links—all from a browser.
  - Automates config rotation and creates subscription URLs compatible with most clients.
  - Repository: [github.com/X-UI-Panel/X-UI](github.com/X-UI-Panel/X-UI)

- Soga
  - Multi-protocol, supports more advanced user control including traffic quotas and expiration.
  - [github.com/sprov065/soga](github.com/sprov065/soga)

### For ShadowsocksR (SSR):
- SSRPanel (and its forks)
  - Full-feature web management, supports SSR/SS/VMess/Trojan, and automated subscription link generation.
  - [github.com/Anankke/SSPanel-Uim](github.com/Anankke/SSPanel-Uim)

### For 3x-ui (multi-protocol, user-friendly):
- 3x-ui
  - Simple, fast XRay/V2Ray WebUI for personal or small organizational use.
  - Easy subscription, user/account management, and traffic stats.
  - [github.com/MHSanaei/3x-ui](github.com/MHSanaei/3x-ui)