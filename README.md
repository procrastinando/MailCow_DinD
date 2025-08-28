# How to Install Mailcow behind Nginx Proxy Manager using a Docker Controller

This guide will walk you through installing Mailcow on a server that already uses Nginx Proxy Manager (NPM). We will use a dedicated "controller" container. This controller will manage the Mailcow installation on the host, providing security and avoiding having a `mailcow-dockerized` directory which contains very important data that is visible to the cloud computing provider.

---

### 1. Requirements

Before you begin, ensure you have the following:

**1.1. Infrastructure:**
*   A domain (e.g., `domain.org`).
*   A hostname for your mail server (e.g., `mail.domain.org`).
*   A server with a public static IP address (e.g., `123.123.123.123`).
*   Docker and Docker Compose installed: `curl -fsSL https://get.docker.com | sudo sh && apt install git -y`

**1.2. Open Ports:**
Ensure the following ports are open in your server's firewall:
*   **For Nginx Proxy Manager**: `80` (HTTP), `443` (HTTPS), `81` (NPM Admin UI).
*   **For Mailcow**: `25` (SMTP), `587` (Submission), `993` (IMAPS).
*   **Optional Mailcow Ports**: `465` (SMTPS), `995` (POP3S), `4190` (Sieve).

**1.3. DNS and Port 25 Check:**
*   **Reverse DNS (PTR)**: In your VPS provider's control panel, set the Reverse DNS for your server's IP to your mail hostname (`mail.domain.org`). This is crucial for email deliverability.
*   **Port 25 Access**: Verify that your provider does not block outbound traffic on port 25. You can check this with the command: `telnet gmail-smtp-in.l.google.com 25`. You should see a `220` response code.

---

### 2. Nginx Proxy Manager (NPM) Setup

If you don't have NPM installed, deploy it using the following `docker-compose-npm.yaml`:

```yaml
services:
  npm:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: npm
    restart: unless-stopped
    ports:
      - '80:80'
      - '443:443'
      - '81:81'
    volumes:
      - npm-data:/data
      - npm-letsencrypt:/etc/letsencrypt
    networks:
      - npm-network

volumes:
  npm-data:
    name: npm-data
  npm-letsencrypt:
    name: npm_letsencrypt

networks:
  npm-network:
    name: npm-network
```

1.  Run `docker compose up -d` to deploy it.
2.  Access the web UI at `http://123.123.123.123:81`.
3.  Log in with the default credentials (`admin@example.com` / `changeme`) and complete the setup.
4.  Navigate to **Hosts > Proxy Hosts** and click **Add Proxy Host**.
5.  Configure the proxy host for Mailcow:
    *   **Domain Names**: `mail.domain.org`
    *   **Scheme**: `http`
    *   **Forward Hostname / IP**: `123.123.123.123`
    *   **Forward Port**: `8080` *(We will configure Mailcow to use this port later)*
6.  Go to the **SSL** tab, select **Request a new SSL Certificate**, enable **Force SSL**, and click **Save**.

---

### 3. Deploying Mailcow with a Controller

We will create a simple Debian container whose only job is to manage the Mailcow installation.

**3.1. Create the Mailcow Controller Container**

Create a new `docker-compose.yml` file for the controller:

```yaml
services:
  debian:
    build:
      context: https://github.com/procrastinando/MailCow_DinD.git#main
    container_name: mailcow-controller
    privileged: true
    ports:
      - "25:25"
      - "8080:8080" # select the port that you prefer
      - "8443:8443" # select the port that you prefer
      - "587:587"
      - "993:993"
      - "465:465"
      - "995:995"
      - "4190:4190"
    command: /bin/sh -c "dockerd > /dev/null 2>&1 & sleep 2 && tail -f /dev/null"
    networks:
      - npm-network
    volumes:
      - mailcow:/mailcow-dockerized
      - docker:/var/lib/docker
      - npm-letsencrypt:/npm-letsencrypt

volumes:
  mailcow:
  docker:
  npm-letsencrypt:
    external: true

networks:
  npm-network:
    name: npm-network
    external: true
```

Run `docker compose up -d` to create the controller.

**3.2. Install and Configure Mailcow**

Now, we will use the controller to install Mailcow.

1.  Enter the controller container's shell:
    ```bash
    docker exec -it mailcow-controller /bin/bash
    ```

2.  (Inside the container) Clone the Mailcow repository. This only needs to be done once:
    ```bash
    git clone https://github.com/mailcow/mailcow-dockerized.git /mailcow-dockerized
    cd /mailcow-dockerized
    ```

3.  (Inside the container) Generate the configuration file:
    ```bash
    ./generate_config.sh
    ```
    When prompted, enter your mail hostname (`mail.domain.org`).

