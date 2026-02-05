This repository provides a docker compose file, configuration files, certificates for setting up a secure production ready instance of the steute Sensor Bridge application.

Alongside the "Sensor Bridge" software, the system requires an MQTT broker (Eclipse Mosquitto), a database (PostgreSQL) and an HTTP proxy (Traefik) for routing incoming data and handling TLS termination.

It is intended to be run on a server within a secure network environment.

## Server Requirements

- Host with at least 2 CPU cores and 2 GB RAM
- Maximum 100 MB disk space to be mounted into Docker containers
- Host system capable of running Docker Engine for linux `amd64` or `amd64` platform containers
- [Docker Engine](https://docs.docker.com/engine/install/) installed
- [Docker Compose](https://docs.docker.com/compose/) or [Docker Swarm Mode](https://docs.docker.com/engine/swarm/)

The package and script are tested on an `amd64` (`x86_64`) Debian (Bookworm, 12) host running Docker Version 29 and should work on most Linux systems.

No secret data like passwords or keys are stored in the repository. You need to provide those during setup.

The setup script "setup.sh" will guide you through the process of configuring and starting the application.

Instructions for writing the setup script are provided in the .github/setup-instructions.md file.