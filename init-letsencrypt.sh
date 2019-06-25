#!/bin/bash

if ! [[ -x "$(command -v docker-compose)" ]]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

domains=(3dhubz.dacia.ninja)
rsa_key_size=4096
data_path="./data/certbot"
email="dub2sauce@gmail.com" # Adding a valid address is strongly recommended
staging=0 # Set to 1 if you're testing your setup to avoid hitting request limits


if [[ ! -e "$data_path/conf/options-ssl-nginx.conf" ]] || [[ ! -e "$data_path/conf/ssl-dhparams.pem" ]]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "$data_path/conf"
  # The original script used:
  #curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
  #curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/ssl-dhparams.pem >  "$data_path/conf/ssl-dhparams.pem"
  ###################################################################################
  ## changes so it's in line with the assignment: secure ciphers and secure dhparams
  openssl dhparam -out "$data_path/conf/ssl-dhparams.pem" 4096 # 4096 bits
  cat >"$data_path/conf/options-ssl-nginx.conf"<<'EOF'
ssl_protocols TLSv1.2, TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
ssl_ecdh_curve secp384r1;
ssl_session_timeout  10m;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;

resolver 8.8.8.8 valid=300s;
resolver_timeout 5s;

add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
EOF

  ## End changes 24/06/2019
  echo
fi

echo "### Creating dummy certificate for $domains ..."
path="/etc/letsencrypt/live/$domains"
mkdir -p "$data_path/conf/live/$domains"
docker-compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:1024 -days 1\
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot
echo


echo "### Starting nginx ..."
docker-compose up --force-recreate -d nginx
echo

echo "### Deleting dummy certificate for $domains ..."
docker-compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$domains && \
  rm -Rf /etc/letsencrypt/archive/$domains && \
  rm -Rf /etc/letsencrypt/renewal/$domains.conf" certbot
echo


echo "### Requesting Let's Encrypt certificate for $domains ..."
#Join $domains to -d args
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

# Select appropriate email arg
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

# Enable staging mode if needed
if [[ $staging != "0" ]]; then staging_arg="--staging"; fi

docker-compose run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot
echo

echo "### Reloading nginx ..."
docker-compose exec nginx nginx -s reload
