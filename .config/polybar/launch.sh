#!/bin/sh

# terminate already running instances
killall -q polybar

# wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# launch new instances
polybar -r top &

echo "Bars launched..."
