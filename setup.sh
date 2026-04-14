#!/bin/bash

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CA_DIR="${SCRIPT_DIR}/ca"
MOSQUITTO_DIR="${SCRIPT_DIR}/mosquitto"
POSTGRES_DIR="${SCRIPT_DIR}/postgres"
NODE_RED_DIR="${SCRIPT_DIR}/node-red"
TRAEFIK_DIR="${SCRIPT_DIR}/traefik"

# Functions
print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 1. Check system requirements
check_system_requirements() {
    print_info "Checking system requirements..."
    
    # Check if script was started with sudo
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run with sudo for administrative rights"
        exit 1
    fi
    print_success "Running with administrative rights"
    
    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker Engine first."
        exit 1
    fi
    print_success "Docker is installed"
    
    # Check if openssl is available
    if ! command -v openssl &> /dev/null; then
        print_error "OpenSSL is not installed. Please install OpenSSL first."
        exit 1
    fi
    print_success "OpenSSL is available"
}

# 2. Check for reset parameter
handle_reset() {
    if [[ "${1:-}" == "reset" ]]; then
        print_warning "Reset mode: Deleting generated configuration files, certificates, and data..."
        
        # Check if docker-compose.yml exists and check for running containers
        if [[ -f "${SCRIPT_DIR}/docker-compose.yml" ]]; then
            print_info "Checking for running containers..."
            cd "$SCRIPT_DIR"
            
            # Check if any containers from this compose file are running
            if docker compose ps --quiet 2>/dev/null | grep -q .; then
                print_warning "Docker containers related to this application are currently running"
                print_warning "Please stop and remove these containers manually before running reset:"
                print_info "  sudo docker compose down"
                read -p "Have you stopped and removed the containers? (y/N): " -r response
                if [[ ! "$response" =~ ^[Yy]$ ]]; then
                    print_info "Reset cancelled"
                    exit 0
                fi
            fi
        fi
        
        print_warning "This will delete all generated configuration, certificates, secrets, and data." 
        read -p "Do you want to continue with reset? (y/N): " -r reset_confirm
        if [[ ! "$reset_confirm" =~ ^[Yy]$ ]]; then
            print_info "Reset cancelled"
            exit 0
        fi

        if [[ -d "$CA_DIR" ]]; then
            rm -rf "$CA_DIR"
            print_success "Removed ca directory"
        fi

        if [[ -d "$MOSQUITTO_DIR" ]]; then
            rm -rf "$MOSQUITTO_DIR"
            print_success "Removed mosquitto directory"
        fi

        if [[ -d "$POSTGRES_DIR" ]]; then
            rm -rf "$POSTGRES_DIR"
            print_success "Removed postgres directory"
        fi

        if [[ -d "${SCRIPT_DIR}/secrets" ]]; then
            rm -rf "${SCRIPT_DIR}/secrets"
            print_success "Removed secrets directory"
        fi

        if [[ -d "$TRAEFIK_DIR" ]]; then
            rm -rf "$TRAEFIK_DIR"
            print_success "Removed traefik directory"
        fi

        if [[ -d "$NODE_RED_DIR" ]]; then
            rm -rf "$NODE_RED_DIR"
            print_success "Removed node-red directory"
        fi
        
        if [[ -f "${SCRIPT_DIR}/docker-compose.yml" ]]; then
            rm -f "${SCRIPT_DIR}/docker-compose.yml"
            print_success "Removed docker-compose.yml"
        fi
        
        print_success "Reset complete. You can now run the setup again."
        exit 0
    fi
}

# 3. Check if script was already run
check_existing_setup() {
    if [[ -f "${SCRIPT_DIR}/docker-compose.yml" ]]; then
        print_warning "docker-compose.yml already exists"
        read -p "Do you want to continue and overwrite existing files? (y/N): " -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_info "Setup cancelled"
            exit 0
        fi
    fi
}

