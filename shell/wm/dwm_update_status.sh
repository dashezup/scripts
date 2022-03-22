#!/bin/bash

### Constants
PROC_UPTIME='/proc/uptime'
PROC_STAT='/proc/stat'
PROC_MEMINFO='/proc/meminfo'
#SYS_BAT_CAPACITY='/sys/class/power_supply/sbs-20-000b/capacity'
#SYS_BAT_STATUS='/sys/class/power_supply/sbs-20-000b/status'
#SYS_BAT_2EMPTY='/sys/class/power_supply/sbs-20-000b/time_to_empty_avg'
#SYS_BAT_2FULL='/sys/class/power_supply/sbs-20-000b/time_to_full_avg'
SYS_BRIGHTNESS='/sys/class/backlight/backlight/brightness'
SYS_MAX_BRIGHTNESS='/sys/class/backlight/backlight/max_brightness'
SYS_TEMPERATURE='/sys/class/thermal/thermal_zone3/temp'
PROC_WIRELESS='/proc/net/wireless'
#PROC_DPMS='/sys/devices/platform/display-subsystem/drm/card0/card0-eDP-1/dpms'
PROC_DPMS='/sys/devices/pci0000:00/0000:00:02.0/drm/card0/card0-HDMI-A-1/dpms'
PREV_TOTAL=0
PREV_IDLE=0

### Functions
function sec2time () {
        local T=$1
        local D=$((T/60/60/24))
        local H=$((T/60/60%24))
        local M=$((T/60%60))
        local S=$((T%60))
        #[[ $D > 0 ]] && printf '%d days ' $D
        #[[ $H > 0 ]] && printf '%d hours ' $H
        #[[ $M > 0 ]] && printf '%d minutes ' $M
        #![[ $D > 0 || $H > 0 || $M > 0 ]] && printf 'and '
        #printf '%d second\n' $S

        [[ $D > 0 ]] && printf '%d days ' $D
        [[ $H > 0 ]] && printf '%02d:' $H
        [[ $M > 0 ]] && printf '%02d:' $M
        #[[ $D > 0 || $H > 0 || $M > 0 ]] && printf 'and '
        #printf '%d second\n' $S
        printf '%02d\n' $S
}
function get-date () {
	printf " $(date +'%F  %T')"
}
function get-uptime () {
	printf " [$(sec2time $(cat $PROC_UPTIME | cut -d'.' -f1))]"
}
#function get-kbd () {
	#printf " $(setxkbmap -query | grep variant | colrm 1 12)"
