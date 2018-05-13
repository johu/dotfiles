#!/bin/sh

# terminate already running instances
killall -q polybar

# wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# launch new instances
if type "xrandr"; then
	for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
		MONITOR=$m polybar -r top &
	done
else
	polybar -r top &
fi

echo "Bars launched..."
