#!/bin/bash
# maintainer: Risman Soleh Ramadhan <rso@voxteneo.com>

echo "### MODSEC/WAF ###"
# Download Nginx Source Package
sudo chown $USER:$USER /usr/local/src/ -R
mkdir -p /usr/local/src/nginx
cd /usr/local/src/nginx/
sudo apt -y install dpkg-dev
apt source nginx
NGINXVERSION=$(nginx -v 2>&1 | awk '{print $3}' | awk -F '/' '{print $2}')

echo ""
echo "### Install libmodsecurity3 ###"
sudo apt -y install git && \
git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity /usr/local/src/ModSecurity/ && \
cd /usr/local/src/ModSecurity/
sudo apt install -y gcc make build-essential autoconf automake libtool gettext pkg-config libpcre3 libpcre3-dev libxml2 libxml2-dev libcurl4 libgeoip-dev libyajl-dev doxygen && \
git submodule init && \
git submodule update && \
./build.sh && \
./configure && \
make -j$(lscpu | grep -E '^CPU\(s\):' | awk '{print $2}') && \
sudo make install

echo ""
echo "### Download and Compile ModSecurity v3 Nginx Connector Source Code ###"
git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git /usr/local/src/ModSecurity-nginx/
cd /usr/local/src/nginx/nginx-$NGINXVERSION
sudo apt build-dep -y nginx
sudo apt install -y uuid-dev
./configure --with-compat --add-dynamic-module=/usr/local/src/ModSecurity-nginx
make modules
sudo cp objs/ngx_http_modsecurity_module.so /usr/share/nginx/modules/

echo ""
echo "### Load the ModSecurity v3 Nginx Connector Module ###"

if ! grep -E "ngx_http_modsecurity_module" /etc/nginx/nginx.conf; then 
sudo sed -i '/modules-enabled/a\load_module         modules/ngx_http_modsecurity_module.so;' /etc/nginx/nginx.conf
fi

if [ ! -d /etc/nginx/modsec ]; then sudo mkdir /etc/nginx/modsec; fi
sudo cp /usr/local/src/ModSecurity/modsecurity.conf-recommended /etc/nginx/modsec/modsecurity.conf

sudo sed -i '/SecRuleEngine/s/DetectionOnly/On/' /etc/nginx/modsec/modsecurity.conf
sudo sed -i '/SecAuditLogParts/s/ABIJDEFHZ/ABCEFHJKZ/' /etc/nginx/modsec/modsecurity.conf

if ! grep -E "modsecurity" /etc/nginx/modsec/main.conf; then 
  echo "Include /etc/nginx/modsec/modsecurity.conf" | sudo tee -a /etc/nginx/modsec/main.conf
fi

sudo cp /usr/local/src/ModSecurity/unicode.mapping /etc/nginx/modsec/
sudo nginx -t
sudo systemctl restart nginx

echo ""
echo "### Enable OWASP Core Rule Set ###"
CRS_VERSION=3.3.2
cd ~
wget https://github.com/coreruleset/coreruleset/archive/refs/tags/v"$CRS_VERSION".tar.gz
tar xvf v"$CRS_VERSION".tar.gz
sudo mv -v coreruleset-"$CRS_VERSION"/ /etc/nginx/modsec/
sudo cp /etc/nginx/modsec/coreruleset-"$CRS_VERSION"/crs-setup.conf.example /etc/nginx/modsec/coreruleset-"$CRS_VERSION"/crs-setup.conf

if ! grep -E "crs-setup|rules" /etc/nginx/modsec/main.conf; then 
sudo bash -c 'cat <<EOF >>/etc/nginx/modsec/main.conf
Include /etc/nginx/modsec/coreruleset-$CRS_VERSION/crs-setup.conf
Include /etc/nginx/modsec/coreruleset-$CRS_VERSION/rules/*.conf
EOF'
fi

#custom rule, only load the rules, if we set modsec config per webapp
if ! grep -E "rules" /etc/nginx/modsec/rules.conf; then 
sudo bash -c 'cat <<EOF >>/etc/nginx/modsec/rules.conf
Include /etc/nginx/modsec/coreruleset-$CRS_VERSION/rules/*.conf
EOF'
fi

sudo nginx -t
sudo systemctl restart nginx

sudo mkdir -p /etc/nginx/modsec/conf
sudo mkdir -p /var/log/modsec

echo ""
echo "### setup logrotate ###"
sudo bash -c 'cat <<EOF > /etc/logrotate.d/modsecurity
/var/log/modsec_audit.log /var/log/modsec/*.log
{
        rotate 14
        daily
        missingok
        compress
        delaycompress
        notifempty
        postrotate
                service nginx reload >/dev/null 2>&1
        endscript
}
EOF'