# 4. Make the user choose to use the "dhi.io" docker registry
choose_docker_registry() {
    print_info "Docker Registry Configuration"
    print_info "The default setup requires pulling images from the 'dhi.io' registry."
    print_info "This requires authentication via a valid docker account (usage is free)."
    echo ""
    read -p "Do you want to use the 'dhi.io' registry? (Y/n): " -r use_registry
    use_registry="${use_registry:-Y}"
    
    if [[ "$use_registry" =~ ^[Yy]$ ]]; then
        # Check if docker login to dhi.io works
        print_info "Checking Docker authentication for dhi.io..."
        if ! docker login dhi.io 2>/dev/null; then
            print_error "Docker login to dhi.io failed"
            print_info "Please run 'sudo docker login dhi.io' first to authenticate"
            exit 1
        fi
        print_success "Docker Hub authentication successful"
        USE_DHI_IO=true
    else
        print_info "You have chosen not to use the 'dhi.io' registry"
        USE_DHI_IO=false
    fi
}

# 5. Ask whether Node-RED should be included
choose_node_red() {
    print_info "Optional Node-RED Configuration"
    read -p "Do you want to include a Node-RED instance? (y/N): " -r use_node_red
    use_node_red="${use_node_red:-N}"

    if [[ "$use_node_red" =~ ^[Yy]$ ]]; then
        USE_NODE_RED=true
        print_success "Node-RED will be included"
    else
        USE_NODE_RED=false
        print_info "Node-RED will not be included"
    fi
}

# 6. Make a copy of the template docker-compose file
setup_docker_compose() {
    print_info "Setting up docker-compose.yml..."
    
    TEMPLATE_FILE="${SCRIPT_DIR}/templates/docker-compose.yml"
    COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
    
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        print_error "Template file not found: $TEMPLATE_FILE"
        exit 1
    fi
    
    # Copy template to docker-compose.yml
    cp "$TEMPLATE_FILE" "$COMPOSE_FILE"
    print_success "Copied template to docker-compose.yml"
    
    # If not using dhi.io, remove the registry prefix from all image references
    if [[ "$USE_DHI_IO" == false ]]; then
        print_info "Removing dhi.io registry prefix from image references..."
        sed -i 's|dhi\.io/||g' "$COMPOSE_FILE"
        print_success "Updated docker-compose.yml to use alternative images"
    fi

    if [[ "$USE_NODE_RED" == false ]]; then
        print_info "Removing Node-RED service and secrets from docker-compose.yml..."
        sed -i '/^  node-red:$/,/^networks:$/d' "$COMPOSE_FILE"
        sed -i '/^  node-red-admin-password:$/,+1d' "$COMPOSE_FILE"
        sed -i '/^  sb-rest-api-password:$/,+1d' "$COMPOSE_FILE"
        print_success "Removed Node-RED service and secrets from docker-compose.yml"
    fi
}

# 7. Create local CA and generate certificates
create_certificates() {
    print_info "Creating certificates and local CA..."
    
    # Create ca directory
    mkdir -p "$CA_DIR"
    cd "$CA_DIR"
    
    print_info "Enter certificate information (press Enter to use default values):"
    
    # Get user input for certificate details
    read -p "Country Name (C) [DE]: " -r C
    C="${C:-DE}"
    
    read -p "State/Province (ST) [NRW]: " -r ST
    ST="${ST:-NRW}"
    
    read -p "Locality (L) [Loehne]: " -r L
    L="${L:-Loehne}"
    
    read -p "Organization (O) [SensorBridgeTesting]: " -r O
    O="${O:-SensorBridgeTesting}"
    
    read -p "Organizational Unit (OU) [IoT]: " -r OU
    OU="${OU:-IoT}"
    
    read -p "Common Name (CN) [Internal-SensorBridge-CA]: " -r CN
    CN="${CN:-Internal-SensorBridge-CA}"
    
    # Create the root key
    print_info "Creating root CA key..."
    openssl genrsa -out sb-root-ca.key 4096
    
    # Set appropriate permissions
    chmod 600 sb-root-ca.key
    print_success "Root CA key created with secure permissions"
    
    # Create self-signed root certificate (valid for 25 years)
    print_info "Creating self-signed root certificate (valid for 25 years)..."
    openssl req -x509 -new -nodes -key sb-root-ca.key \
      -sha256 -days 9150 \
      -out sb-root-ca.pem \
      -subj "/C=${C}/ST=${ST}/L=${L}/O=${O}/OU=${OU}/CN=${CN}"

    print_success "Root CA certificate created"
    print_info "Root certificate: ${CA_DIR}/sb-root-ca.pem"
    print_info "Root key: ${CA_DIR}/sb-root-ca.key"
}