#}
function get-cpu-average () {
	printf " $(grep 'cpu ' $PROC_STAT | awk '{usage=(1000*($2+$4)/($2+$4+$5)+5)/10} END {print int(usage) "%%"}')"
}
function get-cpu-current () {
	# Get the total CPU statistics, discarding the 'cpu ' prefix.
	#CPU=(`sed -n 's/^cpu\s//p' /proc/stat`)
	CPU=(`grep -oP '(?<=cpu ).*' $PROC_STAT`)
	IDLE=${CPU[3]} # Just the idle CPU time.
	# Calculate the total CPU time.
	TOTAL=0
	for VALUE in "${CPU[@]}"; do
	let "TOTAL=$TOTAL+$VALUE"
	done
	# Calculate the CPU usage since we last checked.
	let "DIFF_IDLE=$IDLE-$PREV_IDLE"
	let "DIFF_TOTAL=$TOTAL-$PREV_TOTAL"
	let "DIFF_USAGE=(100000*($DIFF_TOTAL-$DIFF_IDLE)/$DIFF_TOTAL+5)/10"
	#printf "%0.2f%%\\n" "${DIFF_USAGE}e-2"
	# Remember the total and idle CPU times for the next check.
	PREV_TOTAL="$TOTAL"
	PREV_IDLE="$IDLE"

	printf "%0.2f%%" "${DIFF_USAGE}e-2"
}
function get-ram () {
	while IFS=":" read -r a b; do
		case "$a" in
	"MemTotal") mem_used="$((mem_used+=${b/kB}))"; mem_total="${b/kB}" ;;
	"Shmem") mem_used="$((mem_used+=${b/kB}))"  ;;
	"MemFree" | "Buffers" | "Cached" | "SReclaimable")
	mem_used="$((mem_used-=${b/kB}))"
	;;
	esac
	done < $PROC_MEMINFO
	mem_used="$((mem_used / 1024))"
	mem_total="$((mem_total / 1024))"
	memory="${mem_used}${mem_label:-MiB} / ${mem_total}${mem_label:-MiB}"
	#printf " $(bc <<<"scale=1;$mem_used/$mem_total*100" | sed -e 's/^\./0./')%%"
	let "mem_usage=(100000*$mem_used/$mem_total+5)/10"
	printf " %0.2f%%" "${mem_usage}e-2"
}
function get-storage () {
	printf " $(df / | grep -v '^Filesystem' | awk '{ print $5 }')%"
}
function get-battery () {
	BAT_PERCENT="$(<$SYS_BAT_CAPACITY)%%"

	if [[ $(<$SYS_BAT_STATUS) == Discharging ]]; then
		printf " $BAT_PERCENT [$(sec2time $(<$SYS_BAT_2EMPTY))]"
	elif [[ $(<$SYS_BAT_STATUS) == Charging ]]; then
		printf " $BAT_PERCENT $(sec2time $(<$SYS_BAT_2FULL))"
	elif [[ $(<$SYS_BAT_STATUS) == Full ]]; then
		printf "$BAT_PERCENT Full"
	else
		printf '[?]'
	fi
}
function get-brightness () {
	printf " $(( $(<$SYS_BRIGHTNESS)*100/$(<$SYS_MAX_BRIGHTNESS) ))%%"
}
function get-temperature () {
	#printf "  $(sensors | grep temp1 | awk '{print $2}' | sed 's/+//')"
	printf " %.1f°C" "$(<$SYS_TEMPERATURE)e-3"
}
function get-ip () {
	printf " $(ip route get 1 2>&1 | awk '{print $7}')"
}
function get-wifi () {
	if [[ $(grep wlan0 $PROC_WIRELESS) ]]; then
		printf " $(grep wlan0 $PROC_WIRELESS | awk '{ print int($3 * 100 / 70) }')%%"
	else
		echo -n ' [?]'
	fi
}
function update-status () {
        #xsetroot -name " $info_date $info_uptime $info_kbd $info_cpu_average $info_cpu_current $info_ram $info_storage $info_battery $info_brightness $info_temperature $info_ip $info_wifi "
        #xsetroot -name " $info_date $info_uptime  $info_cpu_average $info_cpu_current $info_ram $info_storage  $info_battery $info_brightness $info_temperature  $info_ip $info_wifi "
        #echo " $info_date $info_uptime  $info_cpu_average $info_cpu_current $info_ram $info_storage  $info_battery $info_brightness $info_temperature  $info_ip $info_wifi "
	xsetroot -name " $info_date $info_uptime  $info_cpu_average $info_cpu_current $info_ram $info_storage $info_ip"

}

### start from here
info_date=$(get-date)
info_uptime=$(get-uptime)
#info_kbd=$(get-kbd)
info_cpu_average=$(get-cpu-average)
info_cpu_current=$(get-cpu-current)
info_ram=$(get-ram)
info_storage=$(get-storage)
#info_battery=$(get-battery)
#info_brightness=$(get-brightness)
#info_temperature=$(get-temperature)
info_ip=$(get-ip)
info_wifi=$(get-wifi)
update-status
sec=0
while true; do
	if [[ $(<$PROC_DPMS) == On ]]
	then
		# run commands when it's on
		#echo On $(get-uptime) && sleep 1
		if [ "$(($sec % 4))" == "0" ]; then
			#echo "$(date +%M:%S) 2"
			info_date=$(get-date)
			info_uptime=$(get-uptime)
			info_cpu_current=$(get-cpu-current)
			info_ram=$(get-ram)
			info_storage=$(get-storage)
			#info_battery=$(get-battery)
			#info_brightness=$(get-brightness)
			#info_temperature=$(get-temperature)
			#info_wifi=$(get-wifi)
			update-status
		fi

		if [ "$(($sec % 40))" == "0" ]; then
			info_cpu_average=$(get-cpu-average)
			info_ip=$(get-ip)
			update-status
			
		fi

		#if [ "$(($sec % 32))" == "0" ]; then
			#info_kbd=$(get-kbd)
			#update-status
		#fi

		sleep 2;
		sec=$(( $sec + 2 ))
	else
		echo Off
		sleep 4
	fi
done
