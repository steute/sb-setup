# How to Use the Setup Script

This guide explains how to use the `setup.sh` script to configure and deploy a secure Sensor Bridge instance with Docker.

## Overview

The setup script automates the creation of:

- **TLS Certificates**: A local Certificate Authority (CA) and signed certificates for all services
- **Configuration Files**: Pre-configured settings for Mosquitto MQTT broker, PostgreSQL database, and Traefik reverse proxy
- **Docker Compose File**: Ready-to-use Docker Compose configuration
- **Secure Passwords**: Randomly generated passwords stored in the `secrets/` directory
- **Database Encryption Key**: Master key for encrypting sensitive data in the database

At the end of the setup, the script displays all important information including:

- SensorBridge master key (for data encryption)
- Web interface credentials (username: admin)
- MQTT broker connection details (WebSocket Secure on port 443, path: /mqttproxy)
- Root CA certificate location and installation instructions

## Prerequisites

Before running the setup script, ensure you have:

- **Docker Engine** (version 29 or later) installed
- **OpenSSL** installed
- **Root/sudo access** to the system
- **Linux system** (tested on amd64/x86_64 Debian 12 Bookworm)
- **Docker Hub account** (if using the dhi.io registry)

## Quick Start

1. Navigate to the setup script directory:

   ```bash
   cd /path/to/sb-setup
   ```

2. Run the setup script with sudo:

   ```bash
   sudo ./setup.sh
   ```

3. Follow the interactive prompts (see detailed guide below)

4. Once complete, start the services:
   ```bash
   sudo docker compose up -d
   ```

## Detailed Step-by-Step Guide

### Step 1: System Requirements Check

The script automatically verifies:

- You're running with sudo/root privileges
- Docker is installed
- OpenSSL is available

If any requirement is missing, the script will exit with an error message.

### Step 2: Existing Setup Check

If you've run the setup before, the script will detect existing files:

```
[WARNING] docker-compose.yml already exists
Do you want to continue and overwrite existing files? (y/N):
```

- **y**: Overwrites existing configuration (use with caution)
- **N**: Cancels the setup (default)

### Step 3: Docker Registry Selection

```
Do you want to use the 'dhi.io' registry? (Y/n):
```

- **Y** (recommended): Uses the official dhi.io Docker registry
  - You'll be prompted to authenticate: `sudo docker login dhi.io`
  - Follow the login prompts with your Docker Hub credentials
