#!/bin/bash

CSV="/tmp/vpngate.csv"

# $ sed 's/^#HostName,/HostName,/; 2q;d' /tmp/vpngate.csv | tr ',' '\n' | awk '{print NR " " $0}' | column -t -R1
#  1  HostName
#  2  IP
#  3  Score
#  4  Ping
#  5  Speed
#  6  CountryLong
#  7  CountryShort
#  8  NumVpnSessions
#  9  Uptime
# 10  TotalUsers
# 11  TotalTraffic
# 12  LogType
# 13  Operator
# 14  Message
# 15  OpenVPN_ConfigData_Base64


# check dependencies
which dialog curl awk sort uniq awk grep column >/dev/null || exit 1

# get vpngate.csv
if [ ! -f $CSV ]; then
	dialog --yesno "$CSV not found, download it?" 6 28
	if [ $? = 0 ]; then
		curl -o "$CSV" "https://www.vpngate.net/api/iphone/" 2>&1 | dialog --progressbox 20 85
	else
		clear
		exit 0
	fi
fi

# get server list
SRV_LIST=$(sed -e '
	1,2d;$d
	s/,Korea Republic of,/,South Korea,/
	s/,Russian Federation,/,Russia,/
	s/,Viet Nam,/,Vietnam,/
	' $CSV
)

get_ovpn() {
	# select country
	local C=(ALL ALL)
	while read -r line; do
		country_short=${line%,*}
		country_long=${line#*,}
		C+=($country_short "$country_long")
	done < <(echo "$SRV_LIST" | awk -F',' -vOFS=',' '{print toupper($7), $6}' | sort | uniq)

	if [ -z "$country" ]; then
		country=$(dialog --title "Select country" --menu "Choose server location" 20 40 17 "${C[@]}" 3>&2 2>&1 1>&3)
		[ $? -ne 0 ] && { clear; exit 0; }
	fi
	[ "$country" != ALL ] && local SRV_LIST=$(echo "$SRV_LIST" | grep -i ",${country},")

	# array of list of VPN Gate servers for dialog
	local SRV_LIST_FORMATTED=$(echo "$SRV_LIST" \
		| awk -F',' -vOFS=',' '{print $3, $4, $5, $6}' \
		| awk -F',' -vOFS=',' '{
		tmp_score="echo "$1" | numfmt --to=si"
		tmp_speed="echo "$3" | numfmt --to=iec-i --suffix=B/s --format=\"%.1f\""
		tmp_score | getline score
		tmp_speed | getline speed
		$1=score
		$3=speed
		print
		}'
	)

	let i=0
	local W=("N" "Score Ping    Speed   Country")
	while read -r line; do
		let i=$i+1
		W+=($i "$line")
	done < <(echo "$SRV_LIST_FORMATTED" | column -s',' -t -R1,2,3)

	# select server and save ovpn files
	NUM=$(dialog \
		--title "List of VPN Gate servers ($country)" \
		--default-item "$NUM" \
		--menu "Choose to save ovpn file" 40 60 17 "${W[@]}" 3>&2 2>&1 1>&3)
	if [ -z "$NUM" ]; then
		clear
		exit 0
	else
		if [ $NUM = "N" ]; then
			unset country
		else
			local SRV_INFO=$(echo "$SRV_LIST" | sed -n "${NUM}p")
			IFS=, read HostName IP Score Ping Speed CountryLong CountryShort Other <<<"$(echo $SRV_INFO)"
			local OVPN="vpngate_${CountryShort,,}_${HostName}.ovpn"
			dialog --yesno "Save file to \"${OVPN}\"?" 6 40
			[ $? = 0 ] && echo "$SRV_INFO" | awk -F',' '{print $15}' | base64 -di >$OVPN
		fi
	fi
}

while true; do get_ovpn; done
