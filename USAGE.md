# How to Use the Setup Script

This guide explains how to use the `setup.sh` script to configure and deploy a secure Sensor Bridge instance with Docker Compose.

## Overview

The setup script automates the creation of:

- **TLS Certificates**: A local Certificate Authority (CA) and signed certificates for all services
- **Configuration Files**: Pre-configured settings for Mosquitto MQTT broker, PostgreSQL database, and Traefik reverse proxy
- **Docker Compose File**: Ready-to-use Docker Compose configuration
- **Secure Passwords**: Randomly generated passwords stored in the `secrets/` directory
- **Database Encryption Key**: Master key for encrypting sensitive data in the database
- **Optional Node-RED Integration**: Optional Node-RED service setup with generated credentials and settings

## Prerequisites

Before running the setup script, ensure you have:

- **Docker Engine** (version 29 or later) installed
- **OpenSSL** installed
- **Root/sudo access** to the system
- **Linux system** (tested on amd64/x86_64 Debian 12 Bookworm)
- **Docker Hub account** (Only if using the dhi.io registry, which is recommended for security but optional.)

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
   - Choose whether to include Node-RED
   - If enabled, note the additional Node-RED credentials shown at the end

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

It is recommended but not required to use the official `dhi.io` Docker registry for the latest and most secure images of the database, the MQTT broker and the Traefik reverse proxy.
To learn more about Docker Hardened Image (DHI) and its security benefits, visit [the Docker DHI docs](https://docs.docker.com/dhi/).

The script will prompt:

```
Do you want to use the 'dhi.io' registry? (Y/n):
```

- **Y** (recommended): Uses the official dhi.io Docker registry
  - You'll be prompted to authenticate: `sudo docker login dhi.io`
  - Follow the login prompts with your Docker Hub credentials
- **n**: Uses alternative Docker images from the public Docker Hub registry

### Step 4: Optional Node-RED Integration

The script prompts whether Node-RED should be included:

```
Do you want to include a Node-RED instance? (y/N):
```

- **y**: Includes Node-RED in the generated `docker-compose.yml` and prepares Node-RED configuration
  - Generates `secrets/node-red-admin-password.txt`
  - Generates `secrets/sb-rest-api-password.txt`
  - Creates `node-red/` and `node-red/data/`
  - Copies `templates/settings.js` to `node-red/settings.js`
- **N** (default): Removes the Node-RED service and Node-RED related secrets from the generated `docker-compose.yml`

### Step 5: Certificate Configuration

The script will generate a local Certificate Authority (CA) and sign certificates for all services. You can customize the certificate details or accept the defaults.

```
Enter certificate information (press Enter to use default values):
Country Name (C) [DE]:
State/Province (ST) [NRW]:
Locality (L) [Loehne]:
Organization (O) [SensorBridgeTesting]:
Organizational Unit (OU) [IoT]:
Common Name (CN) [Internal-SensorBridge-CA]:
```

The script will then:

- Create a root CA certificate (valid for 25 years)
- Generate certificates for MQTT broker, PostgreSQL, and Traefik (valid for 5-20 years)
- Sign all certificates with the CA

### Step 6: Initial Sensor Bridge Admin Password

```
Do you want a randomly generated initial password? (Y/n):
```

- **Y**: Generates a random password and displays it on screen
  - The password is also saved to `secrets/initial_sb_password.txt`
  - **Important**: Note this password down - you'll need it for first login
- **n**: Prompts you to enter and confirm a custom password

### Step 7: Traefik Certificate SAN Entries

All external services (Sensor Bridge web interface, MQTT broker to connect Access Points) use the Traefik certificate. By default, it includes SAN entries for `localhost`, `sensorbridge`, `host.docker.internal`, and `127.0.0.1`.

_The script generates self signed certificates. You may want to replace them by your own certificates or use services like letsencrypt in production. In that case, you need to make sure that the Traefik certificate includes SAN entries for all hostnames and IP addresses you want to use to access the web interface and MQTT broker. Please see the [advanced configuration docs](https://docs.nexy.net/TBD) for more details._ **TODO: TBD!**

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

### Step 8: Setup Complete

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
URL: https://localhost (or https://sensorbridge or your chosen SAN entry)
Initial Username: admin
Initial Password: <your-generated-password>
Location: /path/to/secrets/initial_sb_password.txt
Note: You will need to change the password at first login. Store the new password securely.
```

#### MQTT Connection Details (for Access Points)

```
=== MQTT Broker Connection ===
Protocol: WSS (WebSocket Secure)
Host: localhost (or sensorbridge or your chosen SAN entry)
Port: 443
Path: /mqttproxy
Username: mqttclient
Password: <your-generated-password>
Location: /path/to/secrets/mqtt_password.txt
Example connection: wss://localhost:443/mqttproxy
```

#### Node-RED Integration Details (If Enabled)

```
=== Node-RED Integration ===
Create a Sensor Bridge REST API user with these credentials:
Username: nodered
Password: <generated-password>
Password location: /path/to/secrets/sb-rest-api-password.txt

Node-RED login URL: https://localhost/nodered/admin (or your server address)
Node-RED Username: admin
Node-RED Password: <generated-password>
Password location: /path/to/secrets/node-red-admin-password.txt
```

Before using the integration, create a REST API user in Sensor Bridge with:

- Username: `nodered`
- Password: from `secrets/sb-rest-api-password.txt`

#### Root Certificate Information

```
=== Root Certificate ===
Location: /path/to/ca/sb-root-ca.pem
This root certificate can be used to validate all self-signed server certificates.
Install it on your system or browser to avoid browser security warnings.
Also use it in the Access Point configuration to validate the broker's identity.
Fingerprint (SHA256): <sha256-fingerprint>
```

#### Next Steps

```
=== Next Steps ===
1. BACKUP the secrets directory and master key to a secure location
2. Start the services (in this directory!): sudo docker compose up -d
3. Optionally install the root CA certificate to avoid browser warnings
4. Access the web interface at https://localhost (or your chosen SAN entry) and log in with the initial credentials
5. Connect Access Points using the provided MQTT connection information.
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
├── node-red/                           # Optional: created when Node-RED is enabled
│   ├── settings.js                     # Optional: Node-RED runtime settings
│   └── data/                           # Optional: Node-RED data directory (uid/gid 1000:1000)
└── secrets/
    ├── initial_sb_password.txt         # SensorBridge admin password
    ├── mqtt_password.txt               # MQTT client password
    ├── node-red-admin-password.txt     # Optional: Node-RED admin password
    ├── postgres_password_pg.txt        # PostgreSQL password (for DB)
    ├── postgres_password_sb.txt        # PostgreSQL password (for SensorBridge)
    ├── sb-rest-api-password.txt        # Optional: Sensor Bridge REST API password for Node-RED
    └── sb_masterkey.txt                # Database encryption key
```

### Important Security Notes

- **CRITICAL: Backup the master key** - `secrets/sb_masterkey.txt` is essential for data encryption. If lost, encrypted data cannot be recovered. Store it in a password manager or secure vault immediately.
- **Keep the `ca/` directory secure** - it contains your root CA private key which can sign certificates
- **Store all passwords securely** - all generated passwords are in the `secrets/` directory:
  - `initial_sb_password.txt` - SensorBridge web interface admin password
  - `mqtt_password.txt` - MQTT broker client password
  - `postgres_password_pg.txt` and `postgres_password_sb.txt` - PostgreSQL passwords
  - `node-red-admin-password.txt` - Node-RED admin password (if Node-RED enabled)
  - `sb-rest-api-password.txt` - Sensor Bridge REST API password for Node-RED user (if Node-RED enabled)
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

1. Navigate to `https://localhost`, `https://sensorbridge`, or your chosen SAN entry
   - Your browser will show a certificate warning (expected for self-signed certificates)
   - To avoid the warnings, install the root CA certificate (`ca/sb-root-ca.pem`) on your system or browser
   - Or click "Advanced" and proceed to the site accepting the certificate
2. **Login Credentials**:
   - Username: `admin`
   - Password: Check `secrets/initial_sb_password.txt` or use the password displayed during setup
   - **Important**: You will have to change the password immediately after first login

### Node-RED (If Enabled)

1. Navigate to `https://localhost/nodered/admin` or `https://<server-address>/nodered/admin`
2. Login with:
   - Username: `admin`
   - Password: `secrets/node-red-admin-password.txt`
3. In Sensor Bridge, create a REST API user for Node-RED:
   - Username: `nodered`
   - Password: `secrets/sb-rest-api-password.txt`

## Resetting the Setup

To completely remove all generated files and start fresh:

```bash
sudo ./setup.sh reset
```

This will:

1. Check if containers are running and prompt you to stop them
2. Delete all generated directories: `ca/`, `mosquitto/`, `postgres/`, `traefik/`, `node-red/`, `secrets/`
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

### Certificate warnings persist

**Solution**: Install the root CA certificate on your system or browser

### Can't find generated passwords or master key

**Solution**: All passwords and the master key are stored in the `secrets/` directory:

```bash
cat secrets/initial_sb_password.txt      # SensorBridge admin password
cat secrets/mqtt_password.txt            # MQTT client password
cat secrets/sb_masterkey.txt             # Database encryption master key
cat secrets/postgres_password_pg.txt     # PostgreSQL password (for DB)
cat secrets/postgres_password_sb.txt     # PostgreSQL password (for SensorBridge)
cat secrets/node-red-admin-password.txt  # Node-RED admin password (if enabled)
cat secrets/sb-rest-api-password.txt     # Sensor Bridge REST API password for Node-RED (if enabled)
```
