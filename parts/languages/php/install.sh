#!/bin/sh

# install php-fpm config
cp ${FILES}/php-fpm.conf /etc/php/php-fpm.conf

# install nginx config snippet
mkdir -p /etc/nginx/snippets
cp ${FILES}/nginx/* /etc/nginx/snippets/

# create service files
mkdir -p /service
cp -Ra ${FILES}/service /service/php-fpm
