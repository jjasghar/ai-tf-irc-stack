# IRC Stack Terraform Deployment

This Terraform configuration deploys a complete IRC stack on DigitalOcean with:

- **Ergo IRC Server** - Modern IRC server written in Go
- **The Lounge** - Modern web IRC client
- **Caddy** - Reverse proxy with automatic HTTPS
- **DNSimple** - DNS management

## Architecture

```
Internet
    ↓
[DNSimple DNS] → [DigitalOcean Droplet]
                      ↓
                 [Caddy :80/:443] 
                      ↓
                 [The Lounge :9000] ← → [Ergo IRC :6667/:6697]
```

## Project Structure

```
ai-tf-do-irc-stack/
├── configs/                    # Configuration templates
│   ├── Caddyfile              # Caddy reverse proxy config
│   ├── ergo-ircd.yaml         # Ergo IRC server config
│   ├── thelounge-config.js    # The Lounge web client config
│   ├── ergo.service           # Ergo systemd service
│   └── thelounge.service      # The Lounge systemd service
├── scripts/                   # Helper scripts
│   └── substitute_config.sh   # Template variable substitution
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output definitions
├── user_data.sh              # Server initialization script
└── terraform.tfvars.example  # Example configuration
```

## Prerequisites

1. **DigitalOcean Account** with API token
2. **DNSimple Account** with API token and domain management
3. **SSH Key Pair** for server access
4. **Terraform** installed (>= 1.0)

## Quick Start

1. **Clone and setup:**
   ```bash
   git clone <this-repo>
   cd ai-tf-do-irc-stack
   ```

2. **Configure variables:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your tokens and settings
   ```

3. **Deploy:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Access your IRC server:**
   - Web interface: `https://irc-testing.asgharlabs.io`
   - IRC SSL: `irc-testing.asgharlabs.io:6697`
   - IRC Plain: `irc-testing.asgharlabs.io:6667`

## Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `do_token` | DigitalOcean API token | `dop_v1_...` |
| `dnsimple_token` | DNSimple API token | `your_token` |
| `dnsimple_account_id` | DNSimple account ID | `12345` |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ssh_public_key_path` | `~/.ssh/id_rsa.pub` | SSH public key path |
| `project_name` | `irc-stack` | Project name for resources |
| `region` | `nyc3` | DigitalOcean region |
| `hostname` | `irc-testing.asgharlabs.io` | Server hostname |
| `dns_zone` | `asgharlabs.io` | DNS zone |
| `dns_record_name` | `irc-testing` | DNS record name |
| `admin_email` | `admin@asgharlabs.io` | Admin email |
| `ergo_network_name` | `AsgharlabsNet` | IRC network name |

## Getting API Tokens

### DigitalOcean Token
1. Go to [DigitalOcean API](https://cloud.digitalocean.com/account/api/tokens)
2. Click "Generate New Token"
3. Give it a name and select "Write" scope
4. Copy the token (starts with `dop_v1_`)

### DNSimple Token
1. Go to [DNSimple Account Settings](https://dnsimple.com/user)
2. Navigate to "Automation" tab
3. Generate a new token
4. Copy the token

### DNSimple Account ID
Find this in your DNSimple dashboard URL: `https://dnsimple.com/a/{ACCOUNT_ID}/domains`

## Post-Deployment Setup

### The Lounge Admin User

After deployment, create an admin user for The Lounge:

```bash
# SSH to your server
ssh root@$(terraform output -raw droplet_ip)

# Create admin user
sudo -u thelounge thelounge --home /home/thelounge/.thelounge add admin

# Set password for admin user
sudo -u thelounge thelounge --home /home/thelounge/.thelounge reset admin
```

### IRC Server Admin

The IRC server comes with a default admin user:
- **Username:** `admin`
- **Password:** `admin123` (change this!)

To change the admin password:
1. Generate a new password hash: `/opt/ergo/ergo genpasswd`
2. Update the password in `/opt/ergo/ircd.yaml`
3. Restart Ergo: `systemctl restart ergo`

## Service Management

