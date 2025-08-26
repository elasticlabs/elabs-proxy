# HTTPS Secure reverse proxy

An opinionated Secure Web Application Gateway (SWAG) &amp; HTTPS reverse application proxy for your dockerized software stacks! This stack implements the following building blocks : 

- [Secure Web Application Gateway (SWAG)](https://www.linuxserver.io/blog/2020-08-21-introducing-swag) for Nginx best practice gateway + certbot + fail2ban + goaccess.
- [Authentik](https://https://goauthentik.io/) coupled with [oAuth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/), providing control of your identity needs with a secure, flexible solution.
- [Portainer CE](https://www.portainer.io/) for daily docker stack monitoring.
- [Homepage](https://gethomepage.dev/) provides an elegant portal access page for your deployed apps.
- [OpenObserve](https://openobserve.ai/), an open source and low-profile observability platform.
- [Restic](https://restic.net/), a modern backup program that can back up your files. 

<p>
  <img src="https://raw.githubusercontent.com/elasticlabs/elabs-https-nginx-proxy/authentik/.utils/Architecture.png" alt="Elasticlabs secure HTTPS proxy" height="400px">
</p>

Assuming that `example.com` is your self-hosted domain name, the proxy applications will be accessible via : 

- `https://example.com/portainer/`
- `https://example.com/authentik/`
- `https://example.com/code/`
- `https://example.com/openobserve/`
- `https://example.com/restic/`
- `https://example.com/files/`

Enjoy! 

## Table Of Contents

- [HTTPS Secure reverse proxy](#https-secure-reverse-proxy)
  - [Table Of Contents](#table-of-contents)
  - [Preparation steps](#preparation-steps)
    - [Stack preparation](#stack-preparation)
  - [Stack initial deployment](#stack-initial-deployment)
  - [Post-Install configuration](#post-install-configuration)
    - [Portainer](#portainer)
    - [Homepage](#homepage)
    - [SWAG](#swag)

----  

## Preparation steps

Please 1st ensure that you deployed a fresh docker + compose environment on your server. If not, please follow the [docker installation guide](https://docs.docker.com/engine/install/) and the [docker-compose installation guide](https://docs.docker.com/compose/install/linux/#install-using-the-repository). 

- Install utility tools: `# yum install git make htop wget tree`
- Carefully create / choose an appropriate directory to group your stacks GIT reposities (e.g. `~/AppContainers/`)
- GIT clone this repository `git clone https://github.com/elasticlabs/https-nginx-proxy-docker-compose.git`
- Ensure you registered a valid DNS domain mane

To successfully implement this solution, you'll need to ensure that the following DNS records are existing and properly pointing towards your server's IP address (replace `example.com` with your own domain name). Ensure those properly resolve from your server using `nslookup`commands.

| Tool | Record | description |
|---|---|---|
| Homepage | `example.com` | Your server homepage URL. Portainer will be accessed through `example.com/portainer` URL |
| SWAG Dashboard | `dash.example.com` | Your SWAG Dashboard (GoAccess) URL |


### Stack preparation

This stack is composed of the following main services : SWAG, Authentik, Portainer and Homepage. 

| Tool | Steps |
|---|---|
| Docker Compose | * Rename `.env-changeme` file into `.env`.<br>* Modify the following variables in `.env` file :<br>  * `VIRTUAL_HOST=` : replace `example.com` with your homepage domain name (usually ROOT domain).<br>  * `CERTBOT_EMAIL=` : used for let'sencrypt account.<br>  * `SUBDOMAINS`=auth,dash.<br>  * `AUTHELIA_SUBDOMAIN`=auth.example.com.<br>  * `TZ`=Europe/Paris by your timezone. |
| Authentik | * move TODO <br> |
| Homepage | The provided makefile gets you covered! | 

## Stack initial deployment

| ▲ [Top](#https-secure-reverse-proxy) |
| --- |

The following section describes how to deploy the stack and how to use it. 
It is based on a `Makefile` file _via_ following operators :

- Get help : `make`
- `make up` : brings up the whole stack. `up` always triggers a `make build` before, so you don't have to worry about it.
- `make build` : (Optional) checks that everythings's OK then builds the stack images.
- `make hard-cleanup` : /!\ Remove images, containers, networks, volumes & data

If all runs well, you should check for services status, especially SWAG with the following command : `docker compose logs swag-proxy`. Especially, negociating the certificates creation with Let's Encrypt can take a while. Please be patient. Once SWAG becomes ready, you should see something like this :

```bash

TODO // elabs-secure-proxy_swag-entrypoint  | Server ready

```

Additionnal commands are available to help you manage your stack :

- `make update` : (Optional) updates the stack images.
- `docker compose logs <service-id>` : shows the logs of a specific service (double-tab to list available services)
- `docker compose exec <service-id> /bin/bash` : opens a shell inside a specific service container
- `docker compose ps` : shows the status of the whole stack
- `docker compose ps <service-id>` : shows the status of a specific service


## Post-Install configuration

| ▲ [Top](#https-secure-reverse-proxy) |
| --- |

The following section describes what your get after a successful automated depoyment and how you can refine or complement the default configuratino to better fit your needs, create accounts, and secure the whole deployment.

### Portainer

After deployment you have `5 minutes` to setup an `administrative user accomunt` in the Portain GUI.

- If you fail to do it and access portainer, you'll be redirected to a `timeout.html` page.
- When this happen, simply restart Portainer : `docker compose restart portainer`, then create this 1st account. The tool is ready.
- **Authelia** : Once ready to secure your server, please go to the [Authelia](#authelia) section to learn more.

### Homepage

This secure gateway comes with a simple and fancy pre-configured `server homepage`. 
I chose [Homepage](https://github.com/benphelps/homepage/) over others for its simplicity and its ability to be easily customized. It is static, and meant to be fully customizable to tailor your needs.

**Configuration**

Homepage is configured through [a couple of YAML files](https://gethomepage.dev/en/configs/service-widgets/): 

- `bookmarks.yml` : place here a list of your favorite websites, like in your web browser, but specialized for your deployment
- `services.yml` : where you can [manually or automatically add your dockerized services](https://gethomepage.dev/en/configs/services/)
- `settings.yml` : to customize its behaviour
- `widgets.yml` : where you can add fancy and useful widgets to your homepage. Please go there to learn more!
- **Authelia** : Once ready to secure your server, please go to the [Authelia](#authelia) section to learn more.

### SWAG
Big idea short : when thinking about deplying a new stack, you have 2 major choices to make :
- Either you want your stuff to live in a **subfolder** (e.g. `https://example.com/your-app/`)
- Or you want your stuff to live in a **subdomain** of your domain (e.g. `https://your-app.example.com/`)

**Subfolder**

SWAG comes with many sample configuration files matching most common COTS on the market. You can find them in the `/config/nginx/proxy-confs/` folder. Please visit the [SWAG reverse proxy documentation](https://github.com/linuxserver/reverse-proxy-confs) to learn more.

These configuration files follow a simple naming convention : `<app-name>.subfolder.conf.sample`.
During startup, SWAG will automatically load all the `<app-name>.subfolder.conf` files and aggregate their `location` blocks to the `default.conf`live nginx file.

- Therefore, in this case you only act on the `location` blocks.

To operate, you need to :

- Move the sample file to a new file without the `.sample` extension (e.g. `cp nextcloud.subfolder.conf.sample nextcloud.subfolder.conf`)
  - You can also move the file to the `./data/swag/config/nginx/proxy-confs/` **build folder** to keep things clean and tidy (the gitignore file doesn't track the `*.sample` files).
  - Edit the new file to match your needs (e.g. `nano nextcloud.subfolder.conf`)
  - **Authelia** : if you want to secure access to this new app, please go to the [Authelia](#authelia) section to learn more.
- Restart SWAG to take the new configuration into account (e.g. `docker compose restart swag`)

**Subdomain**

In that case, you need to create full `server` blocks for a given subdomain.
Again, you can find sample config files in the `/config/nginx/proxy-confs/` swag-proxy container folder. Please visit the [SWAG reverse proxy documentation](https://github.com/linuxserver/reverse-proxy-confs) to learn more.

To operate, you need to :

- Copy the sample file to a new file without the `.sample` extension (e.g. `cp nextcloud.subdomain.conf.sample nextcloud.subdomain.conf`)
  - You can also move the file to the `./data/swag/config/nginx/site-confs/` **build folder** to keep things clean and tidy (the gitignore file doesn't track the `*.sample` files).
  - Edit the new file to match your needs (e.g. `nano nextcloud.subdomain.conf`)
  - **Authelia** : if you want to secure access to this new app, please go to the [Authelia](#authelia) section to learn more.

**Dashboard**

This opinionated SWAG deployment comes with a pre-configured dashboard. It is based on the [SWAG Dashboard](https://github.com/linuxserver/docker-mods/tree/swag-dashboard) and [Maxmind GeoIP2 database](https://github.com/linuxserver/docker-mods/tree/swag-maxmind) docker mods.

To operate, you need to :
1. (skip if already done during the preparation steps) In the `.env_swag-variables` file : 
  * Uncomment the `DOCKER_MODS` variable
  * Replace `<licence-key>` with your [Maxmind licence key](https://www.maxmind.com/en/geolite2/signup) personal licence key 

2. Add the following line to `/config/nginx/nginx.conf` under the `http` section:
   
   ```nginx
   include /config/nginx/maxmind.conf;
   ```

3. Move `/config/nginx/maxmind.conf.sample` to `/config/nginx/maxmind.conf` and edit it to add countries to the blocklist / whitelist according to the comments, for example:
   
    ```nginx
    map $geoip2_data_country_iso_code $geo-whitelist {
        default no;
        GB yes;
    }

    map $geoip2_data_country_iso_code $geo-blacklist {
        default yes;
        US no;
    }
    ```

4. Use the definitions in the following way for any application you may restrict to specific GeoIP2 countries:
   ```nginx
    server {
        listen 443 ssl;
        listen [::]:443 ssl;

        server_name some-app.*;
        include /config/nginx/ssl.conf;
        client_max_body_size 0;

        if ($lan-ip = yes) { set $geo-whitelist yes; }
        if ($geo-whitelist = no) { return 404; }

        location / {
    ```

4. (Re)start SWAG to take the new configuration into account (e.g. `docker compose restart swag-proxy`)

5. Access the dashboard through `https://dash.example.com/` URL

### Authelia
| ▲ [Top](#https-secure-reverse-proxy) |
| --- |

During the stack preparation steps, the following files should be initialized with the authelia domain name :
* `.env` : `AUTHELIA_SUBDOMAIN` variable sets the Authelia domain name
* `./data/authelia/configuration.yml.changeme` : lots of variables matching Authelia and other tools domain names should be initialized 
* `./data/swag/config/nginx/snippets/authelia-authrequest.conf` : the `error_page` variable should be initialized with the Authelia domain name
* `./data/swag/config/nginx/proxy-confs/*.conf` and `./data/swag/config/nginx/site-confs/*.conf` : Authelia related lines are commented out. Uncomment them to enable Authelia authentication for a given app, in the following steps.

**Initial configuration**

First of all, move the `./data/authelia/configuration.yml.changeme` file to `./data/authelia/configuration.yml` to enable your own custom authelia configuration. The `.gitignore` file is set to ignore production related files. In this section, we'll focus on setting the 2FA authentication to work on its own before enabling it for the whole stack.

The `./data/authelia/configuration.yml` configuration file is provided as a working kickstarter. Please modify the following sections :

| Topic | Section | description |
|---|---|---|
| Keys |   * `jwt_secret`.<br>  * Session `secret`. <br>  * Storage `encryption_key` | Please modify some symbols and generate new hardened keys to strenghen your stack security |
| 2FA with Duo API | `duo_api` | Please follow the [Duo API Authelia docs](https://www.authelia.com/configuration/second-factor/duo/) to create your own API credentials and fill that block, then uncomment  |
| SMTP | `smtp` | Please follow the [SMTP Authelia docs](https://www.authelia.com/configuration/authentication/smtp/) to create your own SMTP credentials and fill that block, then uncomment  |

**Testing**

Once Authelia configuration is ready, you can start the service with `docker compose up -d --build authelia`. You can then check if the service is running using the following command : `docker compose logs authelia`. If everything is OK, you should see something like this :

```bash
elabs-secure-proxy_authelia  | time="2023-06-22T20:15:36Z" level=info msg="Authelia v4.37.5 is starting"
elabs-secure-proxy_authelia  | time="2023-06-22T20:15:36Z" level=info msg="Log severity set to info"
elabs-secure-proxy_authelia  | time="2023-06-22T20:15:36Z" level=info msg="Storage schema is being checked for updates"
elabs-secure-proxy_authelia  | time="2023-06-22T20:15:36Z" level=info msg="Storage schema is already up to date"
elabs-secure-proxy_authelia  | time="2023-06-22T20:15:37Z" level=info msg="Initializing server for non-TLS connections on '[::]:9091' path '/'"
```

You can then access the Authelia dashboard through `https://auth.example.com/` URL. You should be able to login with the `authelia` account and the `authelia` password, then Duo mobile push. If you can't, please check the logs and the configuration file.

**Enabling Authelia for a given app**

At first, enabling Authelia can feel counter-intuitive (you need to include Authelia `location` files in the `server` blocks, then include the `authrequest` files in the location blocks). Please follow the following steps to enable Authelia for our stack. The underlying logic will remain the same for future needs :

| App | Subfolder | Subdomain |
|---|---|---|
| Homepage | ROOT `/` subdomain | In `./data/swag/config/nginx/site-confs/default.conf` uncomment the `include` line related to Authelia in the `server` block, then <br> in `./data/swag/config/nginx/proxy-confs/homepage.subfolder.conf` uncomment the `include` line in the `location` block to activate the captive portal |
| Portainer | ROOT `/portainer` subfolder | In `./data/swag/config/nginx/proxy-confs/portainer.subfolder.conf` uncomment the `include` line in the `location` block to activate the captive portal | 
| SWAG Dashboard | `dash.example.com` subdomain | In `./data/swag/config/nginx/proxy-confs/dashboard.subdomain.conf` uncomment the `include` line for Authelia in the `location` block to activate the captive portal |

**Authelia ACLs**

Authelia ACLs are defined in the `./data/authelia/config/configuration.yml` file. ACL are pre-filled for this stack basic apps. Please follow the [Authelia ACLs documentation](https://www.authelia.com/configuration/access-control/) to learn more.