# 8. Create MQTT broker certificate signed by CA
create_mqtt_broker_certificate() {
    print_info "Creating MQTT broker certificate signed by CA..."
    
    cd "$SCRIPT_DIR"
    mkdir -p mosquitto
    
    # Create CSR and key for broker
    print_info "Creating certificate signing request for MQTT broker..."
    openssl req -new -newkey rsa:2048 -nodes \
        -keyout mosquitto/mqtt-broker-internal-key.pem \
        -out mosquitto/mqtt-broker-internal.csr \
        -subj "/C=DE/O=MosquittoInternal/OU=IoT/CN=mosquitto.internal.local"
    
    # Sign with CA (valid for 20 years)
    print_info "Signing MQTT broker certificate with CA (valid for 20 years)..."
    openssl x509 -req -in mosquitto/mqtt-broker-internal.csr \
        -CA "${CA_DIR}/sb-root-ca.pem" -CAkey "${CA_DIR}/sb-root-ca.key" -CAcreateserial \
        -out mosquitto/mqtt-broker-internal.pem -days 7300 -sha256 \
        -extfile <(printf "subjectAltName=DNS:mosquitto,DNS:localhost,DNS:host.docker.internal,IP:127.0.0.1")

    # Private keys need to be readable by root and the group of the process running the container with permissions 640
    chmod 640 mosquitto/mqtt-broker-internal-key.pem
    if [[ "$USE_DHI_IO" == false ]]; then
        # If not using dhi.io, we assume the mosquitto container will run with user 1883
        sudo chown "0:1883" mosquitto/mqtt-broker-internal-key.pem
    else
        # If using dhi.io, the mosquitto container runs with user 65532 (nobody), so we set group ownership to 65532
        sudo chown "0:65532" mosquitto/mqtt-broker-internal-key.pem
    fi
    
    print_success "MQTT broker certificate created"
    print_info "MQTT broker certificate: ${SCRIPT_DIR}/mosquitto/mqtt-broker-internal.pem"
    print_info "MQTT broker key: ${SCRIPT_DIR}/mosquitto/mqtt-broker-internal-key.pem"
}

# 9. Copy mosquitto configuration template
setup_mosquitto_config() {
    print_info "Setting up Mosquitto configuration..."
    
    mkdir -p "$MOSQUITTO_DIR"
    cp templates/mosquitto.conf "$MOSQUITTO_DIR/mosquitto.conf"
    
    print_success "Mosquitto configuration file created"
}

# 10. Create mosquitto password file
setup_mosquitto_password() {
    print_info "Creating Mosquitto password file..."
    
    cd "$SCRIPT_DIR"
    
    # Create secrets directory if it doesn't exist
    mkdir -p secrets
    
    # Generate unique password for MQTT client
    print_info "Generating unique password for MQTT client..."
    openssl rand -base64 32 | tr '+/LlO' 'ps11o' | tr -d '=' > secrets/mqtt_password.txt
    print_success "MQTT password generated and stored in secrets/mqtt_password.txt"
    
    # Create mosquitto password file
    print_info "Creating Mosquitto password file with mosquitto_passwd tool..."
    sudo touch "$MOSQUITTO_DIR/mosquitto.pass"
    
    # Run mosquitto_passwd inside the container
    print_info "Creating Mosquitto password file with mqtt_passwd tool..."
    docker run --rm \
      -v "$MOSQUITTO_DIR":/tmp/mosquitto eclipse-mosquitto:2.0 \
      mosquitto_passwd -b -c /tmp/mosquitto/mosquitto.pass mqttclient "$(cat ./secrets/mqtt_password.txt)"
    
    print_success "Mosquitto password file created"
}

