# must do after get your vps

---

## 1. add a new user & root ssh forbidden

1. Create a New User:
   Replace `newuser` with the username you want.
   bash
   `adduser vv`

   Set a password when prompted.

2. Give the New User Sudo Privileges:
   bash
   `usermod -aG sudo vv`

   Now `newuser` can use sudo for admin tasks.

3. Copy SSH Authorization (Optional, recommended for key-based login):
   If you use SSH keys, copy your authorized_keys:
   bash
   `rsync --archive --chown=vv:vv ~/.ssh /home/vv`

4. Edit SSH Config to Forbid Root Login:
   Open the SSH config file:
   bash
   `nano /etc/ssh/sshd_config`

   Find the line:

   `PermitRootLogin yes`

   Change it to:

   `PermitRootLogin no`

   Save the file (Ctrl+X, then Y, then Enter).

5. Restart the SSH Service:
   bash
   `sudo systemctl restart sshd & sudo systemctl status sshd`

   (On some systems, use `service ssh restart` instead.)

6. Test New User SSH:  
   Open a new terminal and log in:
   bash
   ssh user@<your vps ip>

   Ensure it works before logging out as root!

Now, root login for SSH is forbidden, and you have a new user with sudo rights for SSH and telnet access. If you need a step-by-step for key authentication or any specific OS instructions, just let me know!

---

## 2. sudo without passwd

to allow your user to use sudo without entering a password, you need to update the sudoers file with the correct rule.

Here’s how you can set it up:

1. Log in as root or use `sudo` with your existing user.

2. Edit the sudoers file safely (recommended):
   bash
   `visudo`

   This opens the sudoers file with syntax checking.

3. Add this line at the end, replacing `newuser` with your actual username:

   `vv ALL=(ALL) NOPASSWD:ALL`

   - This allows `newuser` to run any command with sudo without a password.

4. Save and exit (for nano: Ctrl+X, then Y, then Enter).

Now, next time you use sudo with this user, you won’t be prompted for a password.

vc, if your system uses groups (the `sudo` group, for example), and you want all users in that group to have passwordless sudo, you can add:

`%sudo ALL=(ALL) NOPASSWD:ALL`

---

## 3. add Swap mem

here’s a clear step-by-step guide to set up a 1G swap file on your Linux VPS.

1. Create a swap file (1GB):
   bash
   `sudo fallocate -l 1G /swapfile`

   If `fallocate` isn’t available, use:
   bash
   `sudo dd if=/dev/zero of=/swapfile bs=1M count=1024`

2. Set correct permissions:
   bash
   `sudo chmod 600 /swapfile`

3. Set up the swap area:
   bash
   `sudo mkswap /swapfile`

4. Enable the swap file:
   bash
   `sudo swapon /swapfile`

5. Make the swap file permanent (add to /etc/fstab):
   Add this line to the end of `/etc/fstab`:

   `/swapfile none swap sw 0 0`

   You can do it with:
   bash
   `echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab`

6. Verify swap is active:
   bash
   `sudo swapon --show`
   free -h

If you see `/swapfile` listed and about 1.0G swap available in `free -h`, it’s all set! 

---

## 4. install docker

here is a simple step-by-step guide to install Docker on your Ubuntu server.

1. Update your system:
   bash
   `sudo apt update`
   `sudo apt upgrade -y`

2. Install necessary packages:
   bash
   `sudo apt install -y ca-certificates curl gnupg lsb-release`

3. Add Docker’s official GPG key:
   bash
   `sudo install -m 0755 -d /etc/apt/keyrings`
   `curl -fsSL download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg`

4. Set up the Docker repository:
   bash
   `e`cho \`
     `"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] download.docker.com/linux/ubuntu \`
     `$(lsb_release -cs) stable" | \`
     sudo tee /etc/apt/sources.list.d/docker.list > /dev/null`

5. Install Docker Engine:
   bash
   `sudo apt update`
   `sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`

6. Start and enable Docker:
   bash
   `sudo systemctl start docker`
   `sudo systemctl enable docker`

7. Test Docker installation:
   bash
   `sudo docker run hello-world`

If you see a "Hello from Docker!" message, everything is installed correctly.  
Let me know if you encounter any errors or need extra help at any step, vv—I’m here to assist you.

---

 if you see the “docker-default AppArmor is not found” error, it usually means AppArmor is not installed or enabled on your Ubuntu system.Here’s how to resolve this and ensure Docker's security profile works as expected:

1. Check if AppArmor is installed:
   bash
   `sudo apparmor_status`

   If you get a "command not found" or AppArmor is not loaded, continue below.

2. Install AppArmor and its utilities:
   bash
   `sudo apt update`
   `sudo apt install -y apparmor apparmor-utils`

3. Enable and start AppArmor:
   bash
   `sudo systemctl enable apparmor`
   `sudo systemctl start apparmor`

4. Reload Docker (to reapply security profiles):
   bash
   `sudo systemctl restart docker`

5. Test Docker again:
   Try running your Docker command or container once more.

Note:  
If you’re running a minimal VPS image or a custom kernel that does not support AppArmor (for example, some lightweight images), Docker should still work, but you’ll see warnings about security profiles. These can usually be ignored for personal/test use, but for the best security and full Docker features, using AppArmor is recommended.







