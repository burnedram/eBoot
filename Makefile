SHELL := /bin/bash
.PHONY: php7-zts ebotv3 ebotv3-config ebotv3-ip apache-alias run

php7-zts:
	@echo "==== Installing dependencies"
	sudo apt-get -y install build-essential git autoconf \
		bison mysql-server mysql-client libmysqlclient-dev
	sudo apt-get -y build-dep php5
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
	sudo apt-get -y install nodejs npm util-linux crudini php5 php5-cli php5-mysql
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
		sudo mv /home/ebotv3/eBot-CSGO/config/config.ini.smp /home/ebotv3/eBot-CSGO/config/config.ini; \
		sudo patch /home/ebotv3/eBot-CSGO/bootstrap.php bootstrap.php.patch && \
		sudo patch /home/ebotv3/eBot-CSGO/config/config.ini config.ini.patch && \
		sudo patch /home/ebotv3/eBot-CSGO/src/eTools/Utils/Logger.php Logger.php.patch && \
		sudo patch /home/ebotv3/eBot-CSGO/src/eBot/Match/Match.php Match.php.patch; \
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
		npm install socket.io@0.9 formidable archiver; "
	@echo
	@sudo patch /home/ebotv3/eBot-CSGO/vendor/koraktor/steam-condenser/lib/Socket.php Socket.php.patch
	@sudo patch /home/ebotv3/eBot-CSGO/vendor/koraktor/steam-condenser/lib/TCPSocket.php TCPSocket.php.patch
	@sudo patch /home/ebotv3/eBot-CSGO/vendor/koraktor/steam-condenser/lib/UDPSocket.php UDPSocket.php.patch
	@echo "==== eBot installed, now run 'make ebotv3-config password=PASSWORD mysql=MYSQLROOTPASSWORD' to configure MySQL and eBot"

ebotv3-config:
	@if [ -z "$(mysql)" ]; then \
		echo "error: parameter 'mysql' missing"; \
		exit 1; \
	fi
	@if [ -z "$(password)" ]; then \
		echo "error: parameter 'password' missing"; \
		exit 1; \
	fi
	@mysql --user=root --password=$(mysql) <<< "\
		GRANT ALL PRIVILEGES ON ebotv3.* TO 'ebotv3'@'localhost' IDENTIFIED BY '$(password)' WITH GRANT OPTION; \
		CREATE DATABASE IF NOT EXISTS ebotv3; "
	@sudo runuser -l ebotv3 -c "\
		crudini --set --existing eBot-CSGO/config/config.ini BDD MYSQL_PASS \\\"$(password)\\\" && \
		cd eBot-CSGO-Web && \
		php symfony configure:database \"mysql:host=localhost;dbname=ebotv3\" ebotv3 $(password) && \
		( php symfony doctrine:insert-sql || \
			true ) && \
		( php symfony guard:create-user --is-super-admin admin@ebotv3 admin $(password) || \
			php symfony guard:change-password admin $(password) ) && \
   		php symfony cc; "
	@echo
	@echo "==== eBot and MySQL configured"
	@echo "==== Dont forget to symlink eBot-CSGO-Web/web or run 'make apache-alias'"
	@echo "==== Change eBot ip with 'make ebotv3-ip ip=IP'"

ebotv3-ip:
	@if [ -z "$(ip)" ]; then \
		echo "error: parameter 'ip' missing"; \
		exit 1; \
	fi
	@sudo runuser -l ebotv3 -c "\
		crudini --set --existing eBot-CSGO/config/config.ini Config BOT_IP \\\"$(ip)\\\" && \
		cd eBot-CSGO-Web && \
		sed -i 's/ebot_ip: .*$$/ebot_ip: $(ip)/' config/app_user.yml; \
		php symfony cc; "

apache-alias:
	sudo chmod 644 /home/ebotv3/eBot-CSGO-Web/web/.htaccess
	sudo cp ebotv3.conf /etc/apache2/sites-available/ebotv3.conf
	sudo a2enmod rewrite
	sudo service apache2 restart
	@echo "==== Don't forget to change 'ServerName' in /etc/apache2/sites-available/ebotv3.conf"
	@echo "==== Enable eBot website with 'a2ensite ebotv3.conf'"

run:
	sudo su - ebotv3 -c "\
		cd eBot-CSGO && \
		php7-zts bootstrap.php; "

demos:
	@for demo in $$(find /home/steam/csgo/csgo-ds/csgo/ -name "*.dem" | xargs -L1 basename); do \
		if [ ! -e /home/ebotv3/eBot-CSGO-Web/web/demos/$${demo}.zip ]; then \
			echo Zipping $${demo}...; \
			sudo runuser -l ebotv3 -c "zip /home/ebotv3/eBot-CSGO-Web/web/demos/$${demo}.zip /home/steam/csgo/csgo-ds/csgo/$${demo}"; \
		fi \
	done

remote-demos:
        @if [ -z "$(host)" ] || [ -z "$(port)" ]; then \
                echo "usage: remote-demos host=<host> port=<port>"; \
                exit 1; \
        fi
        @demos=(); \
        for demo in $$(ssh $(host) -p $(port) find /home/steam/csgo/csgo-ds/csgo/ -name "*.dem" | xargs -L1 basename); do \
                if [ ! -e /home/ebotv3/eBot-CSGO-Web/web/demos/$${demo}.zip ]; then \
                        echo "Add $${demo}"; \
                        demos+=( $${demo} ); \
                fi; \
        done; \
        if [ $${#demos[@]} -eq 0 ]; then \
                echo "Nothing to be done"; \
                exit 0; \
        fi; \
        ssh $(host) -p $(port) tar cvf __eBoot-demos__.tar -C /home/steam/csgo/csgo-ds/csgo $${demos[@]}; \
        scp -P $(port) $(host):__eBoot-demos__.tar ./; \
        ssh $(host) -p $(port) rm __eBoot-demos__.tar; \
        tar xvf __eBoot-demos__.tar; \
        rm __eBoot-demos__.tar; \
        for demo in "$${demos[@]}"; do \
                sudo runuser -l ebotv3 -c "zip /home/ebotv3/eBot-CSGO-Web/web/demos/$${demo}.zip $(shell pwd)/$${demo}" && \
                rm $${demo}; \
        done


