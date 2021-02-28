#!/bin/bash
#
# v0.07
#
# ToDo:
# - select resolutions near the usual resolutions from array (validHRES, validYRES)
# - return values for to be called from another script e.g. runcommand-onstart.sh
# - 31 kHz ROMs (Tapper, Popeye, etc.)
#
version=0.07

# some information
echo -e "Usage: $0 <romname|romname.zip>"
echo -e "\nGenerate HDMI Timings for Arcade systems\n========================================\n\nVersion: ${version} - jedcooper\n\nThis script needs the 'mame' and 'bc' package to work. Install via 'sudo apt install mame bc'.\nI also use the open source VESA GTF calculation program,\nget source code here: https://sourceforge.net/projects/gtf/ \nIt compiles fine on RPi 3B+ RetroPie Buster with 'gcc gtf.c -o gtf -lm -Wall'.\nPut it in the same folder as this generation script or change location in this script.\n"

# some variables ^^
romname=$1
if [[ $romname == "" ]] ; then
    echo -e "No ROM name given! Bailing out..."
    exit
fi
rom=${romname%.*}
gtfpath=/opt/retropie/configs/all
gtfexec=${gtfpath}/gtf

# SuperResolution ranges
# Horizontal resolution range min/max
# common H res are: 1440, 1600, 1680, 1920, 2048
# common Y res are: 192, 200, 224, 240, 256, 288
#
rangeXMIN=1600
rangeXMAX=2048
# array of valid H res for scanline SuperResolutions
validHRES=(1600 1680 1920 2048)

# Vertical resolution range min/max
rangeYMIN=192
rangeYMAX=288
validYRES=(192 200 224 240 256 288)

# generate XML file from ROM
mame ${rom} -listxml > /tmp/${rom}.xml
echo -n "Generating XML file for ${rom}..."
echo "done."

echo -e "\n*** Overview ***\n"
echo -e "ROM filename:      ${romname}"
echo -e "ROM name:          ${rom}"

# get the values from the .xml file
romclearname=$(xmlstarlet sel -t -v 'mame/machine/description' /tmp/${rom}.xml | head -n 1)
refreshrate=$(xmlstarlet sel -t -v '/mame/machine/display/@refresh' /tmp/${rom}.xml)
width=$(xmlstarlet sel -t -v '/mame/machine/display/@width' /tmp/${rom}.xml)
height=$(xmlstarlet sel -t -v '/mame/machine/display/@height' /tmp/${rom}.xml)

echo -e "ROM clear name:    ${romclearname}"
echo -e "ROM width:         ${width}"
echo -e "ROM height:        ${height}"
echo -e "ROM refresh:       ${refreshrate}"

rm /tmp/${rom}.xml

# simple calculations yet w/o intelligent range usage
# as where would 2.016 Integer resolution be next to a valid H res
# to 2.048 (ofc!) or 1.920 etc.?

echo -e "\n*** Emulator resolution values ***\n"

intfactorX=$(bc <<< ${rangeXMAX}/${width})
emuresX=$(bc <<< ${intfactorX}*${width})
echo -e "Integer Factor X:      ${intfactorX}"
echo -e "Emulator Res X:        ${emuresX}"

intfactorY=$(bc <<< ${rangeYMAX}/${height})
emuresY=$(bc <<< ${intfactorY}*${height})
if [[ ${intfactorY} -lt 1 ]] ; then
    echo -e "\nERR: Emulator resolution would have to be greater than defined maximum Y-Range!\nERR: This is on my ToDo list and yet to come in the future...\n\nExiting...\n"
    exit
fi
echo -e "Integer Factor Y:      ${intfactorY}"
echo -e "Emulator Res Y:        ${emuresY}"

# choose screen resolution Y
# this has to be transformed into more intelligent mode with arrays
#

if [[ ${emuresY} -gt 240 ]] ; then
    screenresY=288
elif [[ ${emuresY} -gt 224 ]] ; then
    screenresY=240
elif [[ ${emuresY} -gt 200 ]] ; then
    screenresY=224
elif [[ ${emuresY} -gt 192 ]] ; then
    screenresY=200
else
    screenresY=192
fi

# choose screen resolution X
# same as above, more intelligent mode with arrays needed
#
screenresX=2048

# Refresh rate for SuperResolution
screenrefresh=$(bc <<< $refreshrate*2)
echo -e "\n*** Chosen screenmode ***\n"
echo -e "Screen Resolution X:   ${screenresX}"
echo -e "Screen Resolution Y:   ${screenresY}"
echo -e "Screen Refresh Rate:   ${screenrefresh}"

