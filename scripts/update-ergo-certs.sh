#!/bin/bash

# Script to copy Let's Encrypt certificates from Caddy to Ergo
# This script should be run after Caddy obtains or renews certificates

set -e

HOSTNAME="$1"
if [ -z "$HOSTNAME" ]; then
    echo "Usage: $0 <hostname>"
    exit 1
fi

# Caddy certificate paths
CADDY_CERT_DIR="/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory"
CADDY_CERT_PATH="$CADDY_CERT_DIR/$HOSTNAME"

# Ergo certificate directory
ERGO_CERT_DIR="/opt/ergo/certs"

# Create Ergo cert directory if it doesn't exist
mkdir -p "$ERGO_CERT_DIR"

# Function to copy certificates if they exist
copy_certificates() {
    if [ -f "$CADDY_CERT_PATH/$HOSTNAME.crt" ] && [ -f "$CADDY_CERT_PATH/$HOSTNAME.key" ]; then
        echo "Copying Let's Encrypt certificates from Caddy to Ergo..."
        
        # Copy certificates
        cp "$CADDY_CERT_PATH/$HOSTNAME.crt" "$ERGO_CERT_DIR/server.crt"
        cp "$CADDY_CERT_PATH/$HOSTNAME.key" "$ERGO_CERT_DIR/server.key"
        
        # Set correct ownership and permissions
        chown ergo:ergo "$ERGO_CERT_DIR/server.crt" "$ERGO_CERT_DIR/server.key"
        chmod 644 "$ERGO_CERT_DIR/server.crt"
        chmod 600 "$ERGO_CERT_DIR/server.key"
        
        echo "✅ Certificates copied successfully!"
        return 0
    else
        echo "⚠️ Let's Encrypt certificates not found at $CADDY_CERT_PATH"
        return 1
    fi
}

# Function to generate fallback self-signed certificates
generate_fallback_certs() {
    echo "Generating fallback self-signed certificates for Ergo..."
    cd /opt/ergo
    
    # Generate self-signed certificate as fallback
    openssl req -x509 -newkey rsa:4096 -keyout "$ERGO_CERT_DIR/server.key" -out "$ERGO_CERT_DIR/server.crt" \
        -days 365 -nodes -subj "/CN=$HOSTNAME"
    
    # Set correct ownership and permissions
    chown ergo:ergo "$ERGO_CERT_DIR/server.crt" "$ERGO_CERT_DIR/server.key"
    chmod 644 "$ERGO_CERT_DIR/server.crt"
    chmod 600 "$ERGO_CERT_DIR/server.key"
    
    echo "✅ Fallback certificates generated!"
}

# Try to copy Let's Encrypt certificates, fallback to self-signed if not available
if ! copy_certificates; then
    generate_fallback_certs
fi

echo "Certificate update complete!"
echo "Note: Ergo needs to be restarted manually to pick up new certificates."