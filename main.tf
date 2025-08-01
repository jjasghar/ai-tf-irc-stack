terraform {
  required_version = ">= 1.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "~> 1.65"
    }
    dnsimple = {
      source  = "dnsimple/dnsimple"
      version = "~> 1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}

# Configure the IBM Cloud Provider
provider "ibm" {
  ibmcloud_api_key = var.ibm_api_key
  region           = var.ibm_region
}

# Configure the DNSimple Provider
provider "dnsimple" {
  token   = var.dnsimple_token
  account = var.dnsimple_account_id
}

# Random suffix for unique DNS entries
resource "random_string" "dns_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Locals for both cloud providers
locals {
  # DigitalOcean SSH key
  do_ssh_key_id = "49660156"  # GitHub and Default SSH key - e5:08:5c:42:7a:e2:8d:bd:0d:5d:07:85:e0:4a:cc:45
  
  # Hostname generation
  unique_hostname = "${var.dns_record_name}-${random_string.dns_suffix.result}.${var.dns_zone}"
  
  # Server IP address (conditional based on cloud provider)
  server_ip = var.cloud_provider == "digitalocean" ? (
    length(digitalocean_droplet.irc_server) > 0 ? digitalocean_droplet.irc_server[0].ipv4_address : ""
  ) : (
    length(ibm_is_floating_ip.irc_fip) > 0 ? ibm_is_floating_ip.irc_fip[0].address : ""
  )
}

# DigitalOcean Resources (only created when cloud_provider = "digitalocean")

# Create a DigitalOcean Droplet
resource "digitalocean_droplet" "irc_server" {
  count    = var.cloud_provider == "digitalocean" ? 1 : 0
  image    = "fedora-41-x64"
  name     = "${var.project_name}-server"
  region   = var.region
  size     = "s-2vcpu-4gb"
  ssh_keys = [local.do_ssh_key_id]

  tags = ["irc", "ergo", "thelounge", "caddy"]

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
    host        = self.ipv4_address
  }

  # Copy configuration files
  provisioner "file" {
    source      = "${path.module}/configs/"
    destination = "/tmp/configs"
  }

  # Copy installation script
  provisioner "file" {
    source      = "${path.module}/scripts/install.sh"
    destination = "/tmp/install.sh"
  }

  # Execute installation script
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install.sh",
      "/tmp/install.sh '${local.unique_hostname}' '${var.admin_email}' '${var.ergo_network_name}' '${var.ergo_motd}'"
    ]
  }
}

# IBM Cloud Resources (only created when cloud_provider = "ibm")

# Get resource group
data "ibm_resource_group" "resource_group" {
  count = var.cloud_provider == "ibm" ? 1 : 0
  name  = var.ibm_resource_group
}

# Get VPC image (Fedora)
data "ibm_is_image" "fedora" {
  count = var.cloud_provider == "ibm" ? 1 : 0
  name  = "ibm-fedora-41-1-minimal-amd64-1"
}

# Get SSH key
data "ibm_is_ssh_key" "ssh_key" {
  count = var.cloud_provider == "ibm" ? 1 : 0
  name  = var.ibm_ssh_key_name
}

# Create VPC
resource "ibm_is_vpc" "irc_vpc" {
  count          = var.cloud_provider == "ibm" ? 1 : 0
  name           = "${var.project_name}-vpc"
  resource_group = data.ibm_resource_group.resource_group[0].id
  tags           = ["irc", "ergo", "thelounge", "caddy"]
}

# Create subnet
resource "ibm_is_subnet" "irc_subnet" {
  count           = var.cloud_provider == "ibm" ? 1 : 0
  name            = "${var.project_name}-subnet"
  vpc             = ibm_is_vpc.irc_vpc[0].id
  zone            = "${var.ibm_region}-1"
  ipv4_cidr_block = "10.240.0.0/24"
  resource_group  = data.ibm_resource_group.resource_group[0].id
}

# Create security group
resource "ibm_is_security_group" "irc_sg" {
  count          = var.cloud_provider == "ibm" ? 1 : 0
  name           = "${var.project_name}-sg"
  vpc            = ibm_is_vpc.irc_vpc[0].id
  resource_group = data.ibm_resource_group.resource_group[0].id
}

