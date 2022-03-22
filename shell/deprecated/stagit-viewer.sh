#!/bin/sh

which fzf bat curl >/dev/null || exit 0

view_raw_file() {
	echo "Fetching $(basename ${1})..."
	local HTML_RAW=$(curl --progress-bar "$1")
	echo "$HTML_RAW" \
		| sed -n 's|^<a href="#.*" class="line" id=".*">.*</a>||p' \
		| recode HTML_4.0..UTF-8 \
		| bat -n --paging=always
}

view_file() {
	local HTML_FILE=$(curl --progress-bar "$1")
	local LIST_FILE=$(echo "$HTML_FILE" | sed -n 's|^<tr><td>.*</td><td><a href=".*">\(.*\)</a></td><td class="num" align="right">.*</td></tr>$|\1|p')
	local HOMEPAGE=$(echo "$1" | sed 's/files.html$//')
	while true; do
		local FILE_PATH=$(echo "$LIST_FILE" | GREP_COLORS="sl=0;34;49:ms=0;37;49" grep --color=always '^\|[^/]*$' | fzf --ansi +s)
		[ -z "$FILE_PATH" ] && return 0
		view_raw_file ${HOMEPAGE}file/${FILE_PATH}.html
	done
}

view_raw_commit() {
	echo "Fetching $(basename ${1})..."
	local TEXT=$(links -dump "$1" | sed 's/^ //' | sed -n '/^commit .*$/,$p')
	echo "$TEXT" | bat -nl diff --paging=always
}

view_log() {
	local HOMEPAGE=$(echo "$1" | sed 's/log.html$//')
	local HTML_FILE=$(curl --progress-bar "$1")
	local LIST_LOG=$(echo "$HTML_FILE" | sed -n 's|^<tr><td>\(.*\)</td><td><a href="commit/\(.*\).html">\(.*\)</a></td><td>.*.*</td><td class="num" align="right">.*|\2  \1  \3|p')
	while true; do
		local COMMIT=$(echo "$LIST_LOG" | fzf +s | awk '{print $1}')
		[ -z "$COMMIT" ] && return 0
		view_raw_commit "${HOMEPAGE}commit/${COMMIT}.html"
	done
}

[ -z "$1" ] && { printf "URL: "; read -r URL; } || URL=$1

if	$(echo "$URL" | grep '^http.*/log.html$' >/dev/null);		then view_log "$URL"
elif	$(echo "$URL" | grep '^http.*/files.html$' >/dev/null);		then view_file "$URL"
elif	$(echo "$URL" | grep 'http.*/commit/.*.html$' >/dev/null);	then view_raw_commit "$URL"
elif	$(echo "$URL" | grep 'http.*/file/.*.html$' >/dev/null);	then view_raw_file "$URL"
else	echo "Invald URL"; return 0
fi