4.  (Inside the container) Edit `mailcow.conf` to work with our reverse proxy:
    ```bash
    nano mailcow.conf
    ```
    Make the following critical changes:
    ```ini
    # Bind the web interface to these non-standard ports on the HOST
    HTTP_PORT=8080
    HTTPS_PORT=8443

    # We use Nginx Proxy Manager for SSL, so disable Let's Encrypt in Mailcow
    SKIP_LETS_ENCRYPT=y
    ```
    Save the file (Ctrl+X, Y, Enter).

5.  (Inside the container) Pull the Mailcow images and deploy them:
    ```bash
    docker compose pull
    docker compose up -d
    ```
    Mailcow's containers will now start on the host, managed via the controller.

**3.3. Set Up Automatic Certificate Renewal**

This is the most important step for automation. We will create a script inside the controller that copies the certificate from NPM to Mailcow and then reloads its services.

1.  **Find your NPM Certificate Path**: First, identify the exact folder for your certificate. Run this command **on your host server**:
    ```bash
    # Replace the volume name if you changed it
    sudo ls -l $(docker volume inspect -f '{{.Mountpoint}}' npm-letsencrypt)/live/
    ```
    The output will show directories like `npm-1`, `npm-2`, etc. Note the correct one for `mail.domain.org`.

2.  **(Inside the container)** Create the renewal script:
    Enter to the container by:
    ```bash
    docker exec -it debian-docker /bin/bash
    ```
    Create a certificate renewal:
    ```bash
    nano /mailcow-dockerized/mailcow_cert_renewal.sh
    ```
    Copy and paste the entire script below. **Remember to change `npm-X` in the `SOURCE_CERT_DIR` variable to the directory you found in the previous step.**

    ```bash
    #!/bin/bash
    
    # --- Configuration ---
    # !! IMPORTANT !!
    # UPDATE this path to match the certificate directory you found earlier.
    SOURCE_CERT_DIR="/npm_letsencrypt/live/npm-1/"
    
    # Mailcow's SSL directory
    DEST_CERT_DIR="/mailcow-dockerized/data/assets/ssl/"
    # Path to your mailcow-dockerized directory
    MAILCOW_DIR="/mailcow-dockerized/"
    
    # --- Logic ---
    
    # 1. Copy the new certificates
    # The -L flag is important to dereference symbolic links
    echo "Copying certificates from ${SOURCE_CERT_DIR}..."
    cp -fvL "${SOURCE_CERT_DIR}fullchain.pem" "${DEST_CERT_DIR}cert.pem"
    cp -fvL "${SOURCE_CERT_DIR}privkey.pem" "${DEST_CERT_DIR}key.pem"
    
    # 2. Set correct permissions for Mailcow's containers
    chmod 644 "${DEST_CERT_DIR}cert.pem"
    chmod 640 "${DEST_CERT_DIR}key.pem"
    
    # 3. Reload services within Docker to apply the new certs
    echo "Reloading Mailcow services to apply new certificates..."
    cd "${MAILCOW_DIR}" || exit
    docker compose exec postfix-mailcow postfix reload
    docker compose exec dovecot-mailcow doveadm reload
    docker compose exec nginx-mailcow nginx -s reload
    
    echo "Certificate renewal process completed."
    ```

3.  (Inside the container) Make the script executable and run it once to confirm it works:
    ```bash
    chmod +x /mailcow-dockerized/mailcow_cert_renewal.sh
    ./mailcow-dockerized/mailcow_cert_renewal.sh
    ```

4.  (Inside the container) Create a cron job to run the script automatically. Run `crontab -e` and add the following line to run the script every Sunday at 3:30 AM:
    ```crontab
    30 3 * * 0 /mailcow-dockerized/mailcow_cert_renewal.sh > /mailcow-dockerized/mailcow_cert_renewal.log 2>&1
    ```

---

### 4. Set Up Your DNS Records

1.  Log in to the Mailcow UI at `https://mail.domain.org` with the default credentials (`admin` / `moohoo`).
2.  Navigate to **Email > Configuration** and add your domain (`domain.org`).
3.  After adding the domain, a **DNS** button will appear. Click it to see the exact records you need to add to your DNS provider (e.g., Cloudflare). They will include:
    *   **A Record** for `mail` pointing to `123.123.123.123`.
    *   **MX Record** for your root domain (`@` or `domain.org`) pointing to `mail.domain.org`.
    *   **TXT Records** for SPF and DMARC.
    *   **A `dkim._domainkey` TXT Record**.
    *   CNAME records for autoconfig and autodiscover.

---

### 5. Final Steps

You now have a fully functional mail server! Be sure to:
1.  **Change the admin password** in the Mailcow UI.
2.  Create your first user mailbox.
3.  Configure your email client (e.g., Thunderbird, Outlook) using the details provided by Mailcow.

Your setup is now complete, secure, and easy to maintain.
