output "server_ip" {
  description = "Public IP address of the IRC server"
  value       = local.server_ip
}

output "server_private_ip" {
  description = "Private IP address of the IRC server"
  value = var.cloud_provider == "digitalocean" ? (
    length(digitalocean_droplet.irc_server) > 0 ? digitalocean_droplet.irc_server[0].ipv4_address_private : ""
  ) : (
    length(ibm_is_instance.irc_server) > 0 ? ibm_is_instance.irc_server[0].primary_network_interface[0].primary_ip[0].address : ""
  )
}

output "cloud_provider" {
  description = "Cloud provider used for deployment"
  value       = var.cloud_provider
}

output "hostname" {
  description = "Full hostname of the IRC server"
  value       = local.unique_hostname
}

output "web_interface_url" {
  description = "URL to access The Lounge web interface"
  value       = "https://${local.unique_hostname}"
}

output "irc_server_ssl" {
  description = "IRC server SSL connection details"
  value       = "${local.unique_hostname}:6697 (SSL)"
}

output "irc_server_plain" {
  description = "IRC server plain text connection details"
  value       = "${local.unique_hostname}:6667 (Plain text)"
}

output "ssh_connection" {
  description = "SSH connection command"
  value       = "ssh root@${local.server_ip}"
}

output "dns_records" {
  description = "Created DNS records"
  value = {
    a_record     = "${local.unique_hostname} -> ${local.server_ip}"
    cname_record = var.create_www_cname && !var.debug_mode ? "www.${var.dns_record_name}.${var.dns_zone} -> ${var.dns_record_name}.${var.dns_zone}" : "Not created"
  }
}

output "debug_mode" {
  description = "Current debug mode status"
  value       = var.debug_mode
}