# Deploying Docker registry server for the MaxScale

## Requirements for the registry

The [Docker registry](https://docs.docker.com/registry/) is a service that allows to store and extract the image containers. For MaxScale such registry is needed for the system testing during the CI-process.

In our setup the registry is required to process requests from up to 3 build servers and up to 10 clients at the same time. The registry itself and its' contents can be rebuild at any time. This way we do not need to provide high availability for such registry and the simplest setup suites our needs.

The registry should not be put public. For our installation simple basic HTTP authentication should be sufficient.

The installation will include only the Docker registry service that is run in the Docker Swarm mode.

- Docker registry service.

The official documentation contains a [recipe](https://docs.docker.com/registry/#run-an-externally-accessible-registry) for such setup.

## Dependency installation

The following dependencies are needed to be installed:

- Docker. Follow official installation [instructions](https://docs.docker.com/install/linux/docker-ce/ubuntu/).
- Docker Compose. Follow official [installation instructions](https://docs.docker.com/compose/install/).

## Authentication

Create a password file that will contain all the required passwords:

```
sudo mkdir -p /srv/repository/docker-registry/auth
sudo touch /srv/repository/docker-registry/auth/docker-registry.htpasswd
sudo htpasswd -B /srv/repository/docker-registry/auth/docker-registry.htpasswd USER
```
The password will be asked on the command prompt.

### Adding new user to the list of authenticated ones

Use the following line to create new user. The parameter `-B` is mandatory. Substitute the `USER` with required user name.

```bash
sudo htpasswd -B /srv/repository/docker-registry/auth/docker-registry.htpasswd USER
```

## Docker registry

The registry is deployed using Docker Compose. See the `docker-compose.yaml` for more information.

In order to deploy the service please configure authentication and use the following commands to deploy the registry:

```
sudo mkdir -p /srv/repository/docker-registry/registry
docker-compose up -d
```

## Nginx configuration

Nginx server will redirect to the 5000 port that is used to provide registry services. This part is not required, but used for the convenience only.

Copy the `docker-registry.nginx` file to the `/etc/nginx/sites-available`, create the symbolic link to this file into the directory `/etc/nginx/sites-enabled` and reconfigure the Nginx.
