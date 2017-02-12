# WhaaaAAAaat?

Smoothly install an OVH VPS in 3 minutes (might work on where-ever-hosted-Debian-8).

What you might get:
- a colored bash with some macro
- nginx 1.11.9 (secured thanx to Nicolas's script)
- php 7.0.15 fpm (curl, zip, gd, xml, mysql, mcrypt, mbstring, opcache, memcache, mongo...)
- MariaDB 10.0.29 */todo: should be tuned/*
- Memcached 1.4.21
- Mongodb 3.4
- Node */todo: to complete/*
- firewall (ufw) - your own IP will be automatically whitelisted,
- smtp server using Mailgun (http://www.mailgun.com/)
- some stuff to backup on Amazon clouddrive */todo: to complete/*

# Howto?

Just copy/paste the *install.sh* file on your fresh new installed ovh vps (debian8), setup USR_EMAIL, SMTP_LOGIN, SMTP_PASS (get these in your Mailgun domain console), then:
~~~~
# bash install.sh
~~~~

That's it!

# Credits

- nginx installation use the job of Nicolas Simond (https://github.com/stylersnico / https://www.abyssproject.net/). Thanks to him!  
- Mailgun because their api is cool :) 
