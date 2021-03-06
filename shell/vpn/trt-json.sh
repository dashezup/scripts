#!/bin/bash

# trt (transparent proxy for Trojan)

INFO=~/.local/share/data/trojan/srvinfo.json
CONFIG="/etc/trojan/config.json"
SUBURL=""
# the value of IPV4_SERVERS_LIST and IPV6_SERVERS_LIST should be generated by the script itself
IPV4_SERVERS_LIST=""
IPV6_SERVERS_LIST=""
: "${progname:="${0##*/}"}"

## Part 1: iptables

query_ipv4() {
	all_servers=$1
	while true; do
		servers=$(printf "$all_servers" | grep '[[:alpha:]]')
		if [[ -z "$servers" ]]; then
			all_servers=$(echo "$all_servers" | sort | uniq | paste -s -d' ')
			break
		fi
		servers_ip=$(dig +short -t A $servers)
		all_servers=$(echo "$all_servers" | sed "/[[:alpha:]]/d")
		all_servers+=$(echo -e "\n$servers_ip")
	done
	echo $all_servers
}
query_ipv6() {
	all_servers=$1
	while true; do
		servers=$(printf "$all_servers" | grep -v ':' | grep '[[:alpha:]]')
		if [[ -z "$servers" ]]; then
			all_servers=$(echo "$all_servers" | sort | uniq | paste -s -d' ')
			break
		fi
		servers_ip=$(dig +short -t AAAA $servers)
		all_servers=$(echo "$all_servers" | sed "/\./d")
		all_servers+=$(echo -e "\n$servers_ip")
	done
	echo $all_servers
}
clear_iptables_rules() {
	[ "$EUID" -ne 0 ] && { echo "Please run as root" && exit 1; }
	## https://gist.github.com/jarek-przygodzki/29830f868e0c29e1dccb09beafbc4f72
	iptables -P INPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -P OUTPUT ACCEPT
	iptables -F INPUT
	iptables -F OUTPUT
	iptables -F FORWARD
	iptables -F
	iptables -t nat -F
	iptables -t mangle -F
	iptables -X
	iptables -t nat -X
	iptables -t mangle -X
	echo "Cleared iptables rules"
}
add_iptables_rules() {
	clear_iptables_rules
	## https://github.com/shadowsocks/shadowsocks-libev#transparent-proxy
	iptables -t nat -N TROJAN
	for ip in $IPV4_SERVERS_LIST; do
		iptables -t nat -A TROJAN -d $ip -j RETURN
	done
	iptables -t nat -A TROJAN -d 0.0.0.0/8 -j RETURN
	iptables -t nat -A TROJAN -d 10.0.0.0/8 -j RETURN
	iptables -t nat -A TROJAN -d 127.0.0.0/8 -j RETURN
	iptables -t nat -A TROJAN -d 169.254.0.0/16 -j RETURN
	iptables -t nat -A TROJAN -d 172.16.0.0/12 -j RETURN
	iptables -t nat -A TROJAN -d 192.168.0.0/16 -j RETURN
	iptables -t nat -A TROJAN -d 224.0.0.0/4 -j RETURN
	iptables -t nat -A TROJAN -d 240.0.0.0/4 -j RETURN
	iptables -t nat -A TROJAN -p tcp -j REDIRECT --to-ports 16280
	iptables -t nat -A OUTPUT -j TROJAN
	echo "Added iptables rules"
}

## Part 2: Update servers

update_srv() {
	read -p "Type $(tput bold)Yes$(tput sgr0) to continue... " && [ $REPLY == "Yes" ] || { echo "$(tput bold; tput setaf 1)Canceled$(tput sgr0)"; exit 1; }
	TROJAN_URLS=$(curl -s "${SUBURL}" | base64 -d)
	## IPv4 list
	SERVERS_LIST=$(echo "$TROJAN_URLS" | cut -d'@' -f2 | cut -d':' -f1 | sort | uniq)
	ipv4_list=$(query_ipv4 "$SERVERS_LIST")
	sed -i "s/^IPV4_SERVERS_LIST=.*$/IPV4_SERVERS_LIST=\"$ipv4_list\"/" $(realpath $0) && echo "Successfully updated $(tput bold)$(echo "$ipv4_list" | wc -w)$(tput sgr0) IPv4 addresses"
	## IPv6 list
	ipv6_list=$(query_ipv6 "$SERVERS_LIST")
	sed -i "s/^IPV6_SERVERS_LIST=.*$/IPV6_SERVERS_LIST=\"$ipv6_list\"/" $(realpath $0) && echo "Successfully updated $(tput bold)$(echo "$ipv6_list" | wc -w)$(tput sgr0) IPv6 addresses"
	## JSON
	: >"$INFO"
	while read -r node; do
		## mark
		mark=$(urldecode ${node#*\#})
		mark=$(echo $mark | edit_mark)
		mark_lower=$(echo $mark | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
		country=$(echo $mark | cut -d' ' -f1)
		flag=$(echo $country | name2flag)
		provider=$(echo $mark | cut -d' ' -f2)
		order=$(echo $mark | cut -d' ' -f3)
		## info
		node=${node#trojan://} && node=${node%\#*}
		password=${node%\@*} && node=${node#*@}
		remote_addr=${node%\:*}
		remote_port=${node#*:}
		case $provider in GIA|RT|AWS|Azure|CHT|TFN|TTNet|KDDI|GTT|Cogent|ETPI|KT|NTT|PCCW|WTT) level=global ratio="1";; esac
		case $provider in BGP) level=bgp ratio="1";; esac
		case $provider in IPLC) level=iplc ratio="2";; esac
		case $provider in IEPL) level=iepl ratio="2";; esac
		case $provider in Gamer) level=advanced ratio="10";; esac
		## json
		jo remote_addr=$remote_addr remote_port=$remote_port password="[\"$password\"]" mark="$(jo -- level=$level ratio=$ratio name="$mark" id="$mark_lower" flag="$flag" country="$country" provider="$provider" -s order="$order")"
		unset level ratio
	done < <(echo "$TROJAN_URLS" | sed 's/?allowInsecure=1&tfo=1//') | jo -p -a >"$INFO" && echo "Successfully updated $(tput bold)$(jq -r '.[].remote_addr' "$INFO"| wc -l)$(tput sgr0) servers"
}

gen_hosts() {
	DOMAINS=$(jq -r '.[].remote_addr' srvinfo.json | grep '[[:alpha:]]')
	while IFS= read -r domain; do
		query_ipv4 $domain | tr ' ' '\n' | sed "s/$/ $domain/"
	done <<< "$DOMAINS" | column -t
}

## Part 2: JSON

urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }
name2flag() {
	sed -e '
	s/AE/????????/
	s/AU/????????/
	s/BR/????????/
	s/DE/????????/
	s/FR/????????/
	s/GB/????????/
	s/HK/????????/
	s/IN/????????/
	s/JP/????????/
	s/KR/????????/
	s/PH/????????/
	s/RU/????????/
	s/SG/????????/
	s/TR/????????/
	s/TW/????????/
	s/US/????????/
	'
}
edit_mark() {
	sed -e '
	s/^?????????/RU/
	s/^??????/IN/
	s/^?????????/TR/
	s/^??????/BR/
	s/^??????/DE/
	s/^?????????/SG/
	s/^??????/JP/
	s/^??????/FR/
	s/^????????????/AU/
	s/^??????/US/
	s/^??????/TW/
	s/^??????/GB/
	s/^?????????/PH/
	s/^??????/KR/
	s/^??????/HK/
	s/^?????????/AE/
	'
}
query_nodes() {
	case "$LEVEL" in
		global|bgp|iplc|iepl|advanced)
			# summary
			ratio=$(jq -r --arg v "$LEVEL" '[.[].mark | select(.level==$v)][0].ratio' "$INFO")
			countries=$(jq -r --arg v "$LEVEL" '.[].mark | select(.level==$v) | .country' "$INFO" | sort | uniq | tr '[:upper:]' '[:lower:]' | tr '\n' ' ')
			providers=$(jq -r --arg v "$LEVEL" '.[].mark | select(.level==$v) | .provider' "$INFO" | sort | uniq | tr '\n' ' ')
			# list of servers
			#srvlist=$(jq -r --arg v "$LEVEL" '.[].mark | select(.level==$v) | .id + "\t" + .time_appconnect' "$INFO" | sed 's/^/  /' | sort)
			#num_srv=$(echo "$srvlist" | wc -l)
			# print
			srvlist=$(jq -r --arg v "$LEVEL" '.[].mark | select(.level==$v) | .time_appconnect + "|" + .speed_download + "|" + .id' "$INFO" | sed 's/^/  /' | sort -hr | column -s'|' -t)
			echo -e "\n$srvlist\n"
			echo -e "Level:|${LEVEL^}\nRatio:|$ratio\nCountries:|$countries\nNodes:|${num_srv}\nProviders:|$providers" | column -s'|' -t | sed 's/^/  /' && echo
			;;
		time) jq -r '.[].mark | .time_appconnect + "|" + .speed_download + "|" + .id' $INFO | sed 's/^/  /' | column -s'|' -t | sort -hr | sed '/^   /d' | grep 'MiB/s\|0B/s' | GREP_COLORS='ms=01;32' egrep --color 'hk_|kr_|jp_|tw_|$';;
		speed) jq -r '.[].mark | .speed_download + "|" + .time_appconnect + "|" + .id' $INFO | sed 's/^/  /' | column -s'|' -t | sort -h | sed '/^   /d' | grep 'MiB/s\|0B/s' | GREP_COLORS='ms=01;32' egrep --color 'hk_|kr_|jp_|tw_|$';;
		country) jq -r '.[].mark | .id + "|" + .time_appconnect + "|" + .speed_download' $INFO | sed 's/^/  /' | column -s'|' -t | sort -h | GREP_COLORS='ms=01;32' egrep --color 'hk_|kr_|jp_|tw_|$';;

		*) usage ;;
	esac
}
switch_node() {
	# info
	if [[ ! -z "$NODE" ]] && [[ $(jq -r --arg v "$NODE" '.[].mark | select(.id==$v) | .id' $INFO) == "$NODE" ]]; then
		id="$NODE"
	else
		echo "No such node" && exit 1
	fi
	# variables
	remote_addr=$(jq -r --arg v "$id" '.[] | select(.mark.id==$v) | .remote_addr' "$INFO")
	remote_port=$(jq -r --arg v "$id" '.[] | select(.mark.id==$v) | .remote_port' "$INFO")
	password=$(jq -r --arg v "$id" '.[] | select(.mark.id==$v) | .password | .[0]' "$INFO")
	level=$(jq -r --arg v "$id" '.[].mark | select(.id==$v) | .level' "$INFO")
	ratio=$(jq -r --arg v "$id" '.[].mark | select(.id==$v) | .ratio' "$INFO")
	flag=$(jq -r --arg v "$id" '.[].mark | select(.id==$v) | .flag' "$INFO")
	id=$(jq -r --arg v "$id" '.[].mark | select(.id==$v) | .id' "$INFO")
	name=$(jq -r --arg v "$id" '.[].mark | select(.id==$v) | .name' "$INFO")
	provider=$(jq -r --arg v "$id" '.[].mark | select(.id==$v) | .provider' "$INFO")
	# edit config
	jj -v "$remote_addr" -p -i $CONFIG -o $CONFIG 'remote_addr'
	jj -v "$remote_port" -p -i $CONFIG -o $CONFIG 'remote_port'
	jj -v "$password" -p -i $CONFIG -o $CONFIG 'password.0'
	jj -v "$level" -p -i $CONFIG -o $CONFIG 'info.level'
	jj -v "$ratio" -p -i $CONFIG -o $CONFIG 'info.ratio'
	jj -v "$flag" -p -i $CONFIG -o $CONFIG 'info.flag'
	jj -v "$id" -p -i $CONFIG -o $CONFIG 'info.id'
	jj -v "$name" -p -i $CONFIG -o $CONFIG 'info.name'
	jj -v "$provider" -p -i $CONFIG -o $CONFIG 'info.provider'
	#echo -e "Level:|$level\nRatio:|$ratio\nNode:|$NODE\nServer:|$remote_addr\nPort:|$remote_port\nPassword:|$password" | column -s'|' -t
	echo -e "$id\t${remote_addr}:${remote_port}"
}

