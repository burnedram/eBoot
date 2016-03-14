# eBoot-CSGO
This script helps you get eBot up and running using php7.
The frontend still runs php5 (as of the date this was written) on a standard apache2 installation.
Only tested on on a Xen virtualized machine running Debian Jessie, but it should work on any Debian based system with apt-get.

# Installation
Run these targets in order:
* php7-zts
* ebotv3
* ebotv3-config password=PASSWORD mysql=MYSQLROOTPASSWORD
* (Optional) ebotv3-ip ip=IP
* (Optional) apache-alias
* run

# Usage
## make php7-zts
This install a lot of dependencies, including mysql-server. As such apt-get might ask you to enter a root password for your new MySQL installation.
It then downloads [php-src](https://github.com/php/php-src.git) and verifies that it is version 7 before making it and installing it into /usr/local/php7-zts.
In order to make eBot run on php7 [pthreads](https://github.com/krakjoe/pthreads) (and some more) modules are included which doesn't make it very suitable for regular usage.
The php binary is symlinked to /usr/local/bin/php7-zts so it shouldn't mess up any already installed versions of php.

## make ebotv3
Some more dependencies are installed and then [eBot-CSGO](https://github.com/deStrO/eBot-CSGO) and [eBot-CSGO-Web](https://github.com/deStrO/eBot-CSGO-Web) are downloaded and built.
This creates the user 'ebotv3'.
eBot is broken as fuck so some patches are included (and auto-installed) to fix that.

## make ebotv3-config
Takes two arguments: 'password' and 'mysql'.

'password' will be the password used by eBot to login to MySQL and also the password that you will use to login to the admin panel.

'mysql' must be the root password you entered when setting up mysql-server.

## make ebotv3-ip
Takes one argument: 'ip'.

'ip' will be the ip that the frontend will use to try to connect eBot. This means that if the eBot frontend is accessible from the internet and you intend to use it from the internet then you should pass your external IP to this target.
In that case also forward port 12360, since that is the port eBot listens to by default. Otherwise this should be the host's internal IP.

## make apache-alias
Adds an apache2 [Alias](https://httpd.apache.org/docs/current/mod/mod_alias.html#alias) so that the eBot frontend is accessible from /eBot-CSGO.

## make run
Runs eBot as the user 'ebotv3'
