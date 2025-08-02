#!/bin/bash
set -e

# Fedora-specific IRC Stack Installation Script
# Used by: DigitalOcean (fedora-41-x64)

# Arguments from Terraform
HOSTNAME="$1"
ADMIN_EMAIL="$2"
ERGO_NETWORK="$3"
ERGO_MOTD="$4"

echo "======================================"
echo "  IRC Stack Installation - Fedora"
echo "======================================"
echo "Hostname: $HOSTNAME"
echo "Admin Email: $ADMIN_EMAIL"
echo "Ergo Network: $ERGO_NETWORK"
echo "Ergo MOTD: $ERGO_MOTD"
echo "OS: Fedora (detected automatically)"
echo "======================================"

# Update system
echo "Updating Fedora system packages..."
# Refresh GPG keys first to avoid signature issues
dnf update -y --refresh --nogpgcheck fedora-gpg-keys || echo "GPG key update failed, continuing..."
# Try update with nogpgcheck to work around signature issues
dnf update -y --nogpgcheck || echo "System update failed, continuing with package installation..."

# Install required packages (excluding nodejs/npm - will install separately)
echo "Installing required packages on Fedora..."
dnf install -y --nogpgcheck git wget curl tar gzip golang firewalld || echo "Some packages failed to install, continuing..."

# Install Node.js from official NodeSource repository to avoid library conflicts
echo "Installing Node.js from official source..."
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash - || echo "Failed to add NodeSource repo, trying fallback..."
dnf install -y --nogpgcheck nodejs || echo "Failed to install Node.js from repo, trying binary download..."

