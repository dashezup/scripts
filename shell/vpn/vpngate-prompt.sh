#!/bin/sh

ServerList="https://www.vpngate.net/api/iphone/"
CSV="/tmp/vpngate.csv"

: "${progname:="${0##*/}"}"



help() {
	cat <<_EOF | GREP_COLORS='ms=01;32' egrep --color "^f |^l |^g |^h |^c |^q|$"
f | fetch    fetch $FileName
l | list     list servers
g | get      get OpenVPN ovpn file(s)
h | help     show this help
c | clear    clear the terminal screen
q | quit     quit

_EOF
	if [ -f $CSV ]; then
		srv_info
		echo
	else
		echo "$(tput bold)$(tput setaf 1)Can't find $FileName"
		echo "Please fetch it at first$(tput sgr0)"
	fi
}

fetch_srv() {
	local HTTP_CODE=$(curl -s --write-out %{http_code} -o "$CSV" "$ServerList")
	case "$HTTP_CODE" in
		200) echo "$(tput bold)$(tput setaf 2)successfully fetched $FileName$(tput sgr0)";;
		000) echo "failed to fetch $FileName";;
	*) echo "HTTP code: ($HTTP_CODE)";;
	esac
	echo
}

srv_info() {
	local total=$(sed '1,2d;$d' $CSV | wc -l)
	echo "total servers: $(tput setaf 4)${total}$(tput sgr0)"
}

list_srv() {
	srv_info
	SRV_ALL=$(sed '1,2d;$d' $CSV)
	local countries=$(echo "$SRV_ALL" | awk -F',' -vOFS=',' '{print $7}' | sort | uniq | tr '[:upper:]' '[:lower:]' | paste -s -d' ')
	local country_list=$(echo $countries | tr ' ' '|')
	echo "available countries: $(tput bold)$(tput setaf 2)$countries$(tput sgr0)"
	echo "$(tput setaf 3)Input one of the country name above"
	echo "or leave it blank to list all servers$(tput sgr0)"
	read -p "country: " country
	local SRV_LIST=$(echo "$SRV_ALL" | grep -i ",$country," | awk -F',' -vOFS=',' '{print $3, $4, $5, $1, $6}' | awk -F',' -vOFS=',' '{tmp_score="echo "$1" | numfmt --to=si"; tmp_speed="echo "$3" | numfmt --to=iec-i --suffix=B/s"; tmp_score | getline score; tmp_speed | getline speed; $1=score; $3=speed; print}' | sort -h)
	if [ ! -z "${SRV_LIST}" ]; then
		local SRV_LIST_APPEND=$(sed -n 2p $CSV | sed 's/^#HostName/HostName/' | awk -F',' -vOFS=',' '{print $3, $4, $5, $1, $6}')
		echo "${SRV_LIST}
$(tput bold)$(tput setaf 4)${SRV_LIST_APPEND}$(tput sgr0)" | column -s',' -t
	fi
}

get_ovpn() {
	echo "$(tput setaf 3) Input the hostname you get from the output of g | get"
	echo " You can input multiple hostnames by using space as separator$(tput sgr0)"
	read -p "hostname(s): " hostnames
	for srv in $hostnames; do
		if grep "^${srv}," $CSV >/dev/null; then
			echo "$SRV_ALL" | grep "^${srv}," | awk -F',' -vOFS=',' '{print $15}' | base64 -di >${srv}.ovpn
			echo "get: ${srv}.ovpn"
		else
			echo "$(tput bold)$(tput setaf 1)$srv: no such hostname$(tput sgr0)"
		fi
	done
}

main_prompt() {
	while true; do
		read -p "$(basename $progname .sh)> $(tput bold)" cmd
		tput sgr0
		case "$cmd" in
			f|fetch) fetch_srv;;
			l|list) list_srv;;
			g|get) get_ovpn;;
			h|help) help;;
			c|clear) clear >$(tty);;
			q|quit) exit 0;;
			*) help;;
		esac
	done
}

main_prompt
