#!/bin/sh

## $ crontab -l
## * * * * * ~/.local/bin/tg-noworg.sh -u
## 0 * * * * ~/.local/bin/tg-noworg.sh -d

: "${progname:="${0##*/}"}"

#CHAT_ID="" # private (message.from.id)
CHAT_ID="" # channel (channel_post.chat.id)
TG_BOT_TOKEN=""
tgbotapi="curl -s -F chat_id=$CHAT_ID https://api.telegram.org/bot${TG_BOT_TOKEN}"

NOWORG="$HOME/orgmode/now.org"
BASENAME=$(basename $NOWORG)
TEMP="/tmp/tg-noworg"
LAST_CHECKED="${TEMP}/last_checked.txt"
LOG="$HOME/tg-noworg/log.json"

if [ ! -d "$TEMP" ]; then
	mkdir $TEMP && cp $NOWORG $TEMP
	date -u +%s >$LAST_CHECKED
	echo "make directory: ${TEMP}"
	exit 0
fi

send_message() {
	${tgbotapi}/sendMessage -F parse_mode="MarkdownV2" --form-string text="$1" | sed -e 's/\(,"text":"\).*/\1"}}\n/' >>$LOG
}

modify_diff() {
	sed -e '
	# remove first two lines, empty address lines
	1,2d
	s/^@@ .*$//

	# remove lines which contains orgmode timestamps
	/\(SCHEDULED:\|CLOSED:\|:PROPERTIES:\|:LAST_REPEAT:\|:END:\|- State "DONE"       from "TODO"\)/d

	# escape for MarkdownV2
	s/\\/\\\\/g
	s/\(_\|*\|\[\|\]\|(\|)\|~\|`\|>\|#\|+\|-\|=\||\|{\|}\|\.\|!\)/\\\1/g

	# headlines
	/^\(\\\-\|\\+\)\(\\\*\\\* \)/ {s/^\(\\\-\|\\+\)\(\\\*\\\* \)/\1*/; s/$/*/}
	/^\(\\-\|\\+\)\\\*\\\*\\\* / {s/^\(\\-\|\\+\)\(\\\*\\\*\\\*\) \(\|TODO\|DONE\)\(\| \)/\1*\\#\3* __*_/; s/$/_*__/}

	# plain lists
	/^\(\\\-\|\\+\)\(\|\s\+\)\(\\\-\|\\+\|[0-9]\\\.\|[0-9]\\)\) / {s/^\(\\\-\|\\+\)\(\|\s\+\)\(\\\-\|\\+\|[0-9]\\\.\|[0-9]\\)\)\(\| \)\(\|\\\[ \\\]\|\\\[X\\\]\|\\\[\\\-\\\]\)\(\| \)/\1`\2\3\4\5\6`_/; s/$/_/}
	s/\(\\\-\|\\+\)\(\s\+ \)/\1`\2`/

	# strikethrough for removed lines, remove ^+ for added lines
	s/^\\\-/~/; /^~/s/$/~/
	s/^\\+//
	'
}

update_modified() {
	lastcheck=$(cat $LAST_CHECKED)
	echo "lastcheck: $(date -u +%FT%TZ -d @${lastcheck})"
	lastmod=$(stat -c %Y $NOWORG)
	if [ "$lastmod" -gt "$lastcheck" ]; then
		TEXT=$(diff -u0 ${TEMP}/$BASENAME $NOWORG | modify_diff)
		send_message "$TEXT"
		cp $NOWORG ${TEMP}/$BASENAME
		date -u +%s >$LAST_CHECKED
		echo "update: $BASENAME"
	else
		echo "skip: $BASENAME"
	fi
}

purge_message() {
	sed -i '/^$/d' $LOG
	TIME_48H_AGO=$(date -u -d-48hours-5minute +%s)
	TIME_40H_AGO=$(date -u -d-40hours +%s)
	i=1
	while IFS= read -r json; do
		echo "########## Line $i"
		json=$(echo "$json" | sed 's/\(,"description":"\).*/\1"}/')
		OK=$(echo "$json" | jq .ok)
		if [ $OK = true ]; then
			MESSAGE_ID=$(echo "$json" | jq .result.message_id)
			CHAT_ID=$(echo "$json" | jq .result.chat.id)
			JSON_DATE=$(echo "$json" | jq .result.date)
			FORMATTED_DATE=$(date -u +%FT%TZ -d@${JSON_DATE})
			DURATION=$(ddiff -i'%s' -f'%H hours %M minutes ago' $JSON_DATE $(date +%s))
			[ $JSON_DATE -lt $TIME_48H_AGO ] && echo "$FORMATTED_DATE ($DURATION) -- CANT BE DELETED"
			[ $JSON_DATE -gt $TIME_40H_AGO ] && echo "$FORMATTED_DATE ($DURATION) -- RESERVED"
			if [ $JSON_DATE -ge $TIME_48H_AGO ] && [ $JSON_DATE -le $TIME_40H_AGO ]; then
				echo "$FORMATTED_DATE ($DURATION) -- WILL BE DELETED"
				$tgbotapi/deleteMessage -F message_id=$MESSAGE_ID | sed 's/$/\n/'
				sed -i "${i}s/^.*$//" $LOG
				sleep 1
			fi
		else
			ERROR_CODE=$(echo "$json" | jq .error_code)
			echo "Contains ERROR CODE: $ERROR_CODE"
		fi
		i=$(( i + 1 ))
		echo
	done <$LOG
}

usage() {
	cat <<_EOF
Usage: $progname -u    Update modified content to Telegram channel
       $progname -d    Purge messages which sent between 40 and 48 hours ago
_EOF
	exit 1
}

case "$1" in
	-u) update_modified ;;
	-d) purge_message ;;
	*) usage ;;
esac
exit 0
