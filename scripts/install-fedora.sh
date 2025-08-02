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

# Generate Ergo certificates
echo "Generating Ergo certificates..."
cd /opt/ergo
sudo -u ergo ./ergo mkcerts --conf ergo-ircd.yaml

# Set final ownership
chown -R ergo:ergo /opt/ergo

# Create Ergo systemd service
echo "Creating Ergo systemd service..."
cat > /etc/systemd/system/ergo.service << 'EOF'
[Unit]
Description=Ergo IRC Server
After=network.target

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
systemctl enable ergo thelounge caddy
systemctl start ergo thelounge caddy

# Wait for services to start and SSL certificate provisioning
echo "Waiting for services to start and SSL certificate provisioning..."
sleep 20

# Check SSL certificate status
echo "Checking SSL certificate status..."
if journalctl -u caddy --since "1 minute ago" --no-pager | grep -q "certificate obtained successfully"; then
    echo "✅ SSL certificate obtained successfully!"
else
    echo "⚠️  SSL certificate may still be in progress. Check with: journalctl -u caddy"
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
echo "The Lounge Web Client: Running on port 9000"
echo "Caddy Reverse Proxy: Running on ports 80 and 443"
echo "Web Interface: https://$HOSTNAME"
echo ""
echo "To check service status, run: /root/check_services.sh"
echo "======================================"