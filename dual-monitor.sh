#!/bin/sh
xrandr --output HDMI-2 --mode 2560x1440 --pos 0x0 --rotate left --output DP-1 --primary --mode 3840x2160 --pos 1440x0 --rotate normal --scale 1x1
feh --bg-fill ~/.screenlayout/bg.png --bg-fill ~/.screenlayout/bg.png
