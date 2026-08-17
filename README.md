# Secure Sensor Bridge Docker Setup

Version 1.1.0

## About

This repository provides a script that generates:

- a Docker Compose file
- configuration files
- TLS certificates

for setting up a secure production ready instance of the steute Sensor Bridge application with Docker Compose.

To quickly set up a Sensor Bridge instance for testing, follow the [simple Docker Compose setup instructions](https://docs.nexy.net).

## Requirements

- Docker Engine (version 29 or later)
- OpenSSL
- Linux system (tested on `amd64`/`x86_64` Debian 12 Bookworm)
- Root access (sudo)

## Usage

Please refer to the document [`USAGE.md`](./USAGE.md) for instructions on how to use the setup script.

## Latest Image Versions

As of Aug. 17, 2026, the script generates a Docker Compose file using these image versions:

- `steute/sensor-bridge:3.1.4`
- `postgres:18.6-alpine3.24`
- `eclipse-mosquitto:2.1-alpine`
- `lscr.io/linuxserver/socket-proxy:latest`
- `traefik:3.7`
- `nodered/node-red:4.1.11-22`

Other versions of the Postgres, Mosquitto, Socket-Proxy, and Traefik images may work, but Steute has not tested them.

For older versions of the Sensor Bridge application, please refer to the [release notes](https://docs.next.net).

## Further Documentation

For more detailed documentation and setup options see [the online documentation](https://docs.next.net).
