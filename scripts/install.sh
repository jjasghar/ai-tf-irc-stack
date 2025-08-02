#!/bin/bash
set -e

# Arguments from Terraform
HOSTNAME="$1"
ADMIN_EMAIL="$2"
ERGO_NETWORK="$3"
ERGO_MOTD="$4"

echo "Starting IRC Stack installation..."
echo "Hostname: $HOSTNAME"
echo "Admin Email: $ADMIN_EMAIL"
echo "Ergo Network: $ERGO_NETWORK"
echo "Ergo MOTD: $ERGO_MOTD"

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_VERSION=$VERSION_ID
fi

echo "Detected OS: $OS $OS_VERSION"

# Update system and install packages based on OS
if [[ "$OS" == "fedora" ]]; then
    echo "Updating Fedora system packages..."
    # Refresh GPG keys first to avoid signature issues
    dnf update -y --refresh --nogpgcheck fedora-gpg-keys || echo "GPG key update failed, continuing..."
    # Try update with nogpgcheck to work around signature issues
    dnf update -y --nogpgcheck || echo "System update failed, continuing with package installation..."
    
    # Install required packages (excluding nodejs/npm - will install separately)
    echo "Installing required packages on Fedora..."
    dnf install -y --nogpgcheck git wget curl tar gzip golang firewalld || echo "Some packages failed to install, continuing..."
    