get_info() {
	echo "Servers: $(tput bold)$(jq -r '.[].remote_addr' $INFO | wc -l)$(tput sgr0)"
	echo "IPv4:    $(tput bold)$(echo $IPV4_SERVERS_LIST | wc -w)$(tput sgr0)"
	echo "IPv6:    $(tput bold)$(echo $IPV6_SERVERS_LIST | wc -w)$(tput sgr0)"
	echo
	[ -s /var/service/trojan/supervise/pid ] && jq -r '.info | "NAT:     " + .name + " (" + .level + " *" + (.ratio|tostring) + ")"' /etc/trojan/config.json
	[ -s $HOME/.local/service/trojan-client/supervise/pid ] && jq -r '.info | "Client:  " + .name + " (" + .level + " *" + (.ratio|tostring) + ")"' $HOME/.local/service/trojan-client/client.json

}

speedtest() {
	case "$LEVEL" in
		global|bgp|iplc|iepl|advanced)
			read -p "Type $(tput bold)Yes$(tput sgr0) to continue... " && [ $REPLY == "Yes" ] || { echo "$(tput bold; tput setaf 1)Canceled$(tput sgr0)"; exit 1; }
			#echo "$INFO $CONFIG"
			SERVERS=$(jq -r --arg v "$LEVEL" '.[].mark | select(.level==$v) | .id' $INFO)
			#echo "$SERVERS"
			for id in $SERVERS; do
				#id=$(jq -r --arg v "$sid" '.[] | select(.id==$v) | .mark | .id' $INFO)
				index=$(jq -r --arg v "$id" 'map(.mark.id==$v) | index(true)' $INFO)
				NODE=$id switch_node
				if sv reload ~/.local/service/trojan-client{,/log} >/dev/null; then
					sleep 1
				else
					echo "Failed to reload trojan-client service config, exiting..." && exit 1
				fi
				time_appconnect=$(curl --connect-timeout 2 -x socks5h://127.0.0.1:51837 -o/dev/null -sw '%{time_appconnect}' 'https://connectivitycheck.gstatic.com/generate_204')
				time_appconnect=$(printf "%.0f ms" "$(bc<<<${time_appconnect}*1000)")
				if [[ $time_appconnect == "0 ms" ]]; then
					time_appconnect=""
					speed_download=""
				else
					speed_download=$(curl -x socks5h://127.0.0.1:51837 http://speedtest-sgp1.digitalocean.com/10mb.test -s -o/dev/null --write-out '%{speed_download}' | numfmt --to=iec-i --suffix=B/s)
				fi
				echo -e "$time_appconnect\t$speed_download\n"
				jj -v "$time_appconnect" -p -i $INFO -o $INFO "$index.mark.time_appconnect"
				jj -v "$speed_download" -p -i $INFO -o $INFO "$index.mark.speed_download"
			done;;
		*) usage ;;
	esac
}

