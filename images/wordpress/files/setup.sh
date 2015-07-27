#!/bin/sh

# download wordpress
wget https://wordpress.org/latest.tar.gz -O /tmp/wordpress.tar.gz
gunzip /tmp/wordpress.tar.gz

# unpack wordpress and move to docroot
tar xf /tmp/wordpress.tar -C /tmp/
mv /tmp/wordpress/* /app/www/

# wait for database login and server
while [ ! -e /app/mysql/my_app.cnf ]; do sleep 1; done
while [ ! -e /run/mysqld/mysqld.sock ]; do sleep 1; done

# set database information
cat > /app/www/wp-config.php << EOF
<?php
define('DB_NAME', 'app');
define('DB_USER', 'app');
define('DB_PASSWORD', '$(cat /app/mysql/my_app.cnf | grep ^password | cut -d= -f2)');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');

define('AUTH_KEY',         '$(pwgen 50 1)');
define('SECURE_AUTH_KEY',  '$(pwgen 50 1)');
define('LOGGED_IN_KEY',    '$(pwgen 50 1)');
define('NONCE_KEY',        '$(pwgen 50 1)');
define('AUTH_SALT',        '$(pwgen 50 1)');
define('SECURE_AUTH_SALT', '$(pwgen 50 1)');
define('LOGGED_IN_SALT',   '$(pwgen 50 1)');
define('NONCE_SALT',       '$(pwgen 50 1)');

// define('VHP_VARNISH_IP', '127.0.0.1');

\$table_prefix  = 'wp_';

define('WP_DEBUG', false);

if ( !defined('ABSPATH') )
	define('ABSPATH', dirname(__FILE__) . '/');

require_once(ABSPATH . 'wp-settings.php');
?>
EOF

# install varnish purge plugin
#wget https://downloads.wordpress.org/plugin/varnish-http-purge.zip -O /tmp/varnish-http-purge.zip
#(cd /app/www/wp-content/plugins/ && unzip /tmp/varnish-http-purge.zip)

# fix permissions
chown -R app: /app/www
chmod 600 /app/www/wp-config.php

# cleanup
rmdir /tmp/wordpress
rm /tmp/wordpress.tar
#rm /tmp/varnish-http-purge.zip
