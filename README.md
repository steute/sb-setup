# Secure Sensor Bridge Docker Setup

Version 0.0.1

## About

This repository provides a script that generates:

- a docker compose file
- configuration files
- TLS certificates

for setting up a secure production ready instance of the steute Sensor Bridge application.

## Requirements

- Docker Engine (version 29 or later)
- OpenSSL
- Linux system (tested on `amd64`/`x86_64` Debian 12 Bookworm)
- Root access (sudo)

## Usage

_Please refer to the documentation link, provided below, for detailed instructions on how to use the setup script and for troubleshooting._

Run the setup script with sudo: `sudo ./setup.sh` and follow the instructions.

To clean up all generated files, run `sudo ./setup.sh reset`.

## Documentation

For documentation see [the steute internal docs](https://gitlab-nexy.steute.it-root.com/nexy/nexy-documentation/-/blob/E6489-66/SB3-and-Node-RED-setup/private/versioned_docs/version-3.0.x/10-sensor-bridge/15-secure-docker-setup.md?ref_type=heads) or the [staging documentation](https://staging-docs.nexy.net/private/docs/sensor-bridge/secure-docker-setup).

**WIP: Change the documentation links to the public documentation once the documentation is published.**