# 11. Create PostgreSQL certificate signed by CA
create_postgres_certificate() {
    print_info "Creating PostgreSQL certificate signed by CA..."

    cd "$SCRIPT_DIR"
    mkdir -p "$POSTGRES_DIR"

    # Create CSR and key for postgres
    print_info "Creating certificate signing request for PostgreSQL..."
    openssl req -new -newkey rsa:2048 -nodes \
        -keyout "$POSTGRES_DIR/postgres-internal-key.pem" \
        -out "$POSTGRES_DIR/postgres-internal.csr" \
        -subj "/C=DE/O=PostgresqlInternal/OU=IoT/CN=postgres.internal.local"

    # Sign with CA (valid for 20 years)
    print_info "Signing PostgreSQL certificate with CA (valid for 20 years)..."
    openssl x509 -req -in "$POSTGRES_DIR/postgres-internal.csr" \
        -CA "${CA_DIR}/sb-root-ca.pem" -CAkey "${CA_DIR}/sb-root-ca.key" -CAcreateserial \
        -out "$POSTGRES_DIR/postgres-internal.pem" -days 7300 -sha256 \
        -extfile <(printf "subjectAltName=DNS:postgres,DNS:localhost,DNS:host.docker.internal,IP:127.0.0.1")

    # Private keys need to be readable by root and the group of the process running the container with permissions 640
    chmod 640 "$POSTGRES_DIR/postgres-internal-key.pem"
    sudo chown "0:70" "$POSTGRES_DIR/postgres-internal-key.pem"

    print_success "PostgreSQL certificate created"
    print_info "PostgreSQL certificate: ${POSTGRES_DIR}/postgres-internal.pem"
    print_info "PostgreSQL key: ${POSTGRES_DIR}/postgres-internal-key.pem"
}

# 12. Copy pg_hba.conf and prepare postgres data folder
setup_postgres_config() {
    print_info "Setting up PostgreSQL configuration..."

    mkdir -p "$POSTGRES_DIR"
    cp templates/pg_hba.conf "$POSTGRES_DIR/pg_hba.conf"
    mkdir -p "$POSTGRES_DIR/data"

    print_info "Changing ownership of postgres folder to group 70 (postgres)..."
    sudo chown -R 0:70 "$POSTGRES_DIR"
    sudo chmod 0775 "$POSTGRES_DIR/data"

    print_success "PostgreSQL configuration prepared"
}

# 13. Create PostgreSQL password secret
setup_postgres_password() {
    print_info "Creating PostgreSQL password secret..."

    mkdir -p "${SCRIPT_DIR}/secrets"
    openssl rand -base64 32 | tr '+/LlO' 'ps11o' | tr -d '=' > "${SCRIPT_DIR}/secrets/postgres_password_pg.txt"
    # We need a copy, because the file permissions and ownership need to be different for the postgres container and the sensor bridge container
    cp "${SCRIPT_DIR}/secrets/postgres_password_pg.txt" "${SCRIPT_DIR}/secrets/postgres_password_sb.txt"

    print_success "PostgreSQL password generated and stored in secrets/postgres_password_pg.txt and secrets/postgres_password_sb.txt"
}

# 14. Create master key for database encryption
setup_masterkey() {
    print_info "Creating SensorBridge masterkey..."

    mkdir -p "${SCRIPT_DIR}/secrets"
    openssl rand -base64 32 | tr '+/LlO' 'ps11o' | tr -d '=' > "${SCRIPT_DIR}/secrets/sb_masterkey.txt"

    print_success "Masterkey created at secrets/sb_masterkey.txt"
    print_warning "Store this masterkey in a safe place. If lost, encrypted data is unrecoverable."
}

