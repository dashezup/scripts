#!/bin/bash

# Save and show traffic usage
# e.g. run this script (with root) before shutdown the OS to save traffic stats
# run the script with a non-root user to show saved total traffic usage

STATS_TXT="$(realpath $(dirname $0))/net-dev-stats.txt"

[ "$EUID" -ne 0 ] || { echo "Saving stats..."; sed -n 's/://p' /proc/net/dev | awk -v date="$EPOCHSECONDS" '{print date, $1, $2, $10}' >>"$STATS_TXT"; exit 0; }

show_saved_stats() {
	echo -e '\e[1mINTERFACE RX TX\e[0m'
	while read interface; do
		grep " ${interface} " "$STATS_TXT" \
			| awk -v interface="$interface" '{rx += $3; tx += $4} END {print interface, rx, tx}' \
			| numfmt --field=2,3 --to=iec
	done < <(awk '{print $2}' $STATS_TXT | sort | uniq)
}

show_current_stats() {
	echo -e '\e[1mINTERFACE RX TX\e[0m'
	grep ':' /proc/net/dev | awk '{print $1, $2, $10}' | numfmt --field=2,3 --to=iec | column -t
}

[ -s "$STATS_TXT" ] && { echo -e "\e[1m- Saved stats\e[0m:"; show_saved_stats | column -t; echo; }
echo -e "\e[1m- Current stats\e[0m:"; show_current_stats | column -t
