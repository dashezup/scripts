#!/bin/sh

# xlsfonts | grep terminus-bold | grep iso10646
FONT="-xos4-terminus-bold-r-normal--16-160-72-72-c-80-iso10646-1"

get_time() { date -u +%FT%TZ ; }

get_workspace() {
	# current workspace
	CURRENT_WS=$(xprop -root _NET_CURRENT_DESKTOP | sed -e 's/.* = //')
	# window name
	CURRENT_WINDOW_ID=$(xprop -root _NET_ACTIVE_WINDOW | sed 's/.* window id # //')
	[ "$CURRENT_WINDOW_ID" != "0x0" ] && CURRENT_WINDOW_NAME=$(xprop -id "$CURRENT_WINDOW_ID)" WM_NAME | sed 's/.* = "\(.*\)"/\1/')
	# all workspaces
	CLIENT_LIST=$(xprop -root _NET_CLIENT_LIST | sed 's/.*: window id # //; s/, / /g')
	WS=$(for id in $CLIENT_LIST; do
		xprop -id "$id" _NET_WM_DESKTOP | sed 's/.* = //;'
	done | sort -hu | sed "s/^/ /; s/$/ /; s/ $CURRENT_WS /%{F#3498db}[$CURRENT_WS]%{F-}%{B-}/" | tr -d '\n')
	echo "$WS" | grep $CURRENT_WS >/dev/null 2>&1
	[ "$?" -ne 0 ] && WS="$WS($CURRENT_WS)"
	echo "$WS -  %{F#ecf0f1}$CURRENT_WINDOW_NAME%{B-}"

}

get_kbd() { xprop -root _XKB_RULES_NAMES | awk -F\" '{print $6, "("$8")" }' ; }

get_tray() {
	CLIENT_LIST=$(xprop -root _NET_CLIENT_LIST | sed 's/.*: window id # //; s/, / /g')
	for id in $CLIENT_LIST; do
		xprop -id "$id" _NET_WM_STATE | grep '^_NET_WM_STATE(_NET_WM_STATE) = 0x3,' >/dev/null
		if [ "$?" -eq 0 ]; then
			local CLASS=$([ "$?" -eq 0 ] && xprop -id "$id" WM_CLASS | cut -d\" -f4)
			if [ -z "$CLASS" ]; then local NAME=$id; else local NAME=$CLASS; fi
			echo "%{A:xdotool windowactivate $id windowraise $id:}($NAME)%{A}"
		fi
	done | paste -s -d' '
}

#hidden -c xargs 9menu -popup -label Iconics -font "$FONT" #-geometry '0x0+1440+1020'
# 1440x22+0+0
# 1430x24+5+5
# 1080x27+1440+0
showbar() {
	while true; do
		echo " $(get_workspace) %{r}$(get_tray) %{F#b2babb}%{B#212f3d} $(get_kbd) $(get_time) %{F-}%{B-}"
		sleep 0.2
	done | lemonbar -p -f "$FONT" -g '1430x24+5+5' -n 'leftbar' -B '#1c2833' -F '#eeeeee' | sh
}

showbar