# 15. Create initial admin password
setup_initial_admin_password() {
    print_info "Setting initial admin password for SensorBridge web interface..."

    mkdir -p "${SCRIPT_DIR}/secrets"
    read -p "Do you want a randomly generated initial password? (Y/n): " -r use_random
    use_random="${use_random:-Y}"

    if [[ "$use_random" =~ ^[Yy]$ ]]; then
        local random_password
        random_password=$(openssl rand -base64 10 | tr '+/LlO' 'ps11o' | tr -d '=')
        echo "$random_password" > "${SCRIPT_DIR}/secrets/initial_sb_password.txt"
        print_success "Initial password generated and stored in secrets/initial_sb_password.txt"
        print_info "Initial login username: admin"
        print_info "Initial login password: ${random_password}"
    else
        local password
        local confirm_password
        while true; do
            read -s -p "Enter initial admin password: " password
            echo ""
            read -s -p "Confirm initial admin password: " confirm_password
            echo ""

            if [[ -z "$password" ]]; then
                print_warning "Password cannot be empty. Please try again."
                continue
            fi

            if [[ "$password" != "$confirm_password" ]]; then
                print_warning "Passwords do not match. Please try again."
                continue
            fi

            echo "$password" > "${SCRIPT_DIR}/secrets/initial_sb_password.txt"
            print_success "Initial password saved in secrets/initial_sb_password.txt"
            print_info "Initial login username: admin"
            break
        done
    fi
}

