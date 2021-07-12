#!/bin/bash
# maintainer: Risman Soleh Ramadhan <rso@voxteneo.com>

echo "### Deleting previous compiled modsec ###"
sudo rm -rf /usr/local/src/*

echo "### MODSEC/WAF ###"
# Download Nginx Source Package
sudo chown $USER:$USER /usr/local/src/ -R
mkdir -p /usr/local/src/nginx
cd /usr/local/src/nginx/
sudo apt -y install dpkg-dev
apt source nginx
#NGINXVERSION=$(nginx -v 2>&1 | awk '{print $3}' | awk -F '/' '{print $2}')
NGINXVERSION=$1
echo "Nginx Version = $NGINXVERSION"

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
make -j$(lscpu | egrep '^CPU\(s\):' | awk '{print $2}') && \
sudo make install

echo ""
echo "### Download and Compile ModSecurity v3 Nginx Connector Source Code ###"
git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git /usr/local/src/ModSecurity-nginx/
cd /usr/local/src/nginx/nginx-$NGINXVERSION
sudo apt build-dep -y nginx
sudo apt install -y uuid-dev
./configure --with-compat --add-dynamic-module=/usr/local/src/ModSecurity-nginx
make modules
sudo cp -rf objs/ngx_http_modsecurity_module.so /usr/share/nginx/modules/