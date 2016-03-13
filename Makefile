SHELL := /bin/bash
.PHONY: php7-zts ebotv3 ebotv3-config ebotv3-ip

php7-zts:
	@echo "==== Installing dependencies"
	sudo apt-get -y install build-essential git autoconf \
		bison mysql-server mysql-client libmysqlclient-dev
	sudo apt-get build-dep php5
	@echo "==== Checking for php-src"
	@if [ ! -d /usr/local/src/php-src ]; then \
		echo "==== No php-src found, downloading..."; \
		sudo git clone https://github.com/php/php-src.git /usr/local/src/php-src; \
	fi
	@PHP_MAJOR_VERSION=$(shell grep 'PHP_MAJOR_VERSION\s*=[0-9]*' /usr/local/src/php-src/configure.in | cut -d '=' -f2); \
	if [ $${PHP_MAJOR_VERSION} -ne 7 ]; then \
		echo "==== Unknown PHP major version $${PHP_MAJOR_VERSION}, expected 7"; \
		exit 1; \
	fi
	@if [ ! -d /usr/local/src/php-src/ext/pthreads ]; then \
		echo "==== No pthreads ext in php-src, downloading..."; \
		sudo git clone https://github.com/krakjoe/pthreads.git /usr/local/src/php-src/ext/pthreads; \
	fi
	@if [ ! -d /usr/local/src/php-src/ext/mysql ]; then \
		echo "==== No mysql ext in php-src, downloading..."; \
		sudo git clone https://github.com/php/pecl-database-mysql.git /usr/local/src/php-src/ext/mysql; \
	fi
	@echo "==== Begin configure"
	@cd /usr/local/src/php-src && \
	  	sudo ./buildconf --force && \
   		if [ -f Makefile ]; then \
			sudo make clean; \
   		fi && \
		sudo ./configure --prefix=/usr/local/php7-zts \
					--with-libdir=/lib/x86_64-linux-gnu \
					--with-openssl \
					--disable-cgi \
					--enable-gd-native-ttf \
					--enable-opcache \
					--enable-mbstring \
					--enable-sockets \
					--enable-bcmath \
					--with-bz2 \
					--enable-zip \
					--enable-mysqlnd \
					--with-mysql \
					--with-pdo-mysql \
					--enable-maintainer-zts \
					--enable-pthreads && \
		echo "==== Patching Makefile for legacy mysql" && \
		echo sudo patch /usr/local/src/php-src/Makefile Makefile.patch && \
		echo "==== Begin make" && \
		sudo make -j $(shell nproc) && \
		sudo make install;
	@if [ ! -f /usr/local/php7-zts/lib/php.ini ]; then \
		echo "==== Copying default PHP configuration"; \
		sudo cp /usr/local/src/php-src/php.ini-production /usr/local/php7-zts/lib/php.ini; \
		sudo patch /usr/local/php7-zts/lib/php.ini php.ini.patch; \
	fi
	sudo ln -sf /usr/local/php7-zts/bin/php /usr/local/bin/php7-zts

ebotv3:
	@if ! command -v php7-zts >/dev/null 2>&1; then \
		echo "==== Run 'make php7-zts' before trying to install eBot"; \
		exit 1; \
	fi
	@echo "==== Installing dependencies"
	sudo apt-get -y install nodejs util-linux crudini
	@if ! command -v node >/dev/null 2>&1; then \
		echo "==== Symlinking node"; \
		sudo ln -sf $$(command -v nodejs) /usr/bin/node; \
	fi
	@if ! id -u ebotv3 >/dev/null 2>&1; then \
		echo "==== Adding user ebotv3"; \
		sudo adduser ebotv3 --disabled-login; \
	fi
	@if [ ! -d /home/ebotv3/eBot-CSGO ]; then \
		echo "==== No eBot-CSGO found, downloading..."; \
		sudo runuser -l ebotv3 -c 'git clone https://github.com/deStrO/eBot-CSGO.git'; \
		sudo patch /home/ebotv3/eBot-CSGO/bootstrap.php bootstrap.php.patch && \
		sudo patch /home/ebotv3/eBot-CSGO/config/config.ini config.ini.patch && \
		sudo patch /home/ebotv3/eBot-CSGO/src/eBot/Config/Config.php Config.php.patch && \
		sudo patch /home/ebotv3/eBot-CSGO/src/eTools/Utils/Logger.php Logger.php.patch; \
	fi
	@if [ ! -d /home/ebotv3/eBot-CSGO-Web ]; then \
		echo "==== No eBot-CSGO-Web found, downloading..."; \
		sudo runuser -l ebotv3 -c "\
			git clone https://github.com/deStrO/eBot-CSGO-Web.git && \
			cd eBot-CSGO-Web && \
			cp config/app_user.yml.default config/app_user.yml && \
 			rm -rf web/installation; "; \
		sudo patch /home/ebotv3/eBot-CSGO-Web/config/app_user.yml app_user.yml.patch; \
	fi
	@sudo runuser -l ebotv3 -c "\
		cd eBot-CSGO && \
		php7-zts -r \"eval('?>'.file_get_contents('https://getcomposer.org/installer'));\" && \
		php7-zts composer.phar install && \
		npm install socket.io formidable archiver; "
	@echo
	@echo "==== eBot installed, now run 'make ebotv3-config password=PASSWORD mysql=MYSQLROOTPASSWORD' to configure MySQL and eBot"

ebotv3-config:
	@mysql --user=root --password=$(mysql) <<< "\
		GRANT ALL PRIVILEGES ON ebotv3.* TO 'ebotv3'@'localhost' IDENTIFIED BY '$(password)' WITH GRANT OPTION; \
		CREATE DATABASE IF NOT EXISTS ebotv3; "
	@sudo runuser -l ebotv3 -c "\
		crudini --set --existing eBot-CSGO/config/config.ini BDD mysql_pass \\\"$(password)\\\" && \
		cd eBot-CSGO-Web && \
		php symfony configure:database \"mysql:host=localhost;dbname=ebotv3\" ebotv3 $(password) && \
		php symfony doctrine:insert-sql && \
		php symfony guard:create-user --is-super-admin admin@ebotv3 admin $(password); \
   		php symfony cc; "
	@echo
	@echo "==== eBot and MySQL configured"
	@echo "==== Dont forget to symlink eBot-CSGO-Web/web"
	@echo "==== Change eBot ip with 'make ebotv3-ip ip=IP'"

ebotv3-ip:
	@sudo runuser -l ebotv3 -c "\
		cd eBot-CSGO-Web && \
		sed -i 's/ebot_ip: .*$$/ebot_ip: $(ip)/' config/app_user.yml; \
		php symfony cc; "