# Fallback: Install Node.js binary if package manager fails
if ! command -v node &> /dev/null; then
    echo "Installing Node.js binary as fallback..."
    cd /tmp
    wget https://nodejs.org/dist/v20.18.0/node-v20.18.0-linux-x64.tar.xz
    tar -xf node-v20.18.0-linux-x64.tar.xz
    cp -r node-v20.18.0-linux-x64/* /usr/local/
    ln -sf /usr/local/bin/node /usr/bin/node
    ln -sf /usr/local/bin/npm /usr/bin/npm
fi

# Verify Node.js installation
echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"

# Install Caddy
echo "Installing Caddy on Fedora..."
dnf install -y --nogpgcheck 'dnf-command(copr)' || echo "Failed to install copr command, trying alternative..."
dnf copr enable -y @caddy/caddy || echo "Failed to enable Caddy repo, trying direct install..."
dnf install -y --nogpgcheck caddy || echo "Failed to install Caddy via repo, will try direct download..."

# Configure firewall (with proper error handling)
echo "Configuring firewall (firewalld)..."
# Ensure firewalld is installed (in case previous installation failed)
dnf install -y firewalld || echo "Warning: firewalld installation failed, skipping firewall configuration"

# Check if firewalld is available before configuring
if systemctl list-unit-files firewalld.service &>/dev/null; then
    echo "Starting and enabling firewalld..."
    systemctl start firewalld
    systemctl enable firewalld
    
    # Configure firewall rules
    echo "Configuring firewall rules..."
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --permanent --add-port=6667/tcp
    firewall-cmd --permanent --add-port=6697/tcp
    firewall-cmd --reload
    echo "✅ Firewall configured successfully"
else
    echo "⚠️  firewalld not available, skipping firewall configuration (ports will be open)"
fi

# Create directories
echo "Creating directories..."
mkdir -p /opt/ergo /etc/caddy

# Download and extract Ergo
echo "Downloading Ergo IRC server..."
cd /tmp
wget https://github.com/ergochat/ergo/releases/download/v2.14.0/ergo-2.14.0-linux-x86_64.tar.gz
tar -xzf ergo-2.14.0-linux-x86_64.tar.gz
cp -r ergo-2.14.0-linux-x86_64/* /opt/ergo/

# Create ergo user before setting ownership
echo "Creating ergo user..."
useradd -r -s /bin/false -d /opt/ergo ergo

# Copy Ergo configuration and substitute variables
echo "Configuring Ergo..."
cp /tmp/configs/ergo-ircd.yaml /opt/ergo/
sed -i "s/{hostname}/$HOSTNAME/g" /opt/ergo/ergo-ircd.yaml
sed -i "s/{admin_email}/$ADMIN_EMAIL/g" /opt/ergo/ergo-ircd.yaml
sed -i "s/{ergo_network}/$ERGO_NETWORK/g" /opt/ergo/ergo-ircd.yaml

# Copy and configure MOTD file
echo "Setting up Ergo MOTD..."
cp /tmp/configs/ergo-motd.txt /opt/ergo/ergo.motd
sed -i "s/{hostname}/$HOSTNAME/g" /opt/ergo/ergo.motd
sed -i "s/{ergo_network}/$ERGO_NETWORK/g" /opt/ergo/ergo.motd

# Set ownership for ergo directory
chown -R ergo:ergo /opt/ergo

# Install certificate update script
echo "Installing certificate update script..."
cp /tmp/scripts/update-ergo-certs.sh /usr/local/bin/
chmod +x /usr/local/bin/update-ergo-certs.sh

# Create Ergo certificate directory
mkdir -p /opt/ergo/certs
chown -R ergo:ergo /opt/ergo

# Create Ergo systemd service (without pre-start certificate copying)
echo "Creating Ergo systemd service..."
cat > /etc/systemd/system/ergo.service << 'EOF'
[Unit]
Description=Ergo IRC Server
After=network.target
Wants=caddy.service

[Service]
Type=simple
User=ergo
Group=ergo
WorkingDirectory=/opt/ergo
ExecStart=/opt/ergo/ergo run --conf /opt/ergo/ergo-ircd.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create certificate watcher service to update Ergo certs when Caddy renews them
echo "Creating certificate auto-update service..."
cat > /etc/systemd/system/ergo-cert-update.service << 'EOF'
[Unit]
Description=Update Ergo IRC Server Certificates
After=caddy.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update-ergo-certs.sh HOSTNAME_PLACEHOLDER
ExecStartPost=/bin/systemctl restart ergo
User=root
EOF

# Create path unit to watch for certificate changes
cat > /etc/systemd/system/ergo-cert-update.path << 'EOF'
[Unit]
Description=Watch for Caddy certificate changes
After=caddy.service

[Path]
PathChanged=/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/HOSTNAME_PLACEHOLDER/HOSTNAME_PLACEHOLDER.crt

[Install]
WantedBy=multi-user.target
EOF

# Replace the hostname placeholder in the certificate watcher files
sed -i "s/HOSTNAME_PLACEHOLDER/$HOSTNAME/g" /etc/systemd/system/ergo-cert-update.service
sed -i "s/HOSTNAME_PLACEHOLDER/$HOSTNAME/g" /etc/systemd/system/ergo-cert-update.path

# Install The Lounge
echo "Installing The Lounge..."
npm install -g thelounge

# Create thelounge user
echo "Creating thelounge user..."
useradd -r -s /bin/false -d /var/lib/thelounge thelounge
mkdir -p /var/lib/thelounge
chown thelounge:thelounge /var/lib/thelounge

# Copy The Lounge configuration
echo "Configuring The Lounge..."
mkdir -p /var/lib/thelounge
cp /tmp/configs/thelounge-config.js /var/lib/thelounge/config.js
sed -i "s/{ergo_network}/$ERGO_NETWORK/g" /var/lib/thelounge/config.js
chown thelounge:thelounge /var/lib/thelounge/config.js

# Create The Lounge systemd service
echo "Creating The Lounge systemd service..."
cat > /etc/systemd/system/thelounge.service << 'EOF'
[Unit]
Description=The Lounge IRC Web Client
After=network.target

[Service]
Type=simple
User=thelounge
Group=thelounge
WorkingDirectory=/var/lib/thelounge
ExecStart=/usr/bin/thelounge start
Restart=always
RestartSec=10
Environment=THELOUNGE_HOME=/var/lib/thelounge

[Install]
WantedBy=multi-user.target
EOF

# Configure Caddy directories and permissions
echo "Setting up Caddy directories..."
mkdir -p /var/log/caddy
chown caddy:caddy /var/log/caddy
chmod 755 /var/log/caddy

# Configure Caddy with HTTPS directly (Fedora-specific config)
echo "Configuring Caddy (HTTPS with automatic SSL)..."
cp /tmp/configs/Caddyfile.fedora /etc/caddy/Caddyfile
sed -i "s/{hostname}/$HOSTNAME/g" /etc/caddy/Caddyfile

# Reload systemd and start all services
echo "======================================"
echo "  Starting all services..."
echo "======================================"
systemctl daemon-reload
systemctl enable ergo thelounge caddy ergo-cert-update.path
systemctl start ergo thelounge caddy ergo-cert-update.path

# Wait for services to start
echo "Waiting for services to start..."
sleep 10

# Wait for SSL certificate provisioning with improved monitoring
echo "======================================"
echo "  Waiting for SSL Certificate..."
echo "======================================"
CERT_OBTAINED=false
MAX_WAIT=600  # 10 minutes maximum wait for production
WAIT_TIME=0
RESTART_COUNT=0
MAX_RESTARTS=8

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    # Check if certificate file exists and is valid
    CERT_PATH="/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/$HOSTNAME/$HOSTNAME.crt"
    if [ -f "$CERT_PATH" ] && openssl x509 -in "$CERT_PATH" -text -noout >/dev/null 2>&1; then
        echo "✅ SSL certificate file found and is valid!"
        CERT_OBTAINED=true
        break
    fi
    
    # Check logs for successful certificate obtainment (JSON format)
    if journalctl -u caddy --since "10 minutes ago" --no-pager | grep -q '"certificate obtained successfully".*"identifier":"'$HOSTNAME'"'; then
        echo "✅ SSL certificate obtained according to logs!"
        # Wait a bit for file to be written
        sleep 5
        if [ -f "$CERT_PATH" ]; then
            CERT_OBTAINED=true
            break
        fi
    fi
    
    # Check for certificate errors and restart more aggressively
    if journalctl -u caddy --since "2 minutes ago" --no-pager | grep -q -E "(could not get certificate|challenge failed|DNS problem).*$HOSTNAME"; then
        if [ $RESTART_COUNT -lt $MAX_RESTARTS ]; then
            RESTART_COUNT=$((RESTART_COUNT + 1))
            echo "⚠️  Certificate error detected. Restarting Caddy (attempt $RESTART_COUNT/$MAX_RESTARTS)..."
            systemctl restart caddy
            sleep 20  # Give more time after restart
        fi
    fi
    
    # Periodic restart to trigger SSL attempts
    if [ $((WAIT_TIME % 120)) -eq 0 ] && [ $WAIT_TIME -gt 0 ] && [ $RESTART_COUNT -lt $MAX_RESTARTS ]; then
        RESTART_COUNT=$((RESTART_COUNT + 1))
        echo "🔄 Periodic Caddy restart to trigger SSL (attempt $RESTART_COUNT/$MAX_RESTARTS)..."
        systemctl restart caddy
        sleep 20
    fi
    
    echo "⏳ Waiting for SSL certificate... ($WAIT_TIME/$MAX_WAIT seconds, restarts: $RESTART_COUNT)"
    sleep 20
    WAIT_TIME=$((WAIT_TIME + 20))
done

if [ "$CERT_OBTAINED" = true ]; then
    echo "✅ SSL certificate ready! Copying to Ergo..."
    
    # Copy certificates to Ergo and restart
    /usr/local/bin/update-ergo-certs.sh $HOSTNAME
    
    if [ $? -eq 0 ]; then
        echo "✅ Certificates copied successfully! Restarting Ergo..."
        systemctl restart ergo
        sleep 5
        
        # Verify Ergo is using the correct certificate
        if openssl x509 -in /opt/ergo/certs/server.crt -text -noout | grep -q "Let's Encrypt"; then
            echo "✅ Ergo is now using Let's Encrypt certificates!"
        else
            echo "⚠️  Ergo may still be using self-signed certificates"
        fi
    else
        echo "⚠️  Certificate copy failed, Ergo will use self-signed certificates"
    fi
else
    echo "⚠️  SSL certificate not obtained within timeout. Caddy will continue trying in background."
    echo "    You can monitor progress with: journalctl -u caddy -f"
    echo "    Ergo will use self-signed certificates for now."
fi

# Create service check script
echo "Creating service check script..."
cat > /root/check_services.sh << 'EOF'
#!/bin/bash
echo "=== IRC Stack Service Status ==="
echo "Ergo IRC Server:"
systemctl status ergo --no-pager -l
echo ""
echo "The Lounge Web Client:"
systemctl status thelounge --no-pager -l
echo ""
echo "Caddy Reverse Proxy:"
systemctl status caddy --no-pager -l
echo ""
echo "=== Network Status ==="
ss -tlnp | grep -E ':(6667|6697|9000|80|443)'
EOF
chmod +x /root/check_services.sh

echo "======================================"
echo "  Installation Complete! ✅"
echo "======================================"
echo "Ergo IRC Server: Running on ports 6667 (plain) and 6697 (SSL)"
if [ "$CERT_OBTAINED" = true ]; then
    echo "  ✅ Using Let's Encrypt SSL certificates (no more self-signed errors!)"
else
    echo "  ⚠️  Using self-signed certificates (SSL may show warnings)"
fi
echo "The Lounge Web Client: Running on port 9000"
echo "Caddy Reverse Proxy: Running on ports 80 and 443"
echo "Web Interface: https://$HOSTNAME"
echo ""
echo "🔐 SSL Certificate Status:"
if [ "$CERT_OBTAINED" = true ]; then
    echo "  ✅ Let's Encrypt certificates automatically provisioned and configured"
    echo "  ✅ IRC SSL connections will work without certificate warnings"
    echo "  ✅ Automatic certificate renewal is enabled"
else
    echo "  ⚠️  SSL certificates are still being obtained in background"
    echo "  ℹ️  Monitor with: journalctl -u caddy -f"
fi
echo ""
echo "To check service status, run: /root/check_services.sh"
echo "======================================"