# 3D Hubs project

## Get Started

You can see the project live on: https://3dhubz.dacia.ninja/ (It's just a DigitalOcean VM running CentOS and Docker).

Also SSL report about ciphers, and so on: https://www.ssllabs.com/ssltest/analyze.html?d=3dhubz.dacia.ninja

The app should work after a clone & running `docker-compose up`, however due to LetsEncrypt & HSTS being enabled you can only connect to the IP of the `nginx` container. This is mainly due to the fact that on the first run dummy SSL certificates are used just so Nginx starts. Afterwards they get replaced by proper LetsEncrypt certificates using the `init-letsencrypt.sh` script.
So, basically all we need is (without proper LetsEncrypt certs):

```
# git clone  https://github.com/ninjaslikecheese/3dhubs.git
# cd 3dhubs
# docker-compose up -d
```

If you also have access to a domain, and changed the existing domain in the code of course, all you need to do is run the following script:
```
# ./init-letsencrypt.sh
```

It will request LetsEncrypt certs and restart the containers.

## Notes
* Even though I configured TLS 1.3 to work, unfortunately it's not supported due to outdated OpenSSL on containers, therefore it fallbacks to TLS 1.2.
* Microcaching: I've set it up, though after tests with `ab` I didn't see any improvement, either I didn't set it up correctly or because that Nginx proxy is not used for static files. Also noticed `uwsgi_cache` and tried it, but since it should only be used for static files I reverted it back to `proxy_cache`. All these settings you can find in `3dhubs.conf`
* DH-Params: The command I've used is `openssl dhparam -out ssl-dhparams.pem 4096` when I've initially configured it, and afterwards I adapted the `init-letsencrypt.sh` script. I always generated 4096 DH files ever since I started configured my own VPN servers, about 10 years ago.
* Extra headers: the `options-ssl-nginx.conf` file which is created by `init-letsencrypt.sh` contains the security tweaks, from ciphers to nosniff & HSTS. About HSTS: On the initial run, you might need to access the host directly by IP, and not the hostname, since HSTS is enabled on a long timespan for this domain. Or change the domain of course, but that may be more complicated. 
* Changed UWSGI so it uses socket files, for that reason I've also used custom passwd & group files so they are in the same group, able to access the socket files.
* Since one of the requirements states that it should work directly after a clone and `docker-compose up` I included the dummy certificates and DH file. These are created also by `init-letsencrypt.sh`, but it's an extra step and generating 4096 bits DH takes quite a long time. This script will generate dummy certificates for Nginx to work and afterwards it will request proper LetsEncrypt certificates. I did not write this script, I just adapted it for this project, particularly lines 18-43. 
* I know that it's a bad practice to add SSL Keys & Certs and hardcoded credentials to Git, but since one of the requirements was so that it runs on the first `docker-compose`, I found this to be the only way. To bypass this I usually use Puppet to generate new credentials on each environment creation


## Issues
The most pressing issue that slowed me down the most was that the task was not sent to Celery, causing Nginx requests to timeout in UWSGI. Not knowing this and while I saw similar symptoms in the past, I suspected bad Nginx/UWSGI config. I tried everything - switching to socket files, different protocols etc. Out of options, I've started commenting part of the app.py code to see if that is the cause of the hangs - and it was: example_task.delay().
To fix this, I took the liberty and modified worker.py so it uses secrets.json file where the Broker URL is stored. I think it's a good practice to have them stored in a different file which you can just .gitignore and add an example in the code if necessary. I also had to start the celery worker using `celery` and not `python worker.py` as stated in the docs. This might not be the only way, and surely you might find an easier approach to fix this since you know the project better. For now this is the only way I found it works.


## Improvements
Surely there are different ways of improving this and here are a few that I can think of:
 * Use software like HashiCorp Vault to pass down secrets to containers. src: https://www.hashicorp.com/resources/securing-container-secrets-vault
 * Create better optimized Docker images, therefore less scripts and Dockerfile custom logic in entrypoints
 * Make sure RabbitMQ is started by a non-privileged user. I've tried it, got some errors and decided not to bother too much since I had other priorities at the time. 


## Conclusion
I really enjoyed working on this project because I didn't have a chance to work with Flask & Celery at this level. I've also learned a lot about Docker security best practices because currently we only use Docker in a development environment, so we don't have focus that much on security other than the basics. Overall I can say these facts have slowed me down a bit. 

Thank you for the opportunity!