usage() {
	cat <<_EOF | GREP_COLORS='ms=1' egrep --color "$progname|$"
Usage: $progname <node_level>          query nodes by levels
       $progname <time|speed|country>  query nodes by types
       $progname sn <node_id>          switch node (nat)
       $progname sc <node_id>          switch node (client)
       $progname i                     show info

       $progname -u  update IP list and json
       $progname -t <node_level> speed test

  sudo $progname -a  add iptables rules
  sudo $progname -c  clear iptables rules

  +------------+-------+-------------+
  | node_level | ratio | provider    |
  +------------+-------+-------------+
  |  global    |  1    | *various*   |
  |  bgp       |  1.2  | BGP         |
  |  iplc      |  2    | IPLC        |
  |  iepl      |  2    | IEPL        |
  |  advanced  |  10   | *gamer*     |
  +------------+-------+-------------+

_EOF
	exit 1
}

case "$1" in
	global|bgp|iplc|iepl|advanced|time|speed|country) LEVEL=$1 query_nodes | GREP_COLORS='ms=01;32' egrep --color 'hk_|kr_|jp_|tw_|$';;
	sn)
		NODE=$2 switch_node
		sv reload trojan{,/log}
		;;
	sc)
		NODE=$2 CONFIG=~/.local/service/trojan-client/client.json switch_node
		sv reload ~/.local/service/trojan-client
		;;
	i) get_info ;;
	#-h) gen_hosts ;;
	-u) update_srv ;;
	-t) CONFIG=~/.local/service/trojan-client/client.json LEVEL=$2 speedtest ;;
	-a) add_iptables_rules ;;
	-c) clear_iptables_rules ;;
	*) usage ;;
esac
exit 0


## extra comands
# jq -r --arg v global '.[].mark | select(.level==$v) | .speed_download + "|" + .time_appconnect + "|" + .id' ~/.local/share/data/trojan/srvinfo.json | sed 's/^/  /' | column -s'|' -t | sort -h
# jq -r '.[].mark | .speed_download + "|" + .time_appconnect + "|" + .id' ~/.local/share/data/trojan/srvinfo.json | sed 's/^/  /' | column -s'|' -t | sort -h | GREP_COLORS='ms=01;32' egrep --color 'hk_|kr_|jp_|tw_|$'
# jq -r '.[].mark | .time_appconnect + "|" + .speed_download + "|" + .id' ~/.local/share/data/trojan/srvinfo.json | sed 's/^/  /' | column -s'|' -t | sort -h | GREP_COLORS='ms=01;32' egrep --color 'hk_|kr_|jp_|tw_|$'
