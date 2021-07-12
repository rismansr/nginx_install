#!/bin/bash

# maintainer: Risman Soleh Ramadhan <rso@voxteneo.com>

## please mount azure file share before executing this script
echo "Creating symlink to the azure storage account ..."
ln -fs /mnt/nginx-config /etc/nginx
ln -fs /mnt/letsencrypt /etc/letsencrypt
mkdir -p /var/www
ln -fs /mnt/ssl-acme /var/www/_letsencrypt

echo "#############"
echo "### NGINX ###"
echo "#############"
add-apt-repository ppa:ondrej/nginx-mainline -y && \
sed -i 's/# //g' /etc/apt/sources.list.d/ondrej-ubuntu-nginx-mainline-$(lsb_release -cs).list && \
apt update && \
apt install nginx-core nginx-common nginx nginx-full -y && \
systemctl enable nginx && \
# disable upgrade on nginx
#sudo apt-mark hold nginx && \
echo "Generating DH parameters, 2048 bit long safe prime, generator 2"
echo "This is going to take a long time ..."
openssl dhparam -out /etc/nginx/dhparam.pem 2048 > /dev/null

mkdir -p /var/cache/nginx/tmp

echo ""
echo "########################################"
echo "### GeoIP (additional GeoIP database)###"
echo "########################################"
add-apt-repository ppa:maxmind/ppa -y && \
apt update && \
apt install geoipupdate libmaxminddb0 libmaxminddb-dev mmdb-bin -y && \
mkdir /etc/nginx/geoip2

cat <<EOF >/etc/nginx/GeoIP.conf
# GeoIP.conf file for 'geoipupdate' program, for versions >= 3.1.1.
# Used to update GeoIP databases from https://www.maxmind.com.
# For more information about this config file, visit the docs at
# https://dev.maxmind.com/geoip/geoipupdate/.

# 'AccountID' is from your MaxMind account.
AccountID 572218

# 'LicenseKey' is from your MaxMind account
LicenseKey wlsoMOZG78gAGI1u

# 'EditionIDs' is from your MaxMind account.
EditionIDs GeoLite2-ASN GeoLite2-City GeoLite2-Country

# The directory to store the database files. Defaults to DATADIR
DatabaseDirectory /etc/nginx/geoip2
EOF

geoipupdate -f /etc/nginx/GeoIp.conf && \

#write out current crontab
crontab -l > mycron
if ! grep -E "geoipupdate" mycron; then 
#echo new cron into cron file
echo "0 0 * * 1 /usr/bin/geoipupdate -f /etc/nginx/GeoIp.conf" >> mycron
#install new cron file
crontab mycron
fi

rm mycron

echo ""
echo "#################"
echo "### abuseipdb ###"
echo "#################"
apt install php -y --no-install-recommends && \
git clone https://github.com/AmplitudeDesignInc/abuseipdb-php-nginx-blacklist-create.git /etc/nginx/abuseipdb

cat <<EOF >/etc/nginx/abuseipdb/config.php
<?php
# please change this key to use the right one
define('ABUSE_IP_DB_KEY', '3e2062f086ac1b0d36e447c0615c8a17d55164d4225d336fd4aa2de88a2fc63561951ddac5f8438f'); // String
define('ABUSE_CONFIDENCE_SCORE', 80); // Integer
EOF

cd /etc/nginx/abuseipdb && php abuseipdb-blacklist-create.php && \

sed -i '/sites-enabled/a\    #Block spammers and other unwanted visitors\n    include /etc/nginx/abuseipdb/nginx-abuseipdb-blacklist.conf;' /etc/nginx/nginx.conf
nginx -t && service nginx reload

#write out current crontab
crontab -l > mycron
if ! grep -E "abuseipdb-blacklist-create" mycron; then 
#echo new cron into cron file
echo "0 1 * * * /usr/bin/php /etc/nginx/abuseipdb/abuseipdb-blacklist-create.php" >> mycron
#install new cron file
crontab mycron
fi

rm mycron

echo ""
echo "##############"
echo "### badbot ###"
echo "##############"
cd -
cp -rf ./badagent.list /etc/nginx/badagent.list

echo ""
echo "###############"
echo "### CERTBOT ###"
echo "###############"
# add-apt-repository ppa:certbot/certbot
# apt install python-certbot-nginx
apt install -y python3 python3-venv libaugeas0
apt-get remove certbot
python3 -m venv /opt/certbot/
/opt/certbot/bin/pip install --upgrade pip
/opt/certbot/bin/pip install certbot
ln -s /opt/certbot/bin/certbot /usr/bin/certbot
/opt/certbot/bin/pip install certbot-nginx certbot-plugin-gandi

# ### keepalived ###
# ### Install from source
# sudo apt-get install build-essential libssl-dev
# wget https://www.keepalived.org/software/keepalived-2.2.2.tar.gz
# tar xzvf keepalived-2.2.2.tar.gz
# cd keepalived-2.2.2/
# #./configure
# ./configure --prefix=/usr/local/keepalived-2.2.2
# make
# sudo make install
# 
# ### Install using ubuntu/debian package
# sudo apt install keepalived

echo ""
echo "#####################"
echo "### inotify-tools ###"
echo "#####################"
apt install inotify-tools -y && \
cat <<EOF > /usr/sbin/inotify_nginx.sh
#!/bin/bash
while true; do
  inotifywait -q -o /var/log/inotify_nginx.log --timefmt '%F %T' --format '[ %T ] %w %e %f'  --exclude '(.*.sw.*|.*~|.*nginx-vhost-generator.*)' -e create -e modify -e delete -r /etc/nginx/ /etc/letsencrypt/

  ## make sure this VM can ssh to remote nginx VM using root user for reloading nginx service
  ## change the IP below to match the remote VM's IP
  ssh 10.2.0.6 -t 'nginx -t && systemctl reload nginx && echo "== Nginx change has been applied on remote Nginx (Nginx reloaded) =="'
done
EOF

chmod 700 /usr/sbin/inotify_nginx.sh

echo ""
echo "####################################"
echo "### supervisor for inotify-tools ###"
echo "####################################"

apt install supervisor -y && \
systemctl enable supervisor && \

cat <<EOF > /etc/supervisor/conf.d/inotify_nginx.conf
[program:inotify_nginx]
command=/bin/bash /usr/sbin/inotify_nginx.sh
process_name=%(program_name)s
stdout_logfile = /var/log/inotify_nginx.log
redirect_stderr=true
autostart=true
autorestart=true
EOF

systemctl restart supervisor 
