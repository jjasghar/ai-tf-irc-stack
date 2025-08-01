output "droplet_ip" {
  description = "Public IP address of the IRC server"
  value       = digitalocean_droplet.irc_server.ipv4_address
}

output "droplet_private_ip" {
  description = "Private IP address of the IRC server"
  value       = digitalocean_droplet.irc_server.ipv4_address_private
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
  value       = "ssh root@${digitalocean_droplet.irc_server.ipv4_address}"
}

output "dns_records" {
  description = "Created DNS records"
  value = {
    a_record     = "${local.unique_hostname} -> ${digitalocean_droplet.irc_server.ipv4_address}"
    cname_record = var.create_www_cname ? "www.${var.dns_record_name}-${random_string.dns_suffix.result}.${var.dns_zone} -> ${var.dns_record_name}-${random_string.dns_suffix.result}.${var.dns_zone}" : "Not created"
  }
}