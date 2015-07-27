#!/bin/bash

REGISTRY="registry.kurz.pw:443"
MIRROR="https://abuild.kurz.pw/packages"

get_part_list() {
	image=$1
	if [ -z "${image}" ]; then
		echo "uh?!"
		exit 1
	fi

	(
		donesomething=1
		added_parts=""
		. images/${image}/config.sh
		while [ "${donesomething}" = "1" ]; do
			donesomething=0
			for part in ${PARTS}; do
				if [[ ! " ${added_parts} " =~ " ${part} " ]]; then
					if [ -e parts/${part}/config.sh ]; then
						. parts/${part}/config.sh
					fi
					added_parts="${added_parts} ${part}"
					donesomething=1
				fi
			done
		done
		echo $PARTS
	)
}

get_last_change() {
	image=$1
	if [ -z "${image}" ]; then
		echo "uh?!"
		exit 1
	fi

	last_change="$(find images/${image} -printf '%T@\n' | sort -n | tail -n1 | cut -d. -f1)"
	for part in $(get_part_list $image); do
		part_last_change="$(find parts/${part} -printf '%T@\n' | sort -n | tail -n1 | cut -d. -f1)"
		if [ "${part_last_change}" -gt "${last_change}" ]; then
			last_change=${part_last_change}
		fi
	done

	echo ${last_change}
}

rebuild_image() {
	image=$1
	if [ -z "${image}" ]; then
		echo "uh?!"
		exit 1
	fi

	mkdir -p .log
	buildlog=".log/$(date +"%Y-%m-%d_%H-%M-%S")-${image}.log"

	echo ":: Rebuilding ${image}"

	rm -rf /tmp/alpine/${image}

	echo "   -> Building rootfs..."
	docker run \
		-t -i --rm=true \
		--name alpine-build \
		-v /tmp/alpine/${image}:/image \
		-v ${PWD}/parts:/image/parts \
		-v ${PWD}/images/${image}:/image/template \
		${REGISTRY}/alpine \
		/image/parts/build.sh stage1 2>> ${buildlog} >> ${buildlog}

	if [ ! "$?" = "0" ]; then
		echo "   !! Build failed!"
		exit 1
	fi

	echo "   -> Importing image..."
	tar c -C /tmp/alpine/${image} -c . 2>> ${buildlog} | \
		docker import \
			-c 'VOLUME /log' \
			-c 'VOLUME /app' \
			-c 'ENTRYPOINT ["/start.sh"]' \
			- \
			${REGISTRY}/${image} \
			2>> ${buildlog} >> ${buildlog}

	if [ ! "$?" = "0" ]; then
		echo "   !! Import failed!"
		exit 1
	fi

	echo "   -> Pushing image..."
	docker push ${REGISTRY}/${image} 2>> ${buildlog} >> ${buildlog}

	if [ ! "$?" = "0" ]; then
		echo "   !! Pushing failed!"
		exit 1
	fi

	echo "   -> Done!"
}

rebuild_base_image() {
	echo ":: Rebuilding alpine (base image)"
	rm -rf .alpine
	mkdir .alpine

	buildlog=".log/$(date +"%Y-%m-%d_%H-%M-%S")-alpine.log"

	echo "   -> Installing base packages..."
	./.apk-static \
		--repository "${MIRROR}/main" \
		--root .alpine \
		--update-cache \
		--allow-untrusted \
		--initdb \
		add \
		alpine-base alpine-keys-kurzpw ca-certificates \
		2>> ${buildlog} >> ${buildlog}

	if [ ! "$?" = "0" ]; then
		echo "   !! Installation failed!"
		exit 1
	fi

	echo "   -> Setting up timezone and repositories..."
	cp /etc/localtime .alpine/etc/localtime
	echo "${MIRROR}/main" > .alpine/etc/apk/repositories

	echo "   -> Removing apk cache..."
	rm -rf .alpine/var/cache/apk/*

	echo "   -> Importing image..."
	tar c -C .alpine -c . 2>> ${buildlog} | \
		docker import \
			-c 'VOLUME /image' \
			- \
			${REGISTRY}/alpine \
			2>> ${buildlog} >> ${buildlog}

	if [ ! "$?" = "0" ]; then
		echo "   !! Import failed!"
		exit 1
	fi

	echo "   -> Pushing image..."
	docker push ${REGISTRY}/alpine 2>> ${buildlog} >> ${buildlog}

	if [ ! "$?" = "0" ]; then
		echo "   !! Pushing failed!"
		exit 1
	fi

	rebuild_all=y
}

# image list
IMAGES=""
for image in images/*; do
	IMAGES="${IMAGES} $(echo ${image} | cut -d/ -f2)"
done

# create buildlog directory
mkdir -p .log

# single image rebuild
if [ ! -z "${1}" ] && [[ " ${IMAGES} " =~ " ${1} " ]]; then
	IMAGES="${1}"
elif [ "${1}" = "-a" ]; then
	rebuild_all=y
elif [ ! -z "${1}" ]; then
	echo "Image '${1}' not found."
	exit 1
fi

# check if base image is up to date
rebuild_all=${rebuild_all:-n}
if [ "${rebuild_all}" = "y" ] || [ ! -e .alpine ]; then
	rebuild_base_image
else
	docker_created="$(docker inspect -f '{{ .Created }}' ${REGISTRY}/alpine 2> /dev/null)"
	if [ ! "$?" = "0" ]; then
		rebuild_base_image
	else
		last_update="$(date +%s --date="${docker_created}")"
		last_change="$(find make.sh -printf '%T@\n' | sort -n | tail -n1 | cut -d. -f1)"
		if [ "${last_change}" -gt "${last_update}" ]; then
			rebuild_base_image
		fi
	fi
fi

# images
for image in ${IMAGES}; do
	docker_created="$(docker inspect -f '{{ .Created }}' ${REGISTRY}/${image} 2> /dev/null)"

	if [ ! "$?" = "0" ] || [ "${rebuild_all}" = "y" ]; then
		rebuild_image $image
	else
		last_update="$(date +%s --date="${docker_created}")"
		last_change="$(get_last_change ${image})"
		if [ "${last_change}" -gt "${last_update}" ]; then
			rebuild_image $image
		else
			echo ":: ${image} is up to date!"
		fi
	fi
done

