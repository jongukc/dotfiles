#!/bin/sh

session=$*
[ -n "$session" ] || exit 0

env_out=$(systemctl --user show-environment 2>/dev/null) || exit 0

for var in WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP \
	XDG_SESSION_DESKTOP GDK_BACKEND SDL_VIDEODRIVER CLUTTER_BACKEND; do
	case $(tmux show-environment -t "$session" "$var" 2>/dev/null) in
	-*) ;;
	*) continue ;;
	esac

	value=$(printf '%s\n' "$env_out" | sed -n "s/^$var=//p")
	[ -n "$value" ] || continue
	case $value in "'"* | '"'* | '$'*) continue ;; esac

	tmux set-environment -t "$session" "$var" "$value"
done