elif [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
    echo "Updating Debian/Ubuntu system packages..."
    apt update -y || echo "System update failed, continuing with package installation..."
    
    # Install required packages (excluding nodejs/npm - will install separately)
    echo "Installing required packages on Debian/Ubuntu..."
    apt install -y git wget curl tar gzip golang-go ufw || echo "Some packages failed to install, continuing..."
    
else
    echo "Unsupported OS: $OS"
    exit 1
fi

# Install Node.js from official NodeSource repository to avoid library conflicts
echo "Installing Node.js from official source..."
if [[ "$OS" == "fedora" ]]; then
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash - || echo "Failed to add NodeSource repo, trying fallback..."
    dnf install -y --nogpgcheck nodejs || echo "Failed to install Node.js from repo, trying binary download..."
elif [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - || echo "Failed to add NodeSource repo, trying fallback..."
    apt install -y nodejs || echo "Failed to install Node.js from repo, trying binary download..."
fi

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
echo "Installing Caddy..."
if [[ "$OS" == "fedora" ]]; then
    dnf install -y --nogpgcheck 'dnf-command(copr)' || echo "Failed to install copr command, trying alternative..."
    dnf copr enable -y @caddy/caddy || echo "Failed to enable Caddy repo, trying direct install..."
    dnf install -y --nogpgcheck caddy || echo "Failed to install Caddy via repo, will try direct download..."
elif [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
    apt install -y debian-keyring debian-archive-keyring apt-transport-https || echo "Failed to install keyring packages..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg || echo "Failed to add Caddy GPG key..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt update || echo "Failed to update package list..."
    apt install -y caddy || echo "Failed to install Caddy via repo, will try direct download..."
fi

# Start and enable firewall
echo "Configuring firewall..."
if [[ "$OS" == "fedora" ]]; then
    systemctl start firewalld
    systemctl enable firewalld
elif [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
    systemctl start ufw
    systemctl enable ufw
    ufw --force enable
fi

# Configure firewall
echo "Configuring firewall rules..."
if [[ "$OS" == "fedora" ]]; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --permanent --add-port=6667/tcp
    firewall-cmd --permanent --add-port=6697/tcp
    firewall-cmd --reload
elif [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
    ufw allow 22/tcp    # SSH
    ufw allow 80/tcp    # HTTP
    ufw allow 443/tcp   # HTTPS
    ufw allow 6667/tcp  # IRC plain
    ufw allow 6697/tcp  # IRC SSL
fi

# Create directories
echo "Creating directories..."
mkdir -p /opt/ergo /etc/caddy

# Install Ergo IRC server
echo "Installing Ergo IRC server..."
cd /opt/ergo
wget -O ergo.tar.gz https://github.com/ergochat/ergo/releases/download/v2.16.0/ergo-2.16.0-linux-x86_64.tar.gz
tar -xzf ergo.tar.gz --strip-components=1
rm ergo.tar.gz

# Create ergo user first
echo "Creating ergo user..."
useradd -r -s /bin/false ergo 2>/dev/null || echo "User ergo already exists"

# Copy and configure Ergo
echo "Configuring Ergo..."
if [ -f /tmp/configs/ergo-ircd.yaml ]; then
    cp /tmp/configs/ergo-ircd.yaml ircd.yaml
else
    ./ergo defaultconfig > ircd.yaml
fi

# Copy MOTD file
echo "Setting up Ergo MOTD..."
if [ -f /tmp/configs/ergo-motd.txt ]; then
    # Use template substitution to replace variables in MOTD
    sed -e "s/{hostname}/$HOSTNAME/g" \
        -e "s/{ergo_network}/$ERGO_NETWORK/g" \
        /tmp/configs/ergo-motd.txt > ergo.motd
    chown ergo:ergo ergo.motd
else
    # Fallback: create basic MOTD
    cat > ergo.motd << EOF
Welcome to $ERGO_NETWORK IRC Server

Server: $HOSTNAME
Web interface: https://$HOSTNAME
IRC SSL: $HOSTNAME:6697
IRC Plain: $HOSTNAME:6667

Enjoy your stay!
EOF
    chown ergo:ergo ergo.motd
fi

# Set ownership of Ergo directory to ergo user
chown -R ergo:ergo /opt/ergo

# Generate Ergo certificates (needs config file to exist first)
echo "Generating Ergo certificates..."
./ergo mkcerts

# Fix ownership after certificate generation
chown -R ergo:ergo /opt/ergo

# Create Ergo systemd service
echo "Creating Ergo service..."
if [ -f /tmp/configs/ergo.service ]; then
    cp /tmp/configs/ergo.service /etc/systemd/system/ergo.service
else
    cat > /etc/systemd/system/ergo.service << EOF
[Unit]
Description=Ergo IRC Server
After=network.target

[Service]
Type=simple
User=ergo
Group=ergo
WorkingDirectory=/opt/ergo
ExecStart=/opt/ergo/ergo run --conf /opt/ergo/ircd.yaml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
fi

# Install The Lounge
echo "Installing The Lounge..."
npm install -g thelounge

# Create thelounge user
echo "Creating thelounge user..."
useradd -r -s /bin/false thelounge || echo "User already exists"

# Create The Lounge configuration directory
echo "Creating The Lounge configuration..."
mkdir -p /home/thelounge/.thelounge/users
chown -R thelounge:thelounge /home/thelounge

# Initialize The Lounge with basic config
sudo -u thelounge thelounge start --help > /dev/null

# Copy and configure The Lounge
if [ -f /tmp/configs/thelounge-config.js ]; then
    # Use template substitution to replace variables in the config
    sed "s/{ergo_network}/$ERGO_NETWORK/g" /tmp/configs/thelounge-config.js > /home/thelounge/.thelounge/config.js
    chown thelounge:thelounge /home/thelounge/.thelounge/config.js
else
    # Fallback: create basic config
    cat > /home/thelounge/.thelounge/config.js << EOF
"use strict";
module.exports = {
    public: true,
    host: "127.0.0.1",
    port: 9000,
    reverseProxy: true,
    defaults: {
        name: "$ERGO_NETWORK",
        host: "127.0.0.1",
        port: 6667,
        tls: false,
        nick: "GuestUser",
        username: "GuestUser",
        realname: "GuestUser",
        join: "#lobby"
    }
};
EOF
    chown thelounge:thelounge /home/thelounge/.thelounge/config.js
fi

# Create The Lounge systemd service
echo "Creating The Lounge service..."
if [ -f /tmp/configs/thelounge.service ]; then
    cp /tmp/configs/thelounge.service /etc/systemd/system/thelounge.service
else
    cat > /etc/systemd/system/thelounge.service << EOF
[Unit]
Description=The Lounge IRC Web Client
After=network.target

[Service]
Type=simple
User=thelounge
Group=thelounge
WorkingDirectory=/home/thelounge
ExecStart=/usr/bin/thelounge start
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
fi

# Copy and configure Caddy
echo "Configuring Caddy..."
if [ -f /tmp/configs/Caddyfile ]; then
    # Use template substitution to replace hostname in Caddyfile
    sed "s/{hostname}/$HOSTNAME/g" /tmp/configs/Caddyfile > /etc/caddy/Caddyfile
else
    # Fallback: create basic Caddyfile
    cat > /etc/caddy/Caddyfile << EOF
$HOSTNAME {
    reverse_proxy localhost:9000
    encode gzip
    
    header {
        # Security headers
        Strict-Transport-Security max-age=31536000;
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        Referrer-Policy strict-origin-when-cross-origin
    }
}
EOF
fi

# Create log directory for Caddy
mkdir -p /var/log/caddy
chown caddy:caddy /var/log/caddy

# Enable and start services
echo "Starting services..."
systemctl daemon-reload
systemctl enable ergo thelounge caddy
systemctl start ergo
sleep 5
systemctl start thelounge
sleep 5
systemctl start caddy

# Create a simple status check script
echo "Creating status check script..."
cat > /root/check_services.sh << 'EOF'
#!/bin/bash
echo "=== Service Status ==="
systemctl is-active ergo thelounge caddy

echo ""
echo "=== Port Status ==="
ss -tlnp | grep -E ':6667|:6697|:9000|:80|:443'

echo ""
echo "=== Ergo Status ==="
timeout 3 bash -c 'echo "QUIT" | nc localhost 6667' > /dev/null && echo "Ergo is responding" || echo "Ergo is not responding"

echo ""
echo "=== The Lounge Status ==="
curl -s -I http://localhost:9000 > /dev/null && echo "The Lounge is responding" || echo "The Lounge is not responding"

echo ""
echo "=== Caddy Status ==="
curl -s -I http://localhost > /dev/null && echo "Caddy is responding" || echo "Caddy is not responding"
EOF

chmod +x /root/check_services.sh

# Final verification
echo ""
echo "=== Installation Complete ==="
echo "Running status check..."
sleep 5
/root/check_services.sh

echo ""
echo "IRC Stack deployment completed!"
echo "Web interface: https://$HOSTNAME"
echo "IRC SSL: $HOSTNAME:6697"
echo "IRC Plain: $HOSTNAME:6667"
echo "Public instance - Users can register directly on the web interface"
echo "Check services with: /root/check_services.sh"