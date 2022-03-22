#!/bin/sh

## $ crontab -l
## @reboot sleep 60 && ~/.local/bin/webdav-curl-sync.sh -d
## 0 */3 * * * ~/.local/bin/webdav-curl-sync.sh -d

LAST_UPLOADED=""
: "${progname:="${0##*/}"}"

preview() {
	curl -s https://user:password@domain.tld:port/orgmode.org
}

download() {
	for orgmode in file1 file2; do
		#HTTPS_PROXY="socks5h://127.0.0.1:1080"
		filename="${orgmode}.org"
		file="$HOME/orgmode/$filename"
		uri="https://user:password@domain.tld:port/${orgmode}.org"
		if test -e "$file"; then
			zflag="-z $file"
		else
			zflag=
		fi
		HTTP_CODE=$(curl -sR --write-out %{http_code} -o "$file" $zflag "$uri")
		LAST_MODIFIED=$(date -r $file -u '+%F %T')
		echo -n 'Download: '
		case "$HTTP_CODE" in
			304) echo "$LAST_MODIFIED $filename (bypassed)";;
			200) echo "$LAST_MODIFIED $filename (update)";;
			000) echo "$filename (failed)";;
		*) echo "$filename ($HTTP_CODE)";;
		esac
	done
}

upload() {
	dir="$HOME/orgmode"
	uri="https://user:password@domain.tld:port/orgmode"
	for orgmode in $dir/*.org; do
		filename=$(basename $orgmode)
		filemod=$(stat -c %Y $orgmode)
		if [ "$filemod" -gt "$LAST_UPLOADED" ]; then
			HTTP_CODE=$(curl -s -o /dev/null --write-out %{http_code} -T "$orgmode" "$uri/$filename")
			if [ "$HTTP_CODE" = "201" ]; then
				echo "UPLOAD:   $filename"
				sed -i "s/^LAST_UPLOADED=.*$/LAST_UPLOADED=\"$(date +%s)\"/" $(realpath $0)
			else
				echo "UPLOAD:   $filename (failed)"
			fi
		else
			echo "UPLOAD:   $filename (bypassed)"
		fi
	done
}

usage() {
	echo "Usage: $progname -p|-u|-d|-a"
}

case "$1" in
	-p) preview ;;
	-u) upload ;;
	-d) download ;;
	-a) download; upload ;;
	*) usage ;;
esac
exit 0
