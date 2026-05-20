# Check for latest versions of Docker images

If you update the versions, you have to update these files:

- `templates/docker-compose.yml` - edit this file first
- `README.md` (under "Latest Image Versions", use the `update-versions.sh` script)
- `setup.sh` (the mosquitto versions, used to create the password file for the mosquitto user)

## Sensor Bridge

Version 3.

- Image: https://hub.docker.com/repository/docker/steute/sensor-bridge/tags
- Release notes: (TBD)

## PostgreSQL

Version 18, Alpine based.

- Hardened Image: https://hub.docker.com/hardened-images/catalog/dhi/postgres/images
- Standard Image: https://hub.docker.com/_/postgres/tags?name=18-alpine
- Release notes: https://www.postgresql.org/docs/release/

## Mosquitto

Version 2.1.

- Hardened Image: https://hub.docker.com/hardened-images/catalog/dhi/eclipse-mosquitto/images
- Standard Image: https://hub.docker.com/_/eclipse-mosquitto/tags
- Release notes: https://mosquitto.org/blog/categories/releases/ and https://mosquitto.org/ChangeLog.txt

## Traefik

Version 3.7.

- Hardened Image: https://hub.docker.com/hardened-images/catalog/dhi/traefik/images
- Standard Image: https://hub.docker.com/_/traefik/tags
- Release notes: https://github.com/traefik/traefik/releases

## Node-RED

Version 4.

- Image: https://hub.docker.com/r/nodered/node-red/tags
- Release notes: https://github.com/node-red/node-red/releases