# 16. Setup optional Node-RED configuration
setup_node_red_config() {
    if [[ "$USE_NODE_RED" == false ]]; then
        return
    fi

    print_info "Setting up optional Node-RED configuration..."

    mkdir -p "${SCRIPT_DIR}/secrets"

    openssl rand -base64 32 | tr '+/LlO' 'ps11o' | tr -d '=' > "${SCRIPT_DIR}/secrets/node-red-admin-password-plain.txt"
    openssl rand -base64 32 | tr '+/LlO' 'ps11o' | tr -d '=' > "${SCRIPT_DIR}/secrets/sb-rest-api-password.txt"

    # Determine the Node-RED image tag from the generated docker-compose.yml.
    local node_red_image
    node_red_image=$(awk '
        $1 == "node-red:" { in_node_red = 1; next }
        in_node_red && $1 == "image:" { print $2; exit }
        in_node_red && /^[^[:space:]]/ { in_node_red = 0 }
    ' "${SCRIPT_DIR}/docker-compose.yml")

    # Remove optional surrounding quotes in case the image value is quoted.
    node_red_image="${node_red_image#\"}"
    node_red_image="${node_red_image%\"}"

    # fallback to default image if not found in docker-compose.yml
    if [[ -z "$node_red_image" ]]; then
        node_red_image="nodered/node-red:latest"
        print_warning "Could not determine Node-RED image from docker-compose.yml, using default: $node_red_image"
    fi

    # Hash the plain password for Node-RED adminAuth secret file.
    local node_red_admin_password_plain
    local node_red_admin_password_hash
    local node_red_hash_output

    node_red_admin_password_plain=$(cat "${SCRIPT_DIR}/secrets/node-red-admin-password-plain.txt")
    if [[ -z "$node_red_admin_password_plain" ]]; then
        print_error "Node-RED admin plain password file is empty"
        exit 1
    fi

    print_info "Hashing Node-RED admin password using temporary container image: $node_red_image"
    if ! node_red_hash_output=$(printf "%s\n%s\n" "$node_red_admin_password_plain" "$node_red_admin_password_plain" | \
        docker run --rm -i --entrypoint node-red-admin "$node_red_image" hash-pw 2>&1); then
        print_error "Failed to hash Node-RED admin password with image: $node_red_image"
        exit 1
    fi

    node_red_admin_password_hash=$(printf "%s\n" "$node_red_hash_output" | tr -d '\r' | \
        grep -Eo '\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53}' | tail -n 1)

    if [[ -z "$node_red_admin_password_hash" ]]; then
        print_error "Generated Node-RED admin password hash is empty or invalid"
        exit 1
    fi

    printf "%s\n" "$node_red_admin_password_hash" > "${SCRIPT_DIR}/secrets/node-red-admin-password.txt"

    chmod 640 "${SCRIPT_DIR}/secrets/node-red-admin-password.txt"
    chmod 640 "${SCRIPT_DIR}/secrets/node-red-admin-password-plain.txt"
    chmod 640 "${SCRIPT_DIR}/secrets/sb-rest-api-password.txt"

    mkdir -p "$NODE_RED_DIR/data"
    sudo chown 1000:1000 "$NODE_RED_DIR/data"

    cp "${SCRIPT_DIR}/templates/settings.js" "$NODE_RED_DIR/settings.js"

    print_success "Node-RED secrets and configuration prepared"
}

# 17. Setup traefik configuration folder
setup_traefik_config() {
    print_info "Setting up Traefik reverse proxy configuration..."

    mkdir -p "$TRAEFIK_DIR"
    cp templates/traefik-tls-config.yaml "$TRAEFIK_DIR/traefik-tls-config.yaml"

    print_success "Traefik configuration file created"
}

# Helper function to validate SAN entries
validate_san_entries() {
    local input="$1"
    
    # Empty input is valid (use defaults)
    if [[ -z "$input" ]]; then
        return 0
    fi
    
    # Split by comma and validate each entry
    IFS=',' read -ra entries <<< "$input"
    for entry in "${entries[@]}"; do
        # Trim whitespace
        entry=$(echo "$entry" | xargs)
        
        # Check if it starts with DNS: or IP:
        if [[ ! "$entry" =~ ^(DNS|IP): ]]; then
            print_error "Invalid SAN entry: '$entry' - Must start with 'DNS:' or 'IP:'"
            print_info "Example: DNS:example.com or IP:192.168.1.100"
            return 1
        fi
        
        # Extract type and value
        local type="${entry%%:*}"
        local value="${entry#*:}"
        
        # Check if value is empty
        if [[ -z "$value" ]]; then
            print_error "Invalid SAN entry: '$entry' - Value cannot be empty"
            return 1
        fi
        
        # Validate based on type
        if [[ "$type" == "DNS" ]]; then
            # Basic DNS validation: alphanumeric, dots, hyphens, must not start/end with hyphen or dot
            if [[ ! "$value" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?)*$ ]]; then
                print_error "Invalid DNS name: '$value' - Must be a valid hostname (alphanumeric, dots, hyphens)"
                return 1
            fi
        elif [[ "$type" == "IP" ]]; then
            # IPv4 validation
            if [[ "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                # Check each octet is 0-255
                IFS='.' read -ra octets <<< "$value"
                if [[ ${#octets[@]} -ne 4 ]]; then
                    print_error "Invalid IPv4 address: '$value' - Must have 4 octets"
                    return 1
                fi
                for octet in "${octets[@]}"; do
                    if [[ "$octet" -gt 255 ]] || [[ "$octet" -lt 0 ]]; then
                        print_error "Invalid IPv4 address: '$value' - Octets must be 0-255"
                        return 1
                    fi
                done
            # IPv6 validation (basic)
            elif [[ "$value" =~ ^[0-9a-fA-F:]+$ ]]; then
                # Basic IPv6 check (has colons and hex digits)
                if [[ ! "$value" =~ : ]]; then
                    print_error "Invalid IPv6 address: '$value'"
                    return 1
                fi
            else
                print_error "Invalid IP address: '$value' - Must be a valid IPv4 or IPv6 address"
                return 1
            fi
        fi
    done
    
    return 0
}

# 18. Create Traefik reverse proxy certificate signed by CA
create_traefik_certificate() {
    print_info "Creating Traefik reverse proxy certificate signed by CA..."

    mkdir -p "$TRAEFIK_DIR"

    print_info "Enter additional SAN entries for Traefik certificate (or press Enter for defaults)"
    print_info "Default SAN entries: DNS:sensorbridge, DNS:localhost, DNS:host.docker.internal, IP:127.0.0.1"
    print_info "Format: DNS:hostname or IP:address (comma-separated for multiple entries)"
    
    # Loop until valid input or empty
    local additional_sans=""
    while true; do
        read -p "Additional SAN entries: " -r additional_sans
        
        # Validate input
        if validate_san_entries "$additional_sans"; then
            break
        fi
        print_warning "Please enter valid SAN entries or press Enter to use defaults only"
    done
    
    # Build the SAN string
    local san_string="subjectAltName=DNS:sensorbridge,DNS:localhost,DNS:host.docker.internal,IP:127.0.0.1"
    if [[ -n "$additional_sans" ]]; then
        # Remove spaces around commas for clean concatenation
        additional_sans=$(echo "$additional_sans" | sed 's/[[:space:]]*,[[:space:]]*/,/g')
        san_string="${san_string},${additional_sans}"
    fi

    # Create CSR and key for Traefik
    print_info "Creating certificate signing request for Traefik..."
    openssl req -new -newkey rsa:2048 -nodes \
        -keyout "$TRAEFIK_DIR/traefik-external-key.pem" \
        -out "$TRAEFIK_DIR/traefik-external.csr" \
        -subj "/C=DE/O=SensorBridge/OU=IoT/CN=sensorbridge.internal.local"

    # Sign with CA (valid for 5 years)
    print_info "Signing Traefik certificate with CA (valid for 5 years)..."
    openssl x509 -req -in "$TRAEFIK_DIR/traefik-external.csr" \
        -CA "${CA_DIR}/sb-root-ca.pem" -CAkey "${CA_DIR}/sb-root-ca.key" -CAcreateserial \
        -out "$TRAEFIK_DIR/traefik-external.pem" -days 1825 -sha256 \
        -extfile <(printf "%s" "$san_string")

    # Private keys need to be readable by root and the group of the process running the container with permissions 640
    sudo chmod 640 "$TRAEFIK_DIR/traefik-external-key.pem"
    if [[ "$USE_DHI_IO" == false ]]; then
        # If not using dhi.io, we assume the traefik container will run with user 0
        sudo chown "0:0" "$TRAEFIK_DIR/traefik-external-key.pem"
    else
        # If using dhi.io, the traefik container runs with user 65532
        sudo chown "0:65532" "${TRAEFIK_DIR}/traefik-external-key.pem"
    fi

    print_success "Traefik certificate created"
    print_info "Traefik certificate: ${TRAEFIK_DIR}/traefik-external.pem"
    print_info "Traefik key: ${TRAEFIK_DIR}/traefik-external-key.pem"
}

# 19. Set user/guid and permissions for generated files and folders
set_permissions() {
    print_info "Setting permissions for generated secrets..."

    # Secrets, used by the Sensor Bridge container, need to be readable by root and group 1000 (root) with permissions 640
    sudo chown "0:1000" "${SCRIPT_DIR}/secrets"/*.txt
    sudo chmod 0640 "${SCRIPT_DIR}/secrets"/*.txt

    # The postgres password secret needs to be readable by the postgres user (group 70) with permissions 640
    sudo chown "0:70" "${SCRIPT_DIR}/secrets/postgres_password_pg.txt"
}

# Main execution
main() {
    echo "================================"
    echo "  Sensor Bridge Setup Script"
    echo "================================"
    echo ""
    
    check_system_requirements
    handle_reset "$@"
    check_existing_setup
    choose_docker_registry
    choose_node_red
    setup_docker_compose
    create_certificates
    create_mqtt_broker_certificate
    setup_mosquitto_config
    setup_mosquitto_password
    create_postgres_certificate
    setup_postgres_config
    setup_postgres_password
    setup_masterkey
    setup_initial_admin_password
    setup_node_red_config
    setup_traefik_config
    create_traefik_certificate
    set_permissions
    
    cd "$SCRIPT_DIR"
    
    echo ""
    echo "========================================"
    print_success "Setup completed successfully!"
    echo "========================================"
    echo ""
    
    # Display important credentials and information
    print_info "=== IMPORTANT INFORMATION ==="
    echo ""
    
    # SensorBridge Master Key
    print_warning "=== SensorBridge Master Key ==="
    print_warning "Master Key: $(cat ${SCRIPT_DIR}/secrets/sb_masterkey.txt)"
    print_warning "Location: ${SCRIPT_DIR}/secrets/sb_masterkey.txt"
    print_warning "IMPORTANT: Store this master key in a safe place (e.g., password manager or secure vault)."
    print_warning "           If lost, encrypted data in the database cannot be recovered!"
    echo ""
    
    # SensorBridge Web Interface Login
    print_info "=== SensorBridge Web Interface ==="
    print_info "URL: https://localhost (or https://sensorbridge or your chosen SAN entry)"
    print_info "Initial Username: admin"
    print_info "Initial Password: $(cat ${SCRIPT_DIR}/secrets/initial_sb_password.txt)"
    print_info "Location: ${SCRIPT_DIR}/secrets/initial_sb_password.txt"
    print_warning "You will need to change the password at first login. Store the new password securely."
    echo ""
    
    # MQTT Connection Information
    print_info "=== MQTT Broker Connection ==="
    print_info "Protocol: WSS (WebSocket Secure)"
    print_info "Host: localhost (or sensorbridge or your chosen SAN entry)"
    print_info "Port: 443"
    print_info "Path: /mqttproxy"
    print_info "Username: mqttclient"
    print_info "Password: $(cat ${SCRIPT_DIR}/secrets/mqtt_password.txt)"
    print_info "Location: ${SCRIPT_DIR}/secrets/mqtt_password.txt"
    print_info "Example connection: wss://localhost:443/mqttproxy"
    echo ""

    if [[ "$USE_NODE_RED" == true ]]; then
        print_info "=== Node-RED Integration ==="
        print_info "Create a Sensor Bridge REST API user with these credentials:"
        print_info "Username: nodered"
        print_info "Password: $(cat ${SCRIPT_DIR}/secrets/sb-rest-api-password.txt)"
        print_info "Password location: ${SCRIPT_DIR}/secrets/sb-rest-api-password.txt"
        echo ""
        print_info "Node-RED login URL: https://localhost/nodered/admin (or your server address)"
        print_info "Node-RED Username: admin"
        print_info "Node-RED Password: $(cat ${SCRIPT_DIR}/secrets/node-red-admin-password-plain.txt)"
        print_info "Password location: ${SCRIPT_DIR}/secrets/node-red-admin-password-plain.txt"
        echo ""
    fi
    
    # Root Certificate Information
    print_info "=== Root Certificate ==="
    print_info "Location: ${SCRIPT_DIR}/ca/sb-root-ca.pem"
    print_info "This root certificate can be used to validate all self-signed server certificates."
    print_info "Install it on your system or browser to avoid browser security warnings."
    print_info "Also use it in the Access Point configuration to validate the broker's identity."
    print_info "Fingerprint (SHA256): $(openssl x509 -in ${SCRIPT_DIR}/ca/sb-root-ca.pem -noout -fingerprint -sha256 | cut -d= -f2)"
    echo ""
    
    echo "========================================"
    print_info "=== Next Steps ==="
    echo "========================================"
    print_info "1. BACKUP the secrets directory and master key to a secure location"
    print_info "2. Start the services (in this directory!): sudo docker compose up -d"
    print_info "3. Optionally install the root CA certificate to avoid browser warnings"    
    print_info "4. Access the web interface at https://localhost (or your chosen SAN entry) and log in with the initial credentials"
    print_info "5. Connect Access Points using the provided MQTT connection information."

    echo ""
}

# Run main function with all arguments
main "$@"
