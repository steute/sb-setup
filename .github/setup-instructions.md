The setup script should do these task in an interactive process:

1. Check the system requirements

- Check if the script was started using "sudo", because it needs administrative right to change permissions.
- Check if docker is installed 
- Check if "openssl" is available

2. Check for the "reset" parameter

If the script is started with the parameter "reset", it should delete all generated configuration files and certificates, so that a fresh setup can be done.

Check if any docker containers related to this application are running (see file "docker-compose.yml"), and warn the user that those containers should be stopped and removed manually before running the script with "reset". 

Inform the user, that all configuration files and certificates and data will be deleted, and ask for confirmation to continue with the reset process.

After confirming with the user, delete all generated files (in most cases it is OK to delete the complete subdirectories) and exit the script.

3. Check if the script was already run

The script creates the file "docker-compose.yml" during the first run. If this file already exists, the script should warn the user and ask if they want to continue and overwrite existing files.

4. Make the use choose to use the "dhi.io" docker registry

The default setup requires pulling some images from the Docker Hub registry "dhi.io". The use of this registry requires authentication via a valid docker account (usage is free).

Ask the user if he wants to use the "dhi.io" registry. If yes, check if "docker login dhi.io" works without asking for username and password. If the login fails, ask the user to run "sudo docker login dhi.io" first and exit the script.

If the user chooses not to use the "dhi.io" registry, the script should inform the user that he needs to provide alternative images for the required services.

5. Make a copy of the template docker-compose file in "templates/docker-compose.yml" to "docker-compose.yml" in the script folder.

If the user chose not to use the "dhi.io" registry, replace all occurrences of "dhi.io/" with "" in the copied file.

6. Create a local CA and generate certificates in the "ca" folder

Ask the user to enter the following information for the certificates, offering default values in brackets:

- C=DE 
- ST=NRW
- L=Loehne 
- O=SensorBridgeTesting 
- OU=IoT 
- CN=Internal-SensorBridge-CA

Create the root key:

```sh
openssl genrsa -out sb-root-ca.key 4096
```

Set the appropriate permissions on the key file so that only the user running the script can read it:

```sh
chmod 600 sb-root-ca.key
```

Create Self-signed root certificate (valid for 25 years), using the provided information:

```sh
openssl req -x509 -new -nodes -key sb-root-ca.key \
  -sha256 -days 9150 \
  -out sb-root-ca.pem \
  -subj "/C=DE/ST=NRW/L=Loehne/O=SensorBridgeTesting/OU=IoT/CN=Internal-SensorBridge-CA"
```

The root certificate "sb-root-ca.pem" will be used later for generating other certificates and must be trusted by clients connecting to the MQTT broker and HTTP proxy.

7. Create a self-signed certificate and key for the MQTT broker, signed by the local CA, and store it in the "mosquitto" folder.

Create the certificates:

```bash
mkdir -p mosquitto

# CSR + key for broker
openssl req -new -newkey rsa:2048 -nodes \
  -keyout mosquitto/mqtt-broker-internal-key.pem \
  -out mosquitto/mqtt-broker-internal.csr \
  -subj "/C=DE/O=MosquittoInternal/OU=IoT/CN=mosquitto.internal.local"

# Sign with CA (valid for 20 years)
openssl x509 -req -in mosquitto/mqtt-broker-internal.csr \
  -CA sb-root-ca.pem -CAkey sb-root-ca.pem -CAcreateserial \
  -out mosquitto/mqtt-broker-internal.pem -days 7300 -sha256 \
  -extfile <(printf "subjectAltName=DNS:mosquitto,DNS:localhost,DNS:host.docker.internal,IP:127.0.0.1")

# Adjust permissions on the key file so that the mosquitto broker can read it (if we run the broker as a non-root user)
chmod 644 mosquitto/mqtt-broker-internal-key.pem
```

8. Copy the "mosquitto.conf" file from the "templates" folder to the "mosquitto" folder.

```bash
cp templates/mosquitto.conf mosquitto/mosquitto.conf
```

9. Create a mosquitto password file in the "mosquitto" folder, using the mosquitto_passwd tool.

First create a unique password for the MQTT client user (default: "mqttclient"), and store it in a docker secret file called "mqtt_password" in the "secrets" folder. Create the "secrets" folder if it does not exist yet.

```bash
mkdir -p secrets
openssl rand -base64 32 | tr '+/' '__' | tr -d '=' > secrets/mqtt_password.txt
```

Then create the mosquitto password file with the following command:

```bash
sudo touch mosquitto/mosquitto.pass
```

```bash
# Run mosquitto_passwd inside the container
sudo docker run --rm \
  -v ./mosquitto:/tmp/mosquitto eclipse-mosquitto:2.0 \
  mosquitto_passwd -b -c /tmp/mosquitto/mosquitto.pass mqttclient "$(cat ./secrets/mqtt_password.txt)"
```

10. Create a self-signed certificate and key for the postgresql database signed by the local CA, and store it in the "postgres" folder.

```bash
# CSR + key
openssl req -new -newkey rsa:2048 -nodes \
  -keyout postgres/postgres-internal-key.pem \
  -out postgres/postgres-internal.csr \
  -subj "/C=DE/O=PostgresqlInternal/OU=IoT/CN=postgres.internal.local"

# Sign with CA (valid for 20 years)
openssl x509 -req -in postgres/postgres-internal.csr \
  -CA sb-root-ca.pem -CAkey sb-root-ca.key -CAcreateserial \
  -out postgres/postgres-internal.pem -days 7300 -sha256 \
  -extfile <(printf "subjectAltName=DNS:postgres,DNS:localhost,DNS:host.docker.internal,IP:127.0.0.1")

chmod 640 postgres/postgres-internal-key.pem
```

11. Copy the "pg_hba.conf" file from the "templates" folder to the "postgres" folder and create the "data" folder.

```bash
cp templates/pg_hba.conf postgres/pg_hba.conf
mkdir postgres/data
```

Change the ownership of the "postgres" folder to the user running the script, so that the postgres container can read the certificates and configuration files. The group "70" is the default group for the "postgres" user in the official postgres docker image, which is used in our setup. By setting the group ownership to "70", we ensure that the postgres container can read the files even if it runs as a non-root user.

```bash
sudo chown -R 0:70 postgres
sudo chmod 0775 postgres/data
```

12. Create a unique password for the database connection in "secrets/postgres_password.txt".

```bash
openssl rand -base64 32 | tr '+/' '__' | tr -d '=' > secrets/postgres_password.txt
```

13. Create a uniqe masterkey in "secrets/sb_masterkey.txt" for encrypting sensitive data in the database.

```bash
openssl rand -base64 32 | tr '+/' '__' | tr -d '=' > secrets/sbmasterkey.txt
```

Remind the use to store this masterkey in a safe place, as it is required to access the encrypted data in the database, and if lost, the encrypted data will be unrecoverable.

14. Ask the user if he wants a ramdom generated first time login password for the SensorBridge web interface, or if he wants to set a custom password (e.g. "steute"). 

If the user chooses to set a custom password, ask him to enter the password and confirm it by entering it twice. Store the password in "secrets/initial_sb_password.txt".

Also print the standard username "admin" for the first login.

