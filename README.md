# IRC Stack Terraform Deployment

[![Multi-Cloud Support](https://img.shields.io/badge/Multi--Cloud-DigitalOcean%20%7C%20IBM%20Cloud-blue?style=flat-square)](#cloud-providers)
[![Terraform](https://img.shields.io/badge/Terraform-1.0%2B-623CE4?logo=terraform&style=flat-square)](https://terraform.io)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

This Terraform configuration deploys a complete IRC stack with **multi-cloud support**:

- **Ergo IRC Server** - Modern IRC server written in Go
- **The Lounge** - Modern web IRC client
- **Caddy** - Reverse proxy with automatic HTTPS
- **DNSimple** - DNS management

### ☁️ **Cloud Providers Supported:**
- **🌊 DigitalOcean** - Droplets, Firewalls, SSH Keys
- **☁️ IBM Cloud** - Virtual Server Instances, VPC, Security Groups

## Architecture

```
Internet
    ↓
[DNSimple DNS] → [Cloud Instance: DigitalOcean or IBM Cloud]
                      ↓
                 [Caddy :80/:443] 
                      ↓
                 [The Lounge :9000] ← → [Ergo IRC :6667/:6697]
```

### Cloud-Specific Architecture

**DigitalOcean:**
- Droplet (Virtual Machine)
- DigitalOcean Firewall
- SSH Key Management

**IBM Cloud:**
- Virtual Server Instance (VSI)
- VPC with Subnet
- Security Groups
- Floating IP

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

### For All Deployments:
1. **DNSimple Account** with API token and domain management
2. **SSH Key Pair** for server access  
3. **Terraform** installed (>= 1.0)

### For DigitalOcean:
4. **DigitalOcean Account** with API token
5. **SSH Key** uploaded to DigitalOcean

### For IBM Cloud:
4. **IBM Cloud Account** with API key
5. **SSH Key** created in IBM Cloud console
6. **Resource Group** (default or custom)

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

## Cloud Providers

This deployment supports both **DigitalOcean** and **IBM Cloud**. Choose your preferred provider by setting the `cloud_provider` variable.

### 🌊 DigitalOcean Configuration

**Required variables:**
```hcl
cloud_provider = "digitalocean"
do_token = "your_digitalocean_api_token_here"
```

**Resources created:**
- Droplet (Virtual Machine) - `s-2vcpu-4gb` (2 vCPU, 4GB RAM)
- Firewall with IRC and web ports open
- Uses existing SSH key by ID

**Setup steps:**
1. Get API token from [DigitalOcean API](https://cloud.digitalocean.com/account/api/tokens)
2. Upload your SSH key to DigitalOcean
3. Update the SSH key ID in `main.tf` (line 50)

### ☁️ IBM Cloud Configuration

**Required variables:**
```hcl
cloud_provider = "ibm"
ibm_api_key = "your_ibm_api_key_here"
ibm_ssh_key_name = "your_ssh_key_name"
```

**Optional variables:**
```hcl
ibm_region = "us-south"              # Default region
ibm_resource_group = "default"        # Default resource group
```

**Resources created:**
- Virtual Server Instance (VSI) - `bx2-2x8` (2 vCPU, 8GB RAM)
- VPC with subnet and security group
- Floating IP for public access
- Security group rules for IRC and web ports

**Setup steps:**
1. Get API key from [IBM Cloud API Keys](https://cloud.ibm.com/iam/apikeys)
2. Create SSH key in [IBM Cloud Console](https://cloud.ibm.com/vpc-ext/compute/sshKeys)
3. Note your resource group name (default: "default")

### 🔄 Switching Cloud Providers

To switch between providers:

1. **Update `terraform.tfvars`:**
   ```hcl
   # For DigitalOcean
   cloud_provider = "digitalocean"
   
   # For IBM Cloud  
   cloud_provider = "ibm"
   ```

2. **Run Terraform:**
   ```bash
   terraform plan    # Review changes
   terraform apply   # Deploy to new provider
   ```

> **Note:** The infrastructure is conditionally created based on `cloud_provider`. Only resources for the selected provider will be created.

## Configuration

### Required Variables

#### For All Deployments:
| Variable | Description | Example |
|----------|-------------|---------|
| `cloud_provider` | Cloud provider to use | `"digitalocean"` or `"ibm"` |
| `dnsimple_token` | DNSimple API token | `your_token` |
| `dnsimple_account_id` | DNSimple account ID | `12345` |

#### For DigitalOcean Only:
| Variable | Description | Example |
|----------|-------------|---------|
| `do_token` | DigitalOcean API token | `dop_v1_...` |

#### For IBM Cloud Only:
| Variable | Description | Example |
|----------|-------------|---------|
| `ibm_api_key` | IBM Cloud API key | `your_api_key` |
| `ibm_ssh_key_name` | SSH key name in IBM Cloud | `my-ssh-key` |

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