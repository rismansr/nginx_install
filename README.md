
# Nginx + Modsecurity

These sripts are used for installing High Availability Nginx + Modsecurity in Debian/Ubuntu (Active + Active) 

## Prerequisites

- Load Balancer
- 2 Virtual Machines (Debian/Ubuntu) attached to the Load Balancer
- Mounted NFS on both Nginx VMs that is storing these Folders (/mnt/nginx-config, /mnt/letsencrypt, /mnt/ssl-acme)

## Installation

- Clone this repo into the VMs
- Create GeoIP.conf (follow instruction bellow):
    - Create an account on maxmind.com if you have not one ( https://www.maxmind.com/en/geolite2/signup?lang=en )
    - Generate a lincense key https://www.maxmind.com/en/accounts/current/license-key?lang=en )
    - Get GeoIP.conf https://www.maxmind.com/en/accounts/current/license-key/GeoIP.conf
    - Place it in the nginx-install repo directory
    - Add additional config to the GeoIP.conf
    ```bash
    # The directory to store the database files. Defaults to DATADIR
    DatabaseDirectory /etc/nginx/geoip2
    ```
- Create abuseipdb_config.php
    - Create/login into your abuseipdb account https://www.abuseipdb.com/register
    - get your abuseipdb key
    - copy abuseipdb_config.php.example and rename it as abuseipdb_config.php
    - put your abuseipdb key into abuseipdb_config.php
    ```php
    <?php
    # please change this key to use the right one
    define('ABUSE_IP_DB_KEY', YOUR_ABUSE_IP_DB_KEY'); // String
    define('ABUSE_CONFIDENCE_SCORE', 80); // Integer
    ```
- Upgrade all packages
```bash
sudo apt update && sudo apt upgrade
```
- Install Nginx
```bash
sudo bash nginx_install.sh
```
- Install modsec
    - Note: If you are going to install modsec  on the second Nginx VM please comment out these configs in /etc/nginx/nginx.conf before executing the script for installing modsec:
        - `load_module          modules/ngx_http_modsecurity_module.so;`
        - `modsecurity on;`
        - ​`modsecurity_rules_file /etc/nginx/modsec/rules.conf;`

```bash
bash modsec_nginx_install.sh
```


- Copy nginx.conf
```bash
sudo mv /etc/nginx/nginx.conf{,.bak}
sudo cp ./nginx.conf /etc/nginx/nginx.conf
```

- Change the remote IP on this script (on 1st Nginx change it with the IP of the 2nd Nginx, on 2nd Nginx change it with the IP of the 1st Nginx :
```bash
sudo vim /usr/sbin/inotify_nginx.sh
sudo supervisorctl restart all
```
- Check nginx config & reload nginx service:
```bash
sudo nginx -t && sudo systemctl reload nginx
```

- Generate SSH key for root user (it's used for reloading nginx on remote NGINX by inotify-wait service when there is new change of nginx configs and letsencrypt SSL cert)
```bash
sudo ssh-keygen
sudo cat /root/.ssh/id_rsa.pub
```
- add the content of /root/.ssh/id_rsa.pub to the remote nginx in file /root/.ssh/authorized_keys
- test the ssh: `sudo ssh remote_nginx_ip`

- create DNS API secret for certbot (in this example I use Gandi)
```bash
sudo mkdir -p /etc/letsencrypt/.secrets
echo "dns_gandi_api_key=API-KEY-FROM-HERE" | sudo tee gandi.ini
```
## Authors

- [@rismansr](https://www.github.com/rismansr)