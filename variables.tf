variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "dnsimple_token" {
  description = "DNSimple API token"
  type        = string
  sensitive   = true
}

variable "dnsimple_account_id" {
  description = "DNSimple account ID"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key file"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "project_name" {
  description = "Project name for naming resources"
  type        = string
  default     = "irc-stack"
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc3"
}

variable "hostname" {
  description = "Full hostname for the IRC server"
  type        = string
  default     = "irc-testing.asgharlabs.io"
}

variable "dns_zone" {
  description = "DNS zone name (e.g., asgharlabs.io)"
  type        = string
  default     = "asgharlabs.io"
}

variable "dns_record_name" {
  description = "DNS record name (e.g., irc-testing)"
  type        = string
  default     = "irc-testing"
}

variable "create_www_cname" {
  description = "Create a www CNAME record"
  type        = bool
  default     = false
}

variable "admin_email" {
  description = "Administrator email for Let's Encrypt and server admin"
  type        = string
  default     = "admin@asgharlabs.io"
}

variable "ergo_network_name" {
  description = "IRC network name"
  type        = string
  default     = "AsgharlabsNet"
}

variable "ergo_motd" {
  description = "Message of the day for IRC server"
  type        = string
  default     = "Welcome to Asgharlabs IRC Network!"
}

# DigitalOcean SSH Key Configuration
variable "do_ssh_key_id" {
  description = "DigitalOcean SSH Key ID (get from DigitalOcean console)"
  type        = string
  default     = ""
}

# Cloud Provider Selection
variable "cloud_provider" {
  description = "Cloud provider to use (digitalocean or ibm)"
  type        = string
  default     = "digitalocean"
  validation {
    condition     = contains(["digitalocean", "ibm"], var.cloud_provider)
    error_message = "The cloud_provider value must be either 'digitalocean' or 'ibm'."
  }
}

# IBM Cloud Configuration
variable "ibm_api_key" {
  description = "IBM Cloud API key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ibm_region" {
  description = "IBM Cloud region"
  type        = string
  default     = "us-south"
}

variable "ibm_resource_group" {
  description = "IBM Cloud resource group ID (optional - leave empty to use account default)"
  type        = string
  default     = ""
}

variable "ibm_ssh_key_name" {
  description = "Name of existing IBM Cloud SSH key"
  type        = string
  default     = ""
}

# Debug Mode Configuration
variable "debug_mode" {
  description = "Enable debug mode with random hostname suffix (for testing)"
  type        = bool
  default     = true
  validation {
    condition     = var.debug_mode == true || var.debug_mode == false
    error_message = "The debug_mode value must be either true or false."
  }
}

# Infrastructure Configuration
variable "do_instance_size" {
  description = "DigitalOcean droplet size"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "ibm_instance_profile" {
  description = "IBM Cloud instance profile (CPU and memory configuration)"
  type        = string
  default     = "bx2-2x8"
}

variable "ibm_vpc_cidr" {
  description = "CIDR block for IBM Cloud VPC subnet"
  type        = string
  default     = "10.240.0.0/24"
}

variable "dns_ttl" {
  description = "TTL (Time To Live) for DNS records in seconds"
  type        = number
  default     = 300
  validation {
    condition     = var.dns_ttl >= 60 && var.dns_ttl <= 86400
    error_message = "DNS TTL must be between 60 and 86400 seconds (1 minute to 1 day)."
  }
}

variable "resource_tags" {
  description = "List of tags to apply to all resources"
  type        = list(string)
  default     = ["irc", "ergo", "thelounge", "caddy"]
}