#!/bin/sh

set -o errexit
set -o pipefail
set -o nounset

FULLCHAIN=/etc/nginx/ssl/live/${SERVER_NAME}/fullchain.pem
PRIVKEY=/etc/nginx/ssl/live/${SERVER_NAME}/privkey.pem

# Delete the default.conf file
if [ -f "/etc/nginx/conf.d/default.conf" ] ; then
    rm "/etc/nginx/conf.d/default.conf"
fi

# Substitute placeholders with current environment variables
export DOLLAR="$"

envsubst < /etc/nginx/conf.d/01_api_http.conf.bak | tee /etc/nginx/conf.d/01_api_http.conf.bak.bak > /dev/null 2>&1
envsubst < /etc/nginx/conf.d/02_api_https.conf.bak | tee /etc/nginx/conf.d/02_api_https.conf.bak.bak > /dev/null 2>&1

# Enable "/.well-known/acme-challenge/" endpoint
cp /etc/nginx/conf.d/01_api_http.conf.bak.bak /etc/nginx/conf.d/01_api_http.conf
echo "'/.well-known/acme-challenge/' endpoint enabled."

nginx -g "daemon off;" &

# Wait for SSL certificates before enabling HTTPS
until [ -f ${FULLCHAIN} ]
do
     sleep 1
done

until [ -f ${PRIVKEY} ]
do
     sleep 1
done

# Enable access to the API
cp /etc/nginx/conf.d/02_api_https.conf.bak.bak /etc/nginx/conf.d/02_api_https.conf
nginx -s reload

echo "API access via HTTPS enabled."

# Sleeps while keeping the ssl certificates up to date
trap exit TERM

while true
do
    # The SSL certificates are renewed by certbot about 30 days before the expire date,
    # so it should be okay to reload nginx in 0h to 24h after the renew.
    sleep 24h & wait ${!}
    nginx -s reload
done
