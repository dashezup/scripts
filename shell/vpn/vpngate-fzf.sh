#!/bin/sh

CSV="/tmp/vpngate.csv"

# check dependencies
which curl fzf tput sed column cut base64 >/dev/null || exit 1

# download vpngate.csv

if [ ! -f $CSV ]; then
	echo "$(tput bold; tput setaf 4)$CSV$(tput setaf 1) not found$(tput sgr0), do you want to download it?"
	read -p "Press $(tput bold)Enter$(tput sgr0) to continue... " -r ANSWER && [ "$ANSWER" = "" ] || { echo "$(tput bold; tput setaf 1)Canceled$(tput sgr0)"; exit 0; }
	curl -o "$CSV" --progress-bar 'https://www.vpngate.net/api/iphone/'
fi


# echo "$(seq -s, 1 15)\n$(sed -n 2p vpngate.csv | sed 's/^#HostName,/HostName,/')" | column -s',' -t
# 1         2   3      4     5      6            7             8               9       10          11            12       13        14       15
# HostName  IP  Score  Ping  Speed  CountryLong  CountryShort  NumVpnSessions  Uptime  TotalUsers  TotalTraffic  LogType  Operator  Message  OpenVPN_ConfigData_Base64

get_csv() {
	echo '0,Hostname,Score,Ping,Speed,Country,Code,Sessions,Uptime,Users,Traffic,Log,Operator,Message'
	local i=0; sed -e '
	1,2d;$d
	s/weeks,/ weeks,/
	s/^#HostName,/HostName,/
	s/,Korea Republic of,/,South Korea,/
	s/,Russian Federation,/,Russia,/
	s/,Viet Nam,/,Vietnam,/
	' $CSV \
	| while IFS=, read HostName IP Score Ping Speed CountryLong CountryShort NumVpnSessions Uptime TotalUsers TotalTraffic LogType Operator Message OpenVPN_ConfigData_Base64; do
		local i=$(($i + 1))
		Score=$(numfmt --to=si $Score)
		Speed=$(numfmt --to=iec-i --suffix=B/s --format="%.1f" $Speed)
		UptimeInMilliseconds=$Uptime
		Uptime=$(echo "$(($UptimeInMilliseconds/15552000000)) years")                      # 1000*60*60*12*30*12
		[ "${Uptime%% *}" -eq 0 ] && Uptime="$(($UptimeInMilliseconds/1296000000)) months" # 1000*60*60*12*30
		[ "${Uptime%% *}" -eq 0 ] && Uptime="$(($UptimeInMilliseconds/43200000)) days"     # 1000*60*60*12
		[ "${Uptime%% *}" -eq 0 ] && Uptime="$(($UptimeInMilliseconds/3600000)) hours"     # 1000*60*60
		[ "${Uptime%% *}" -eq 0 ] && Uptime="$(($UptimeInMilliseconds/60000)) minutes"     # 1000*60
		[ "${Uptime%% *}" -eq 0 ] && Uptime="$(($UptimeInMilliseconds/1000)) seconds"      # 1000
		[ "${Uptime%% *}" -eq 0 ] && Uptime="${UptimeInMilliseconds} milliseconds"
		TotalUsers=$(numfmt --to=si $TotalUsers)
		TotalTraffic=$(numfmt --to=iec-i --suffix=B --format="%.1f" $TotalTraffic)
		#     1  2         3      4     5      6            7             8               9       10          11            12       13        14
		echo "$i,$HostName,$Score,$Ping,$Speed,$CountryLong,$CountryShort,$NumVpnSessions,$Uptime,$TotalUsers,$TotalTraffic,$LogType,$Operator,$Message"
	done
}

get_srv() {
	local NUM=$(get_csv | column -s, -t -R3,4,5,8,10,11 | fzf +s | cut -d' ' -f1)
	[ -z "$NUM" ] && exit 0
	if [ "$NUM" -ne 0 ]; then
		local SRV=$(sed -n "$(($NUM + 2))p" $CSV)
		local CountryCode=$(echo $SRV | awk -F, '{print tolower($7)}')
		local Hostname=$(echo $SRV | awk -F, '{print $1}')
		local OVPN="vpngate_${CountryCode}_${Hostname}.ovpn"
		read -p "Press $(tput bold)Enter$(tput sgr0) to save $(tput bold; tput setaf 4)${OVPN}$(tput sgr0)... " -r ANSWER
		[ "$ANSWER" = "" ] && echo $SRV | awk -F, '{print $15}' | base64 -di >$OVPN
	fi
}

while true; do get_srv; done
