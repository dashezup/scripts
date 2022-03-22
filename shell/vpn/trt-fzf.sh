#!/bin/bash

: "${progname:="${0##*/}"}"
TROJAN_SUBURL=""
CSV="/home/user/.local/share/data/trojan/trojan.csv" # use absolute path

urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

country_zh2code() {
	sed -e '
	s/,俄羅斯 /,RU /
	s/,印度 /,IN /
	s/,土耳其 /,TR /
	s/,巴西 /,BR /
	s/,德國 /,DE /
	s/,新加坡 /,SG /
	s/,日本 /,JP /
	s/,法國 /,FR /
	s/,澳大利亞 /,AU /
	s/,美國 /,US /
	s/,臺灣 /,TW /
	s/,英國 /,GB /
	s/,菲律賓 /,PH /
	s/,韓國 /,KR /
	s/,香港 /,HK /
	#s/,阿聯酋 /,AE /
	'
}

country_code2name() {
	sed -e '
	s/AU/Australia/
	s/BR/Brazil/
	s/DE/Germany/
	s/FR/Frace/
	s/GB/United Kingdom/
	s/HK/Hong Kong/
	s/IN/India/
	s/JP/Japan/
	s/KR/South Korea/
	s/PH/Philippines/
	s/RU/Russia/
	s/SG/Singapore/
	s/TR/Turkey/
	s/TW/Taiwan/
	s/US/United States/
	'
}

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

url2csv() {
	read -p "Type $(tput bold)Yes$(tput sgr0) to continue... " && [ $REPLY == "Yes" ] || { echo "$(tput bold; tput setaf 1)Canceled$(tput sgr0)"; exit 1; }
	: >$CSV
	#      1        2           3           4            5            6        7      8               9              10
	#echo "password,remote_addr,remote_port,country_code,country_name,provider,number,time_appconnect,speed_download,ipv4" >>$CSV
	BASE64_URLS=$(curl --progress-bar $TROJAN_SUBURL)
	total=$(echo "$BASE64_URLS" | base64 -d | wc -l)
	local i=0
	while IFS=, read -r password remote_addr remote_port mark; do
		local i=$(($i + 1))
		mark=${mark//,}
		#mark=${mark/ /,}
		#country=${mark%% *}; mark=${mark#*$country}; mark=${mark/ /}
		#provider=${mark%% *}; mark=${mark#*$provider}; number=${mark/ /}
		IFS=" " read -r country_code provider number <<<$(echo "$mark")
		country_name=$(echo "$country_code" | country_code2name)
		CONFIG=$HOME/.local/service/trojan-client/client.json switch_proxy
		local ipv4=$(query_ipv4 $remote_addr)
		sv restart $HOME/.local/service/trojan-client >/dev/null
		sleep 0.8
		time_appconnect=$(curl --connect-timeout 2 -x socks5h://127.0.0.1:51837 -o/dev/null -sw '%{time_appconnect}' 'https://connectivitycheck.gstatic.com/generate_204')
		time_appconnect=$(printf "%.0f ms" "$(bc<<<${time_appconnect}*1000)")
		speed_download=$(curl -x socks5h://127.0.0.1:51837 http://speedtest-sgp1.digitalocean.com/10mb.test --progress-bar -o/dev/null --write-out '%{speed_download}' | numfmt --to=iec-i --suffix=B/s)
		echo "$i/$total | $country_code $provider $number | $time_appconnect $speed_download | $ipv4"
		echo "$password,$remote_addr,$remote_port,$country_code,$country_name,$provider,$number,$time_appconnect,$speed_download,$ipv4" >>$CSV
		sleep 2
	done < <(urldecode "$(echo "$BASE64_URLS" | base64 -d | sed 's#^trojan://##' | sed 's/?allowInsecure=1&tfo=1//' | sed 's/@/,/; s/:/,/; s/#/,/')" | country_zh2code)
}

switch_proxy() {
	#jo run_type=client local_addr=0.0.0.0 local_port=51837 remote_addr=$remote_addr remote_port=$remote_port password=$(jo -a $password) log_level=0 ssl=$(jo verify=false verify_hostname=true cert= cipher="ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA:AES128-SHA:AES256-SHA:DES-CBC3-SHA" sni= alpn=$(jo -a h2 "http/1.1") reuse_session=true session_ticket=false curse=) tcp=$(jo no_delay=true keep_alive=true reuse_port=false fast_open=false fast_open_qlen=20) >$CONFIG
	#jo run_type=nat local_addr=127.0.0.1 local_port=16280 remote_addr=$remote_addr remote_port=$remote_port password=$(jo -a $password) log_level=0 ssl=$(jo verify=false verify_hostname=true cert= cipher="ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA:AES128-SHA:AES256-SHA:DES-CBC3-SHA" sni= alpn=$(jo -a h2 "http/1.1") reuse_session=true session_ticket=false curse=) tcp=$(jo no_delay=true keep_alive=true reuse_port=false fast_open=false fast_open_qlen=20) >$CONFIG
	jj -v "$remote_addr" -p -i $CONFIG -o $CONFIG 'remote_addr'
	jj -v "$remote_port" -p -i $CONFIG -o $CONFIG 'remote_port'
	jj -v "$password" -p -i $CONFIG -o $CONFIG 'password.0'
}

select_srv() {
	while true; do
		local SORTED_CSV=$(cat $CSV | awk 'BEGIN{FS=OFS=","}{print $9,$0}' | sort -hr)
		local NUM=$(while IFS=, read -r speed password remote_addr remote_port country_code country_name provider number time_appconnect speed_download ipv4; do
			echo "$speed_download,$time_appconnect,$country_code,$provider,$number,$remote_addr,$remote_port,$country_name"
		done < <(echo "$SORTED_CSV") | sed '1iSpeed,Time,Country code,Provider,Number,Address,Port,Country name' | awk 'BEGIN{FS=OFS=","}{print i++","$0}' | column -s, -t | fzf | cut -d' ' -f1)
		[ -z "$NUM" ] && exit 0
		if [ "$NUM" -ne 0 ]; then
			IFS=, read speed password remote_addr remote_port country_code country_name provider number time_appconnect speed_download ipv4 <<<$(echo "$SORTED_CSV" | sed "${NUM}q;d")
			break
		fi
	done
}

reset_iptables_rules() {
	#[ "$EUID" -ne 0 ] && { echo "Please run as root" && exit 1; }
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
	echo "Resetted iptables rules"
}
add_iptables_rules() {
	reset_iptables_rules
	## https://github.com/shadowsocks/shadowsocks-libev#transparent-proxy
	iptables -t nat -N TROJAN
	for ip in $ipv4; do
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

get_info() {
	printf 'Clint: '
	grep "^$(jq -r '.password[0] + "," + .remote_addr + "," + (.remote_port|tostring)' ~/.local/service/trojan-client/client.json)," $CSV | cut -d',' -f4,6,7 --output-delimiter=' '
	printf 'Nat:   '
	grep "^$(jq -r '.password[0] + "," + .remote_addr + "," + (.remote_port|tostring)' /etc/trojan/config.json)," $CSV | cut -d',' -f4,6,7 --output-delimiter=' '
}

usage() {
	cat <<_EOF | GREP_COLORS='ms=1' egrep --color "$progname|$"
Usage: $progname -f       get csv
       $progname s        select node
       $progname c        switch node for trojan client
       $progname n        switch node for trojan NAT

       $progname r        reset iptables rules
       $progname a        add iptables rules

_EOF
	exit 1
}


case $1 in
	-f)	url2csv;;
	s)
		select_srv
		echo "$country_code $provider $number ($remote_addr)"
		;;
	c)
		CONFIG=$HOME/.local/service/trojan-client/client.json
		select_srv
		echo "Cient: $country_code $provider $number ($remote_addr)"
		switch_proxy
		sv restart $HOME/.local/service/trojan-client >/dev/null
		;;
	n)
		[ "$EUID" -ne 0 ] && { echo "Please run as root" && exit 1; }
		CONFIG=/etc/trojan/config.json
		select_srv
		echo "NAT: $country_code $provider $number ($remote_addr)"
		echo "IPv4: $ipv4"
		switch_proxy
		sv restart trojan
		add_iptables_rules
		;;
	r)
		[ "$EUID" -ne 0 ] && { echo "Please run as root" && exit 1; }
		reset_iptables_rules
		;;
	a)
		[ "$EUID" -ne 0 ] && { echo "Please run as root" && exit 1; }
		ipv4=$(grep "^$(jq -r '.password[0] + "," + .remote_addr + "," + (.remote_port|tostring)' /etc/trojan/config.json)," $CSV | cut -d',' -f10 --output-delimiter=' ')
		add_iptables_rules
		;;
	i)
		get_info
		;;
	*) usage;;
esac
exit 0
