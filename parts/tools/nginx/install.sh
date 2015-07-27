#!/bin/bash

# install config
mkdir -p ${ROOT}/etc/nginx /etc/nginx/conf.d /etc/nginx/snippets
cp ${FILES}/nginx.conf /etc/nginx/nginx.conf
cp ${FILES}/security.conf /etc/nginx/snippets/security.conf

# create runtime directories
mkdir -p /var/lib/nginx /var/log/nginx
chown 1000:1000 /var/lib/nginx /var/log/nginx

# create service files
mkdir -p /service
cp -Ra ${FILES}/service /service/nginx


