#!/bin/bash

cp -a ${FILES}/nginx.conf /etc/nginx/conf.d/app.conf
cp -a ${FILES}/setup.sh /usr/local/bin/setup_wordpress.sh

#cp -a ${FILES}/varnish/* /etc/varnish/
