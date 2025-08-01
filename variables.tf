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
  description = "IBM Cloud resource group name"
  type        = string
  default     = "default"
}

variable "ibm_ssh_key_name" {
  description = "Name of existing IBM Cloud SSH key"
  type        = string
  default     = ""
}