## when exiting an emulator -- revert to 640x480@65
#vcgencmd hdmi_timings 640 1 56 56 80 480 0 1 3 25 0 0 0 65 0 36000000 1  > /dev/null #VGA666 640x480p@65hz Timing

vcgencmd hdmi_cvt 1280 960 60 1 0 0 0 > /dev/null
tvservice -e "DMT 87" > /dev/null
sleep 1 > /dev/null

#fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 640 -yres 480 > /dev/null #24b Depth

fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 1280 -yres 960 > /dev/null #24b Depth
tvservice -s > /dev/null

###
