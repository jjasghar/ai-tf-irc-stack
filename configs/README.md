# Configuration Templates

This directory contains configuration templates for all IRC stack services. These files are copied to the server during deployment and have template variables substituted automatically.

## Files

### `Caddyfile`
Caddy reverse proxy configuration that handles:
- HTTPS termination with automatic Let's Encrypt certificates
- Reverse proxying to The Lounge web interface
- Security headers and compression
- Access logging

### `ergo-ircd.yaml`
Ergo IRC server configuration with:
- Network and server settings
- User authentication and registration
- Channel settings and history
- Operator permissions
- SSL/TLS configuration

### `ergo-motd.txt`
Ergo IRC server Message of the Day (MOTD) displayed to users when they connect:
- Customizable welcome message with ASCII art support
- Server information and connection details
- Network rules and guidelines
- Template variables for dynamic content

### `thelounge-config.js`
The Lounge web IRC client configuration including:
- Server connection settings
- Web interface preferences
- Message history settings
- Default IRC connection parameters

### `ergo.service` & `thelounge.service`
Systemd service files for automatic service management:
- Service startup and restart policies
- User and working directory settings
- Service dependencies

## Template Variables

The following variables are automatically substituted during deployment:

| Variable | Description | Example |
|----------|-------------|---------|
| `{hostname}` | Full server hostname | `irc-testing.asgharlabs.io` |
| `{ergo_network}` | IRC network name | `AsgharlabsNet` |
| `{ergo_motd}` | Message of the day | `Welcome to Asgharlabs IRC Network!` |

## Customization

### Editing Configurations

1. **Edit the template files** in this directory locally
2. **Keep template variables** intact (e.g., `{hostname}`)
3. **Test your changes** by running `terraform plan`
4. **Deploy** with `terraform apply`

### Adding New Template Variables

To add new template variables:

1. **Add the variable** to `variables.tf`
2. **Update the user_data.sh template** in the `templatefile()` function call in `main.tf`
3. **Update the substitution script** in `scripts/substitute_config.sh`
4. **Use the variable** in your config files as `{variable_name}`

### Example: Customizing Ergo Settings

To enable IRC user cloaking in Ergo:

```yaml
# In configs/ergo-ircd.yaml
server:
    ip-cloaking:
        enabled: true
        netname: "users"
```

Then run:
```bash
terraform apply
```

### Example: Customizing The Lounge Theme

To change The Lounge theme:

```javascript
// In configs/thelounge-config.js  
module.exports = {
    theme: "morning",  // Change from "default"
    // ... rest of config
};
```

### Example: Customizing IRC Server MOTD

To customize the message users see when connecting:

```text
// In configs/ergo-motd.txt
┌─────────────────────────────────────────┐
│        Welcome to My IRC Network       │
└─────────────────────────────────────────┘

🎮 Gaming Community IRC Server
📅 Established 2025

Connection Info:
  Web: https://{hostname}
  SSL: {hostname}:6697

Rules:
• Be respectful to all users
• No spam or flooding
• Have fun!

Type /list to see available channels.
```

The MOTD supports:
- Unicode characters and emoji
- ASCII art and box drawing
- Template variables: `{hostname}`, `{ergo_network}`
- Multi-line formatting

## Configuration References

- [Ergo Configuration Guide](https://ergo.chat/guide.html#configuration)
- [The Lounge Configuration](https://thelounge.chat/docs/server/configuration)
- [Caddy Documentation](https://caddyserver.com/docs/caddyfile)

## Advanced Customization

### Custom IRC Operators

Edit `configs/ergo-ircd.yaml` to add IRC operators:

```yaml
opers:
    admin:
        class: "server-admin"
        password: "$2a$10$..." # Generate with: /opt/ergo/ergo genpasswd
    moderator:
        class: "local-oper" 
        password: "$2a$10$..."
```

### Custom The Lounge Networks

Edit `configs/thelounge-config.js` to add default networks:

```javascript
defaults: {
    name: "{ergo_network}",
    host: "127.0.0.1",
    port: 6697,
    tls: true,  // Enable SSL by default
    join: "#general,#help"  // Auto-join channels
}
```

### Custom Caddy Features

Edit `configs/Caddyfile` to add features:

```
{hostname} {
    # Basic auth for admin panel
    basicauth /admin/* {
        admin $2a$10$...
    }
    
    # Rate limiting
    rate_limit {
        zone static {
            key {remote_host}
            events 100
            window 1m
        }
    }
    
    reverse_proxy localhost:9000
}
```