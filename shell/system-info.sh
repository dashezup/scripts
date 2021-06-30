#!/bin/bash

get_kernel() {
	echo "kernel: $(</proc/version)"
}

get_rtc() {
	rtc_path="/sys/class/rtc/rtc0"
	echo "rtc: $(<${rtc_path}/date) $(<${rtc_path}/time)"
}

get_date() {
	printf "date: %(%F %T)T\\n" "-1"
}

get_uptime() {
	proc_uptime=$(</proc/uptime)
	local T=${proc_uptime%%.*}
        local D=$((T/60/60/24))
        local H=$((T/60/60%24))
        local M=$((T/60%60))
        local S=$((T%60))
	printf 'uptime: '
        [[ $D > 0 ]] && printf '%d days ' $D
        [[ $H > 0 ]] && printf '%02d:' $H
        [[ $M > 0 ]] && printf '%02d:' $M
        printf '%02d\n' $S
}

get_cmdline() {
	echo "cmdline: $(</proc/cmdline)"
}

_get_cpu_average() {
	grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage "%"}'
}

_get_cpu_current() {
	awk '{u=$2+$4; t=$2+$4+$5; if (NR==1){u1=u; t1=t;} else print "cpu (current): " ($2+$4-u1) * 100 / (t-t1) "%"; }' <(grep 'cpu ' /proc/stat) <(sleep 1;grep 'cpu ' /proc/stat)
}

get_cpu_average() {
	IFS=$'\n' read -r cpu_info <<<"$(</proc/stat)"
	read -r cpu user nice system idle iowait irq softirq steal guest guest_nice <<<"$cpu_info"
	echo "$(((user+system)*100/(user+system+idle)))%"
}

get_cpu_usage() {
	#cpu_usage=()
	while read cpu_info; do
		if [[ $cpu_info == cpu* ]]; then
			read -r cpu user nice system idle iowait irq softirq steal guest guest_nice <<<"$cpu_info"
			#cpu_usage+=("${cpu}: $(((user+system)*100/(user+system+idle)))%")
			echo "${cpu}: $(((user+system)*100/(user+system+idle)))%"
		else
			break
		fi
	done </proc/stat
	#echo "${cpu_usage[*]}"
}

get_mem_dirty() {
	read -r _ mem_dirty <<<"$(grep Dirty /proc/meminfo)"
	echo "Memory (Dirty): ${mem_dirty}"
}

get_kernel
get_rtc
get_date
get_uptime
get_cmdline
get_cpu_usage
get_mem_dirty
