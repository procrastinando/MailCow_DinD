#!/bin/bash

# --- Configuration ---
# !! IMPORTANT !!
# UPDATE this path to match the certificate directory you found earlier.
SOURCE_CERT_DIR="/npm-letsencrypt/live/npm-1/"

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