#!/bin/bash

cd /home
virtualenv env
source env/bin/activate
cd app


if [[ ! -f /tmp/requirements.txt.lock ]]; then
 pip3 --cache-dir /tmp install -r requirements.txt && touch /tmp/requirements.txt.lock
fi

celery worker --loglevel=info -b amqp://$RABBITMQ_DEFAULT_USER:$RABBITMQ_DEFAULT_PASS@$RABBITMQ_DEFAULT_HOST:5672/ &> /tmp/worker.log