# modeline generation with GTF
# source: https://sourceforge.net/projects/gtf/
#
echo -e "\n*** vcgencmd hdmi_timings ***"
echo -e "\nGenerating modeline...\n"

modelinecmd="${gtfexec} ${screenresX} ${screenresY} ${screenrefresh} -v"

# vcgencmd conform hdmi_timings
# source: https://www.raspberrypi.org/documentation/configuration/config-txt/video.md
#
h_active_pixels=${screenresX}
if [[ $(${modelinecmd} | grep "Modeline" | cut -f18 -d " ") = "+HSync" ]] ; then
    h_sync_polarity=1
else 
    h_sync_polarity=0
fi
# yeah DIRTY grep'n'cut, but works, so what?
h_front_porch=$(${modelinecmd} | grep "H FRONT PORCH" | cut -f15 -d " " | cut -f1 -d ".")
h_sync_pulse=$(${modelinecmd} | grep "H SYNC" | cut -f20 -d " " | cut -f1 -d ".")
# aux. variable to calculate H Back Porch (not sure if correct tho!)
h_blank=$(${modelinecmd} | grep "H BLANK" | cut -f19 -d " " | cut -f1 -d ".")
h_back_porch=$(bc <<< $h_blank-$h_sync_pulse-$h_front_porch)
v_active_lines=${screenresY}
if [[ $(${modelinecmd} | grep "Modeline" | cut -f19 -d " ") = "+Vsync" ]] ; then
    v_sync_polarity=1
else 
    v_sync_polarity=0
fi
v_front_porch=$(${modelinecmd} | grep "V ODD FRONT" | cut -f14 -d " " | cut -f1 -d ".")
v_sync_pulse=$(${modelinecmd} | grep "V SYNC" | cut -f27 -d " " | cut -f1 -d ".")
v_back_porch=$(${modelinecmd} | grep "V BACK" | cut -f25 -d " " | cut -f1 -d ".")
v_sync_offset_a=0
v_sync_offset_b=0
pixel_rep=0
# frame rate has to be integer?! for sure, but rounded or cut?
#
# rounded
frame_rate_rnd=$(bc <<< "scale=0; ($screenrefresh+0.5)/1")
# not rounded, scaled 2
frame_rate_s2=$(bc <<< "scale=2; $screenrefresh/1")
# calculated by GTF
frame_rate_calc=$(${modelinecmd} | grep "V FRAME RATE" | cut -f23 -d " ")
# so what now? I chose calculated rounded... yet. To see...
frame_rate=$(bc <<< "scale=0; ($frame_rate_calc+0.5)/1")
interlaced=0
# pixel freq in Hz
pixel_freq_mhz=$(${modelinecmd} | grep "Modeline" | cut -f6 -d " ") 
pixel_freq=$(bc <<< "scale=0; ($pixel_freq_mhz*1000000)/1")
aspect_ratio=1

echo -e "h_active_pixels =  ${h_active_pixels}"
echo -e "h_sync_polarity =  ${h_sync_polarity}"
echo -e "h_front_porch =    ${h_front_porch}"
echo -e "h_sync_pulse =     ${h_sync_pulse}"
echo -e "h_back_porch =     ${h_back_porch}"
echo -e "v_active_lines =   ${v_active_lines}"
echo -e "v_sync_polarity =  ${v_sync_polarity}"
echo -e "v_front_porch =    ${v_front_porch}"
echo -e "v_sync_pulse =     ${v_sync_pulse}"
echo -e "v_back_porch =     ${v_back_porch}"
echo -e "v_sync_offset_a =  ${v_sync_offset_a}"
echo -e "v_sync_offset_b =  ${v_sync_offset_b}"
echo -e "pixel_rep =        ${pixel_rep}"
echo -e "frame_rate =       ${frame_rate}           rounded scr: ${frame_rate_rnd}  scale2 scr: ${frame_rate_s2}    calculated: ${frame_rate_calc}"
echo -e "interlaced =       ${interlaced}"
echo -e "pixel_freq =       ${pixel_freq}"
echo -e "aspect_ratio =     ${aspect_ratio}"

echo -e "\nFinal hdmi_timings command line:\nvcgencmd hdmi_timings ${h_active_pixels} ${h_sync_polarity} ${h_front_porch} ${h_sync_pulse} ${h_back_porch} ${v_active_lines} ${v_sync_polarity} ${v_front_porch} ${v_sync_pulse} ${v_back_porch} ${v_sync_offset_a} ${v_sync_offset_b} ${pixel_rep} ${frame_rate} ${interlaced} ${pixel_freq} ${aspect_ratio}"

echo -e "\nALL Done."
