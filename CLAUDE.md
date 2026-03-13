# CLAUDE.md — sb-setup

Shared conventions (language, terminology, proofreading) are defined in the parent workspace `CLAUDE.md`.

## Project Overview

Automated, production-ready Docker Compose setup for the steute Sensor Bridge. The `setup.sh` script generates TLS certificates, configuration files, secrets, and a customised `docker-compose.yml`.

## Requirements

- **OS:** Linux (Debian tested), amd64/x86_64
- **Docker:** current stable version
- **OpenSSL:** Required for CA and certificate generation
- **Privileges:** Must run with `sudo`

## Services (generated)

- **Sensor Bridge** — Main application.
- **PostgreSQL** Database with certificate-based authentication.
- **Mosquitto** MQTT broker with TLS and password auth.
- **Traefik** Reverse proxy, HTTPS on port 443.
- **Docker Socket Proxy** — Restricts Docker socket access.

## Usage

See `USAGE.md`.

## Key Directories

- **`ca/`** — Generated CA and signed certificates.
- **`secrets/`** — Generated passwords (PostgreSQL, MQTT, SB master key).
- **`templates/`** — Source templates for generated config files.
- **`mosquitto/`**, **`postgres/`**, **`traefik/`** — Generated service configurations.

## Conventions

- All inter-service communication uses TLS.
- Secrets are generated randomly during setup and stored with restricted permissions.
- The script supports two Docker registries: dhi.io (recommended) or public Docker Hub.
