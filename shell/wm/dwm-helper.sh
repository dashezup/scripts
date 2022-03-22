#!/bin/sh

: "${progname:="${0##*/}"}"

screenshot() {
	sleep 0.2 && scrot -s -e 'xclip -selection clipboard -t "image/png" < $f' "$HOME/Pictures/Screenshot/%Y-%m-%d-\$p_\$wx\$h_scrot.png"
}

usage() {
	echo "Usage: $progname screenshot"
}

case "$1" in
	screenshot) screenshot ;;
	* ) usage ;;
esac

exit 0

