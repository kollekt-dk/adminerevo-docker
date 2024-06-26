FROM php:8.3.3-apache


RUN	echo "upload_max_filesize = 128M" >> /usr/local/etc/php/conf.d/0-upload_large_dumps.ini \
&&	echo "post_max_size = 128M" >> /usr/local/etc/php/conf.d/0-upload_large_dumps.ini \
&&	echo "memory_limit = 1G" >> /usr/local/etc/php/conf.d/0-upload_large_dumps.ini \
&&	echo "max_execution_time = 600" >> /usr/local/etc/php/conf.d/0-upload_large_dumps.ini \
&&	echo "max_input_vars = 5000" >> /usr/local/etc/php/conf.d/0-upload_large_dumps.ini

STOPSIGNAL SIGINT

RUN	addgroup --system adminer \
&&	adduser --system --ingroup adminer adminer \
&&	mkdir -p /var/www/html \
&&	mkdir /var/www/html/plugins-enabled \
&&	chown -R adminer:adminer /var/www/html

WORKDIR /var/www/html

# Here you would want to enable all the DB types you need
RUN apt-get update \
    && apt-get install -y \
        git libpq-dev \
    && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql
RUN docker-php-ext-install pgsql pdo pdo_pgsql mysqli

COPY	*.php /var/www/html/
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf
ENV	ADMINER_VERSION 4.8.4
ENV	ADMINER_DOWNLOAD_SHA256 e9a9bc2cc2ac46d6d92f008de9379d2b21a3764a5f8956ed68456e190814b149
ENV	ADMINER_COMMIT f1e13af9252bfd88d816ef72593513c13adf1dd5

RUN	set -x \
&&	curl -fsSL "https://github.com/adminerevo/adminerevo/releases/download/v$ADMINER_VERSION/adminer-$ADMINER_VERSION.php" -o adminer.php \
&&	echo "$ADMINER_DOWNLOAD_SHA256  adminer.php" |sha256sum -c - \
&&	git clone --recurse-submodules=designs --depth 1 --shallow-submodules --branch "v$ADMINER_VERSION" https://github.com/adminerevo/adminerevo.git /tmp/adminer \
&&	commit="$(git -C /tmp/adminer/ rev-parse HEAD)" \
&&	[ "$commit" = "$ADMINER_COMMIT" ] \
&&	cp -r /tmp/adminer/designs/ /tmp/adminer/plugins/ . \
&&	rm -rf /tmp/adminer/

RUN apt-get update && apt-get install -y sed && rm -rf /var/lib/apt/lists/*
RUN sed -i "s/Listen 80/Listen ${PORT:-8080}/g" /etc/apache2/ports.conf

COPY	entrypoint.sh /usr/local/bin/
ENTRYPOINT	[ "entrypoint.sh", "docker-php-entrypoint" ]

USER	adminer

CMD ["apache2-foreground"]

EXPOSE 8080