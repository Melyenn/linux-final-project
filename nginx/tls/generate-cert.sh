#!/bin/bash
set -euo pipefail

DOMAIN="app.lab.local"
SSL_DIR="/etc/nginx/ssl"

mkdir -p "$SSL_DIR"

openssl req \
  -x509 \
  -nodes \
  -newkey rsa:2048 \
  -days 365 \
  -keyout "$SSL_DIR/$DOMAIN.key" \
  -out "$SSL_DIR/$DOMAIN.crt" \
  -subj "/C=VN/ST=HCM/L=HCM/O=LinuxFinalProject/OU=Web/CN=$DOMAIN" \
  -addext "subjectAltName=DNS:$DOMAIN"

chmod 600 "$SSL_DIR/$DOMAIN.key"
chmod 644 "$SSL_DIR/$DOMAIN.crt"

echo "Created TLS certificate for $DOMAIN"
