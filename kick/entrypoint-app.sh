#!/bin/bash

cd /home/app
virtualenv env
source env/bin/activate

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

#uwsgi --socket 0.0.0.0:5000 --protocol=http -w app
uwsgi --ini /home/app/uwsgi.ini