#!/bin/sh

PKG_PATH="current/glibc-2.32_2.x86_64.xbps"
SPEED_LIMIT="1048576"
# https://docs.voidlinux.org/xbps/repositories/mirrors/index.html
MIRRORLIST="\
https://alpha.de.repo.voidlinux.org/			T1 EU: Finland
https://mirrors.servercentral.com/voidlinux/		T1 USA: Chicago
https://alpha.us.repo.voidlinux.org/			T1 USA: Kansas City
https://mirror.ps.kz/voidlinux/				T2 Asia: Almaty, KZ
https://mirrors.bfsu.edu.cn/voidlinux/			T2 Asia: China
https://mirrors.cnnic.cn/voidlinux/			T2 Asia: China
https://mirrors.tuna.tsinghua.edu.cn/voidlinux/		T2 Asia: China
https://mirror.sjtu.edu.cn/voidlinux/			T2 Asia: China
https://mirror.maakpain.kro.kr/void/			T2 Asia: Seoul, SK
https://void.webconverger.org/				T2 Asia: Singapore
https://mirror.aarnet.edu.au/pub/voidlinux/		T2 AU: Canberra
https://ftp.swin.edu.au/voidlinux/			T2 AU: Melbourne
https://void.cijber.net/				T2 EU: Amsterdam, NL
https://mirror.easylee.nl/voidlinux/			T2 EU: Amsterdam, NL
http://ftp.dk.xemacs.org/voidlinux/			T2 EU: Denmark
https://mirrors.dotsrc.org/voidlinux/			T2 EU: Denmark
https://quantum-mirror.hu/mirrors/pub/voidlinux/	T2 EU: Hungary
https://voidlinux.qontinuum.space:4443/			T2 EU: Monaco
http://ftp.debian.ru/mirrors/voidlinux/			T2 EU: Russia
https://mirror.yandex.ru/mirrors/voidlinux/		T2 EU: Russia
https://cdimage.debian.org/mirror/voidlinux/		T2 EU: Sweden
https://ftp.acc.umu.se/mirror/voidlinux/		T2 EU: Sweden
https://ftp.lysator.liu.se/pub/voidlinux/		T2 EU: Sweden
https://ftp.sunet.se/mirror/voidlinux/			T2 EU: Sweden
https://mirror.clarkson.edu/voidlinux/			T2 USA: New York"

show_usage() {
	: "${progname:="${0##*/}"}"
	cat <<_EOF | GREP_COLORS='ms=1' egrep --color "$progname|$"
Usage: $progname                    show usage info
       $progname -w [file.csv]      save speedtest results to file
       $progname -r file.csv        format speedtest results from file
       $progname -f file.csv        format speedtest results from file and pass to fzf

pkg path: ${PKG_PATH}
speed limit: $(echo $SPEED_LIMIT | numfmt --to=iec-i --suffix=B/s)
mirrors for testing: $(echo "$MIRRORLIST" | wc -l)
_EOF
}

format_speedtest_results() {
	cat "$1" | sort -t, -nrk4 | while IFS=, read url info time_appconnect download_speed; do
		f_time=$(printf "%.2fs" $time_appconnect)
		f_speed=$(echo $download_speed | numfmt --to=iec-i --suffix=B/s)
		echo "${url},${info},${f_time},${f_speed}"
	done | column -s, -t
}

time_appconnect() {
	curl --connect-timeout 2 -o/dev/null -sw '%{time_appconnect}' -I $1
}

download_speed() {
	curl -Y $SPEED_LIMIT --progress-bar $1 -o/dev/null --write-out "%{speed_download}"
}

mirror_speedtest() {
	count=1
	echo "$MIRRORLIST" | while read -r mirror etc; do
		pkg_url="${mirror}${PKG_PATH}"
		info=$(echo $etc | sed 's/,//g')
		>&2 echo "${count}. $pkg_url"
		echo "${mirror},${info},$(time_appconnect $pkg_url),$(download_speed $pkg_url)"
		>&2 echo
		count=$((count + 1))
	done
}

case $1 in
	-r) format_speedtest_results $2;;
	-f) format_speedtest_results $2 | fzf +s;;
	-w) [ -z $2 ] && { mirror_speedtest; exit 0; } || { mirror_speedtest >"$2"; exit 0; };;
	*) show_usage;;
esac
exit 0
