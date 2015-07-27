#!/bin/ash

handle_signal() {
	for i in /service/* /service/*/log; do
		echo -n "Stopping ${i}..."
		if [ -e $i/stop ]; then
			$i/stop
		else
			svc -d $i
			state=up
			while [ "${state}" = "up" ]; do
				state="$(svstat $i | awk '{print $2}')"
				echo -n .
				sleep 0.1
			done
		fi
		echo ' stopped!'
	done

	sync
	echo 'Goodbye!'
	sleep 1
	killall -9 svscan
	exit 0
}

trap handle_signal SIGTERM 'SIGTERM' SIGTERM

svscan /service &
wait $!
sleep 5
exit 1