- **n**: Uses alternative Docker images (you'll need to provide your own)

### Step 4: Certificate Configuration

Enter certificate details for your Certificate Authority (CA):

```
Enter certificate information (press Enter to use default values):
Country Name (C) [DE]:
State/Province (ST) [NRW]:
Locality (L) [Loehne]:
Organization (O) [SensorBridgeTesting]:
Organizational Unit (OU) [IoT]:
Common Name (CN) [Internal-SensorBridge-CA]:
```

**Tip**: Press Enter to accept the default values shown in brackets, or type your own values.

The script will then:

- Create a root CA certificate (valid for 25 years)
- Generate certificates for MQTT broker, PostgreSQL, and Traefik (valid for 5-20 years)
- Sign all certificates with the CA

### Step 5: Initial Admin Password

```
Do you want a randomly generated initial password? (Y/n):
```

- **Y**: Generates a random password and displays it on screen
  - The password is also saved to `secrets/initial_sb_password.txt`
  - **Important**: Note this password down - you'll need it for first login
- **n**: Prompts you to enter and confirm a custom password

### Step 6: Traefik Certificate SAN Entries

```
Enter additional SAN entries for Traefik certificate (or press Enter for defaults)
Default SAN entries: DNS:sensorbridge, DNS:localhost, DNS:host.docker.internal, IP:127.0.0.1
Format: DNS:hostname or IP:address (comma-separated for multiple entries)
Additional SAN entries:
```

- Press **Enter** to use defaults
- Or enter additional Subject Alternative Names if you need custom domains (e.g., `DNS:myserver.local,IP:192.168.1.100`)

**Important**: The script validates your input and will prompt you to re-enter if the format is incorrect:

- Each entry must start with `DNS:` or `IP:`
- DNS names must be valid hostnames (alphanumeric, dots, hyphens)
- IP addresses must be valid IPv4 or IPv6 addresses
- Multiple entries should be comma-separated

### Step 7: Setup Complete

Upon successful completion, the script displays comprehensive information about your setup:

#### SensorBridge Master Key

```
=== SensorBridge Master Key ===
Master Key: <your-generated-key>
Location: /path/to/secrets/sb_masterkey.txt
IMPORTANT: Store this master key in a safe place (e.g., password manager or secure vault).
           If lost, encrypted data cannot be recovered!
```

**Critical**: Save this master key immediately to a secure location like a password manager or encrypted vault. Without it, you cannot recover encrypted data.

#### Web Interface Credentials

```
=== SensorBridge Web Interface ===
URL: https://localhost (or https://sensorbridge)
Initial Username: admin
Initial Password: <your-generated-password>
Location: /path/to/secrets/initial_sb_password.txt
```

#### MQTT Connection Details

```
=== MQTT Broker Connection ===
Protocol: WSS (WebSocket Secure)
Host: localhost (or sensorbridge)
Port: 443
Path: /mqttproxy
Username: mqttclient
Password: <your-generated-password>
Location: /path/to/secrets/mqtt_password.txt
Example connection: wss://localhost:443/mqttproxy
```

#### Root Certificate Information

```
=== Root Certificate ===
Location: /path/to/ca/sb-root-ca.pem
This root certificate can be used to validate all self-signed server certificates.
Install it on your system to avoid browser security warnings:
  Linux:   sudo cp ca/sb-root-ca.pem /usr/local/share/ca-certificates/sb-root-ca.crt
           sudo update-ca-certificates
  macOS:   sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca/sb-root-ca.pem
  Windows: Double-click ca/sb-root-ca.pem and install to 'Trusted Root Certification Authorities'
```

#### Next Steps

```
=== Next Steps ===
1. BACKUP the secrets directory and master key to a secure location
2. Start the services: sudo docker compose up -d
3. Access the web interface at https://localhost
4. Change the default admin password after first login
5. Install the root CA certificate to avoid browser warnings
```

**Important**: Take note of all displayed credentials and save them securely. All this information is also stored in the `secrets/` directory.

## Generated Files and Directories

After running the setup script, the following structure is created:

```
sb-setup/
├── docker-compose.yml           # Docker Compose configuration
├── ca/
│   ├── sb-root-ca.key          # Root CA private key (keep secure!)
│   ├── sb-root-ca.pem          # Root CA certificate
│   └── sb-root-ca.srl          # Certificate serial number
├── mosquitto/
│   ├── mqtt-broker-internal.pem        # MQTT broker certificate
│   ├── mqtt-broker-internal-key.pem    # MQTT broker private key
│   ├── mqtt-broker-internal.csr        # Certificate signing request
│   ├── mosquitto.conf                  # MQTT broker configuration
│   └── mosquitto.pass                  # MQTT credentials
├── postgres/
│   ├── postgres-internal.pem           # PostgreSQL certificate
│   ├── postgres-internal-key.pem       # PostgreSQL private key
│   ├── postgres-internal.csr           # Certificate signing request
│   ├── pg_hba.conf                     # PostgreSQL client authentication
│   └── data/                           # PostgreSQL data directory
├── traefik/
│   ├── traefik-external.pem            # Traefik certificate
│   ├── traefik-external-key.pem        # Traefik private key
│   ├── traefik-external.csr            # Certificate signing request
│   └── traefik-tls-config.yaml         # Traefik TLS configuration
└── secrets/
    ├── initial_sb_password.txt         # SensorBridge admin password
    ├── mqtt_password.txt               # MQTT client password
    ├── postgres_password_pg.txt        # PostgreSQL password (for DB)
    ├── postgres_password_sb.txt        # PostgreSQL password (for SensorBridge)
    └── sb_masterkey.txt                # Database encryption key
```

### Important Security Notes

- **CRITICAL: Backup the master key** - `secrets/sb_masterkey.txt` is essential for data encryption. If lost, encrypted data cannot be recovered. Store it in a password manager or secure vault immediately.
- **Keep the `ca/` directory secure** - it contains your root CA private key which can sign certificates
- **Store all passwords securely** - all generated passwords are in the `secrets/` directory:
  - `initial_sb_password.txt` - SensorBridge web interface admin password
  - `mqtt_password.txt` - MQTT broker client password
  - `postgres_password_pg.txt` and `postgres_password_sb.txt` - PostgreSQL passwords
- **Change default passwords** - Change the initial admin password after first login
- **Do not commit secrets to version control** - ensure `.gitignore` excludes sensitive files
- **Set appropriate file permissions** - the script automatically sets secure permissions, but verify after any manual changes
- **Backup regularly** - Schedule regular backups of the `secrets/` directory, certificates, and database

## Starting the Services

**IMPORTANT: Always use the `docker compose` commands from the directory containing the generated `docker-compose.yml` file.**

After setup is complete, start all services with:

```bash
sudo docker compose up -d
```

Check service status:

```bash
sudo docker compose ps
```

View logs:

```bash
sudo docker compose logs -f
```

## Accessing SensorBridge

Once the services are running:

### Web Interface

1. Navigate to `https://localhost` or `https://sensorbridge`
   - Your browser will show a certificate warning (expected for self-signed certificates)
   - Click "Advanced" and proceed to the site
2. **Login Credentials**:
   - Username: `admin`
   - Password: Check `secrets/initial_sb_password.txt` or use the password displayed during setup
   - **Important**: Change the password immediately after first login

### MQTT Broker

Connect to the MQTT broker via WebSocket Secure (WSS):

- **Connection URL**: `wss://localhost:443/mqttproxy` or `wss://sensorbridge:443/mqttproxy`
- **Username**: `mqttclient`
- **Password**: Check `secrets/mqtt_password.txt` or use the password displayed during setup
- **Protocol**: MQTT over WebSockets (WSS)
- **Port**: 443 (HTTPS/WSS)
- **Path**: `/mqttproxy`

**Example using MQTT.js:**

```javascript
const mqtt = require("mqtt");

const client = mqtt.connect("wss://localhost:443/mqttproxy", {
  username: "mqttclient",
  password: "<your-mqtt-password>",
  rejectUnauthorized: false, // Set to true after installing root CA
});
```

**Example using mosquitto_sub:**

```bash
mosquitto_sub -h localhost -p 8883 -t 'test/topic' \
  -u mqttclient -P '<your-mqtt-password>' \
  --cafile ca/sb-root-ca.pem
```

### Installing the Root CA Certificate

To avoid certificate warnings, install the root CA certificate on your system:

**Linux:**

```bash
sudo cp ca/sb-root-ca.pem /usr/local/share/ca-certificates/sb-root-ca.crt
sudo update-ca-certificates
```

**macOS:**

```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca/sb-root-ca.pem
```

**Windows:**

1. Double-click `ca/sb-root-ca.pem`
2. Click "Install Certificate"
3. Select "Local Machine"
4. Place in "Trusted Root Certification Authorities"

## Resetting the Setup

To completely remove all generated files and start fresh:

```bash
sudo ./setup.sh reset
```

This will:

1. Check if containers are running and prompt you to stop them
2. Delete all generated directories: `ca/`, `mosquitto/`, `postgres/`, `traefik/`, `secrets/`
3. Remove the `docker-compose.yml` file

**Before resetting**, stop and remove containers:

```bash
sudo docker compose down
```

**Warning**: Reset permanently deletes all certificates, configuration, and secrets. Database data in `postgres/data/` will also be removed.

## Troubleshooting

### Script fails with "must be run with sudo"

**Solution**: Run the script with sudo: `sudo ./setup.sh`

### Docker login fails for dhi.io

**Solution**:

1. Ensure you have a Docker Hub account
2. Login manually first: `sudo docker login dhi.io`
3. Re-run the setup script

### Permission denied errors

**Solution**: Ensure the script is executable:

```bash
chmod +x setup.sh
sudo ./setup.sh
```

### Containers fail to start

**Solution**: Check logs for specific errors:

```bash
sudo docker compose logs
```

Common issues:

- Port conflicts: Another service may be using ports 80/443
- File permissions: Re-run the setup script to fix permissions

### Certificate warnings persist

**Solution**: Install the root CA certificate on your system (see "Installing the Root CA Certificate" above)

### Can't find generated passwords or master key

**Solution**: All passwords and the master key are stored in the `secrets/` directory:

```bash
cat secrets/initial_sb_password.txt      # SensorBridge admin password
cat secrets/mqtt_password.txt            # MQTT client password
cat secrets/sb_masterkey.txt             # Database encryption master key
cat secrets/postgres_password_pg.txt     # PostgreSQL password (for DB)
cat secrets/postgres_password_sb.txt     # PostgreSQL password (for SensorBridge)
```

### Invalid SAN entry error during setup

**Solution**: When entering additional SAN entries for the Traefik certificate, ensure correct format:

- Valid formats: `DNS:hostname.com` or `IP:192.168.1.100`
- Multiple entries: `DNS:host1.com,DNS:host2.com,IP:192.168.1.100`
- Each entry must start with `DNS:` or `IP:`
- DNS names must be valid hostnames (alphanumeric, dots, hyphens)
- IP addresses must be valid IPv4 (e.g., 192.168.1.100) or IPv6 format

### MQTT connection fails

**Solution**:

1. Verify the connection URL includes the correct path: `wss://localhost:443/mqttproxy`
2. Check the MQTT credentials in `secrets/mqtt_password.txt`
3. Ensure the root CA certificate is trusted or set `rejectUnauthorized: false` for testing
4. Verify containers are running: `sudo docker compose ps`

## Next Steps

After successful setup:

1. **CRITICAL: Backup the master key** from `secrets/sb_masterkey.txt` to a secure location (password manager, encrypted vault, etc.)
2. **Backup all secrets and certificates**:
   - `secrets/` directory (contains all passwords and master key)
   - `ca/sb-root-ca.key` and `ca/sb-root-ca.pem` (root CA)
   - `postgres/data/` directory (database data)
3. **Start the services**: `sudo docker compose up -d`
4. **Install the root CA certificate** on your system to avoid browser warnings (see instructions above)
5. **Access the SensorBridge Web Interface** at `https://localhost`
6. **Change the admin password** immediately after first login
7. **Test MQTT connectivity** using the credentials displayed during setup
8. **Configure your sensors and devices** through the web interface

## Additional Resources

- [SensorBridge Documentation](https://docs.nexy.net)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Mosquitto MQTT Documentation](https://mosquitto.org/documentation/)

## Support

For issues or questions, please contact your system administrator or refer to the main project documentation.