# Security group rules
resource "ibm_is_security_group_rule" "ssh" {
  count     = var.cloud_provider == "ibm" ? 1 : 0
  group     = ibm_is_security_group.irc_sg[0].id
  direction = "inbound"
  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "http" {
  count     = var.cloud_provider == "ibm" ? 1 : 0
  group     = ibm_is_security_group.irc_sg[0].id
  direction = "inbound"
  tcp {
    port_min = 80
    port_max = 80
  }
}

resource "ibm_is_security_group_rule" "https" {
  count     = var.cloud_provider == "ibm" ? 1 : 0
  group     = ibm_is_security_group.irc_sg[0].id
  direction = "inbound"
  tcp {
    port_min = 443
    port_max = 443
  }
}

resource "ibm_is_security_group_rule" "irc_plain" {
  count     = var.cloud_provider == "ibm" ? 1 : 0
  group     = ibm_is_security_group.irc_sg[0].id
  direction = "inbound"
  tcp {
    port_min = 6667
    port_max = 6667
  }
}

resource "ibm_is_security_group_rule" "irc_ssl" {
  count     = var.cloud_provider == "ibm" ? 1 : 0
  group     = ibm_is_security_group.irc_sg[0].id
  direction = "inbound"
  tcp {
    port_min = 6697
    port_max = 6697
  }
}

resource "ibm_is_security_group_rule" "outbound_all" {
  count     = var.cloud_provider == "ibm" ? 1 : 0
  group     = ibm_is_security_group.irc_sg[0].id
  direction = "outbound"
}

# Create IBM Cloud instance
resource "ibm_is_instance" "irc_server" {
  count          = var.cloud_provider == "ibm" ? 1 : 0
  name           = "${var.project_name}-server"
  vpc            = ibm_is_vpc.irc_vpc[0].id
  zone           = "${var.ibm_region}-1"
  profile        = "bx2-2x8"  # 2 vCPU, 8 GB RAM
  image          = data.ibm_is_image.fedora[0].id
  keys           = [data.ibm_is_ssh_key.ssh_key[0].id]
  resource_group = data.ibm_resource_group.resource_group[0].id
  tags           = ["irc", "ergo", "thelounge", "caddy"]

  primary_network_interface {
    subnet          = ibm_is_subnet.irc_subnet[0].id
    security_groups = [ibm_is_security_group.irc_sg[0].id]
  }

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
    host        = self.primary_network_interface[0].primary_ip[0].address
  }

  # Copy configuration files
  provisioner "file" {
    source      = "${path.module}/configs/"
    destination = "/tmp/configs"
  }

  # Copy installation script
  provisioner "file" {
    source      = "${path.module}/scripts/install.sh"
    destination = "/tmp/install.sh"
  }

  # Execute installation script
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install.sh",
      "/tmp/install.sh '${local.unique_hostname}' '${var.admin_email}' '${var.ergo_network_name}' '${var.ergo_motd}'"
    ]
  }
}

# Create floating IP for IBM Cloud instance
resource "ibm_is_floating_ip" "irc_fip" {
  count          = var.cloud_provider == "ibm" ? 1 : 0
  name           = "${var.project_name}-fip"
  target         = ibm_is_instance.irc_server[0].primary_network_interface[0].id
  resource_group = data.ibm_resource_group.resource_group[0].id
  tags           = ["irc", "ergo", "thelounge", "caddy"]
}

# Create DNS A record with random suffix
resource "dnsimple_zone_record" "irc_server" {
  zone_name = var.dns_zone
  name      = "${var.dns_record_name}-${random_string.dns_suffix.result}"
  value     = local.server_ip
  type      = "A"
  ttl       = 300
}

# Create CNAME for www (optional)
resource "dnsimple_zone_record" "irc_server_www" {
  count     = var.create_www_cname ? 1 : 0
  zone_name = var.dns_zone
  name      = "www.${var.dns_record_name}"
  value     = "${var.dns_record_name}.${var.dns_zone}"
  type      = "CNAME"
  ttl       = 300
}

# DigitalOcean firewall rules
resource "digitalocean_firewall" "irc_firewall" {
  count = var.cloud_provider == "digitalocean" ? 1 : 0
  name  = "${var.project_name}-firewall"

  droplet_ids = [digitalocean_droplet.irc_server[0].id]

  # SSH
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # HTTP
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # HTTPS
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # IRC plain text (optional, if you want direct access)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "6667"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # IRC SSL
  inbound_rule {
    protocol         = "tcp"
    port_range       = "6697"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Allow all outbound traffic
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}