#!/bin/bash

cd /home
# only create virtualenv if not already created
[[ -f env/bin/activate ]] || virtualenv env
source env/bin/activate
cd app
chown 102:1337 /home/app/uwsgi
chmod 775 /home/app/uwsgi

# first run
if [[ ! -f /tmp/requirements.txt.lock ]]; then

  pip3 --cache-dir /tmp install -r requirements.txt && touch /tmp/requirements.txt.lock
  pip3 --cache-dir /tmp install alembic

  host=db

  until PGPASSWORD=$POSTGRES_PASSWORD psql -h $host -U 3dhubs -d postgres -c '\q'; do
    >&2 echo "Postgres is unavailable - sleeping"
    sleep 1
  done

  >&2 echo "Postgres is up - executing command"

  alembic upgrade head
fi

exec runuser -u app -- /home/env/bin/uwsgi --ini /home/app/uwsgi.ini