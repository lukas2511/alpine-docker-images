#!/bin/ash

set -e

if [ "${1}" = "stage1" ]; then
	mkdir /image/etc
	cp -R /etc/apk /image/etc/
	apk --root /image --update-cache --initdb add alpine-base alpine-keys-kurzpw ca-certificates bash
	cat /etc/apk/repositories > /image/etc/apk/repositories
	cp /etc/localtime /image/etc/localtime
	chmod -R 777 /image/tmp /image/run /image/var/log
	chroot /image /usr/sbin/addgroup -S -g 1000 app
	chroot /image /usr/sbin/adduser -S -G app -u 1000 app
	cp -a /etc/resolv.conf /image/etc/resolv.conf
	mknod -m 622 /image/dev/console c 5 1
	mknod -m 666 /image/dev/zero c 1 5
	mknod -m 444 /image/dev/random c 1 8
	mknod -m 444 /image/dev/urandom c 1 9
	chroot /image /bin/bash /parts/build.sh stage2
	rm -r /image/dev/*
	exit 0
fi

if [ ! "${1}" = "stage2" ]; then
	echo 'uh?'
	exit 1
fi

# base system
packages=""

# get template config
source /template/config.sh

# get part configs
donesomething=1
added_parts=""
while [ "${donesomething}" = "1" ]; do
	donesomething=0
	for part in ${PARTS}; do
		if [[ ! " ${added_parts} " =~ " ${part} " ]]; then
			if [ -e /parts/${part}/config.sh ]; then
				export FILES=/parts/${part}/files
				source /parts/${part}/config.sh
			fi
			added_parts="${added_parts} ${part}"
			donesomething=1
		fi
	done
done

apk add ${packages}

# run part install scripts
for part in ${PARTS}; do
	if [ -e /parts/${part}/install.sh ]; then
		export FILES=/parts/${part}/files
		source /parts/${part}/install.sh
	fi
done

# run template install script
if [ -e /template/install.sh ]; then
	export FILES=/template/files
	source /template/install.sh
fi

cp -a /parts/start.sh /start.sh
