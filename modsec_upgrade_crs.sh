#!/bin/bash

crs_upgrade() {
echo "### Upgrading OWASP Core Rule Set ###"

cd ~
wget "https://github.com/coreruleset/coreruleset/archive/refs/tags/v$CRS_NEW_VERSION.tar.gz"
tar xvf v"$CRS_NEW_VERSION".tar.gz
sudo mv -v coreruleset-"$CRS_NEW_VERSION"/ /etc/nginx/modsec/
sudo cp /etc/nginx/modsec/coreruleset-"$CRS_NEW_VERSION"/crs-setup.conf.example /etc/nginx/modsec/coreruleset-"$CRS_NEW_VERSION"/crs-setup.conf

if ! grep -E "$CRS_NEW_VERSION" /etc/nginx/modsec/main.conf; then 
    sudo mv /etc/nginx/modsec/main.conf /etc/nginx/modsec/main.conf.backup-$(date +%Y%m%d)
fi

if ! grep -E "crs-setup|rules|$CRS_NEW_VERSION" /etc/nginx/modsec/main.conf; then 
sudo bash -c "cat <<EOF >>/etc/nginx/modsec/main.conf
Include /etc/nginx/modsec/coreruleset-$CRS_NEW_VERSION/crs-setup.conf
Include /etc/nginx/modsec/coreruleset-$CRS_NEW_VERSION/rules/*.conf
EOF"
fi

if ! grep -E "$CRS_NEW_VERSION" /etc/nginx/modsec/rules.conf; then 
    sudo mv /etc/nginx/modsec/rules.conf /etc/nginx/modsec/rules.conf.backup-$(date +%Y%m%d)
fi
#custom rule, only load the rules, if we set modsec config per webapp
if ! grep -E "rules|$CRS_NEW_VERSION" /etc/nginx/modsec/rules.conf; then 
sudo bash -c "cat <<EOF >>/etc/nginx/modsec/rules.conf
Include /etc/nginx/modsec/coreruleset-$CRS_NEW_VERSION/rules/*.conf
EOF"
fi

sudo find /etc/nginx/modsec/conf/ -type f -iname crs-setup.conf -exec cp {}{,.bak} \;
sudo find /etc/nginx/modsec/conf/ -type f -iname crs-setup.conf -exec sed -i "s/crs_setup_version=$(echo $CRS_OLD_VERSION | tr -d '.')/crs_setup_version=$(echo $CRS_NEW_VERSION | tr -d '.')/g" {} \;

sudo nginx -t && sudo systemctl reload nginx
}

echo "Please make a backup of your modsec/nginx config before executing this script (DWYOR)"
echo "Insert current installed OWASP CRS version: (example: 3.3.0)"
read CRS_OLD_VERSION

echo "Insert OWASP CRS version you are going to upgrade to: (example: 3.3.2)"
read CRS_NEW_VERSION

crs_upgrade
