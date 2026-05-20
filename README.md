# Secure Sensor Bridge Docker Setup

Version 0.3.0

## About

This repository provides a script that generates:

- a Docker Compose file
- configuration files
- TLS certificates

for setting up a secure production ready instance of the steute Sensor Bridge application with Docker Compose.

To quickly set up a Sensor Bridge instance for testing, follow the [simple Docker Compose setup instructions](./SIMPLE_SETUP.md).

**TODO: Add a link to the public documentation once it is published.**

## Requirements

- Docker Engine (version 29 or later)
- OpenSSL
- Linux system (tested on `amd64`/`x86_64` Debian 12 Bookworm)
- Root access (sudo)

## Usage

Please refer to the document [`USAGE.md`](./USAGE.md) for instructions on how to use the setup script.

## Latest Image Versions

As of May. 20, 2026, the script generates a Docker Compose file using these image versions:

- `steute/sensor-bridge:3.0.4`
- `postgres:18.4-alpine3.23`
- `eclipse-mosquitto:2.1-alpine`
- `lscr.io/linuxserver/socket-proxy:latest`
- `traefik:3.7`
- `nodered/node-red:4.1.10-22`

Other versions of the Postgres, Mosquitto, Socket-Proxy, and Traefik images may work, but Steute has not tested them.

For older versions of the Sensor Bridge application, please refer to the [release notes]().

**TODO: Add a link to the release notes once they are published.**

## Further Documentation

For more detailed documentation and setup options see [the steute internal docs](https://gitlab-nexy.steute.it-root.com/nexy/nexy-documentation/-/blob/E6489-66/SB3-and-Node-RED-setup/private/versioned_docs/version-3.0.x/10-sensor-bridge/15-secure-docker-setup.md?ref_type=heads) or the [staging documentation](https://staging-docs.nexy.net/private/docs/sensor-bridge/secure-docker-setup).

**TODO: Change the documentation links to the public documentation once the documentation is published.**
