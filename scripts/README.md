# Installation Scripts

This directory contains OS-specific installation scripts for the IRC stack (Ergo IRC Server + The Lounge Web Client + Caddy Reverse Proxy).

## Scripts Overview

### `install-fedora.sh` 🔴
**Used by**: DigitalOcean  
**OS**: Fedora 41 (`fedora-41-x64`)  
**Package Manager**: `dnf`  
**Firewall**: `firewalld`  
**User**: `root`  

Features specific to Fedora:
- Uses `dnf` with `--nogpgcheck` flags for package installation
- Installs Caddy via copr repository
- Configures `firewalld` for port management
- Uses NodeSource RPM repository for Node.js

### `install-debian.sh` 🔵
**Used by**: IBM Cloud  
**OS**: Debian 12 (`ibm-debian-12-0-minimal-amd64-1`)  
**Package Manager**: `apt`  
**Firewall**: `ufw`  
**User**: `root`  

Features specific to Debian:
- Uses `apt` for package installation
- Installs Caddy via cloudsmith repository with GPG key management
- Configures `ufw` (Uncomplicated Firewall) for port management
- Uses NodeSource DEB repository for Node.js

### `install.sh` (Legacy) ⚠️
**Status**: Deprecated but kept for reference  
**Description**: Original multi-OS script with OS detection logic  

This script automatically detected the OS and used appropriate commands, but has been split into dedicated scripts for clarity and maintainability.

## Cloud Provider Mapping

| Cloud Provider | OS Image | Script | Package Manager | Firewall | SSH User |
|---|---|---|---|---|---|
| **DigitalOcean** | `fedora-41-x64` | `install-fedora.sh` | `dnf` | `firewalld` | `root` |
| **IBM Cloud** | `ibm-debian-12-0-minimal-amd64-1` | `install-debian.sh` | `apt` | `ufw` | `root` |

## Installation Process

Both scripts follow the same logical flow:

1. **System Update**: Update package repositories and system packages
2. **Package Installation**: Install required dependencies (git, wget, curl, golang, etc.)
3. **Node.js Setup**: Install Node.js 20.x from official NodeSource repository
4. **Caddy Installation**: Install Caddy web server from official repositories
5. **Firewall Configuration**: Configure firewall rules for required ports
6. **Ergo Setup**: Download, configure, and setup Ergo IRC server
7. **The Lounge Setup**: Install and configure The Lounge web client
8. **Service Management**: Create systemd services and start all components
9. **Verification**: Create service check scripts and verify installation

## Port Configuration

Both scripts configure the following ports:

- **22/tcp**: SSH (secure shell)
- **80/tcp**: HTTP (Caddy reverse proxy)
- **443/tcp**: HTTPS (Caddy reverse proxy with automatic TLS)
- **6667/tcp**: IRC plain text connections
- **6697/tcp**: IRC SSL/TLS connections

## Service Status

After installation, you can check service status using:

```bash
/root/check_services.sh
```

This script provides status information for:
- Ergo IRC Server
- The Lounge Web Client  
- Caddy Reverse Proxy
- Network port bindings

## Arguments

All scripts accept the same 4 arguments from Terraform:

1. **HOSTNAME**: The DNS hostname for the server
2. **ADMIN_EMAIL**: Administrator email for Caddy TLS certificates
3. **ERGO_NETWORK**: IRC network name for Ergo configuration
4. **ERGO_MOTD**: Message of the Day text for Ergo

## Error Handling

Both scripts include comprehensive error handling:
- Continue installation even if some packages fail
- Fallback to binary Node.js installation if repository fails
- Graceful handling of GPG/signature verification issues
- Detailed logging of each installation step

## Customization

To customize the installation:

1. **Modify configuration templates** in `../configs/` directory
2. **Update package lists** in the respective scripts
3. **Adjust firewall rules** for additional ports if needed
4. **Change service configurations** in the systemd service sections

The scripts are designed to be idempotent and can be run multiple times safely.