Check service status:
```bash
ssh root@$(terraform output -raw droplet_ip)
/root/check_services.sh
```

Individual service control:
```bash
# Ergo IRC Server
systemctl status ergo
systemctl restart ergo

# The Lounge
systemctl status thelounge  
systemctl restart thelounge

# Caddy
systemctl status caddy
systemctl restart caddy
```

## Firewall Configuration

The server automatically configures these ports:
- **22** - SSH
- **80** - HTTP (redirects to HTTPS)
- **443** - HTTPS (The Lounge web interface)
- **6667** - IRC plain text
- **6697** - IRC SSL

## File Locations

| Service | Config Location | Logs |
|---------|----------------|------|
| Ergo | `/opt/ergo/ircd.yaml` | `/opt/ergo/ircd.log` |
| The Lounge | `/home/thelounge/.thelounge/config.js` | `journalctl -u thelounge` |
| Caddy | `/etc/caddy/Caddyfile` | `/var/log/caddy/access.log` |

## Troubleshooting

### Services not starting
```bash
# Check logs
journalctl -u ergo -f
journalctl -u thelounge -f  
journalctl -u caddy -f

# Check configuration
/opt/ergo/ergo run --check
caddy validate --config /etc/caddy/Caddyfile
```

### DNS not resolving
```bash
# Check DNS propagation
dig irc-testing.asgharlabs.io
nslookup irc-testing.asgharlabs.io
```

### SSL certificate issues
Caddy automatically obtains Let's Encrypt certificates. If there are issues:
```bash
# Check Caddy logs
journalctl -u caddy -f

# Force certificate renewal
caddy reload --config /etc/caddy/Caddyfile
```

## Customization

### Local Configuration Editing

All service configurations are stored in the `configs/` directory as templates. You can edit these files locally before deployment:

- **`configs/ergo-ircd.yaml`** - IRC server configuration
- **`configs/thelounge-config.js`** - Web client configuration  
- **`configs/Caddyfile`** - Reverse proxy configuration
- **`configs/ergo.service`** - IRC server systemd service
- **`configs/thelounge.service`** - Web client systemd service

#### Template Variables

The configuration files support these template variables:
- `{hostname}` - Server hostname (e.g., `irc-testing.asgharlabs.io`)
- `{ergo_network}` - IRC network name (e.g., `AsgharlabsNet`)
- `{ergo_motd}` - Message of the day

#### Applying Configuration Changes

After editing config files locally:

1. **Run Terraform apply** to copy updated configs:
   ```bash
   terraform apply -replace="digitalocean_droplet.irc_server"
   ```

2. **Or manually copy and restart services**:
   ```bash
   # Copy configs to server
   scp -r configs/ root@$(terraform output -raw droplet_ip):/tmp/
   
   # SSH to server and apply configs
   ssh root@$(terraform output -raw droplet_ip)
   /tmp/substitute_config.sh /tmp/configs/Caddyfile 'irc-testing.asgharlabs.io' 'AsgharlabsNet' 'Welcome!'
   cp /tmp/configs/Caddyfile /etc/caddy/Caddyfile
   systemctl reload caddy
   ```

### Direct Server Configuration

You can also edit configurations directly on the server:

- **IRC Server:** Edit `/opt/ergo/ircd.yaml` → `systemctl restart ergo`
- **Web Client:** Edit `/home/thelounge/.thelounge/config.js` → `systemctl restart thelounge`  
- **Reverse Proxy:** Edit `/etc/caddy/Caddyfile` → `systemctl reload caddy`

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

## Security Notes

1. **Change default passwords** immediately after deployment
2. **Restrict SSH access** to your IP if possible
3. **Enable fail2ban** for additional SSH protection
4. **Regularly update** the system: `dnf update -y`
5. **Monitor logs** for suspicious activity

## Support

- [Ergo Documentation](https://ergo.chat/guide.html)
- [The Lounge Documentation](https://thelounge.chat/docs)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [Terraform DigitalOcean Provider](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs)
- [Terraform DNSimple Provider](https://registry.terraform.io/providers/dnsimple/dnsimple/latest/docs)