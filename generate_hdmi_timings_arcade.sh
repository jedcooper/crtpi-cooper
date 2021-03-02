#!/bin/bash
#
# v0.23
#
# ToDo:
# - traps, excepts etc.
# - support different MAME binaries for some version discrepancy esp. ROM naming :-( (WIP)
# - maybe selectable XML file (different MAME versions) via command line parameters?
# - make option for GTF or CVT timings
# - cache XML and timings 
# - modelinecmd and cut must get another approach
#
# Done (in testing):
# - select resolutions near the usual resolutions from array (validHRES, validYRES)
# - 31 kHz ROMs (Tapper, Popeye, etc.)
#
# Support different MAME binaries for some version discrepancy esp. ROM naming: 
#
# Generate an XML file via the MAME "Tab menu", f.e. for MAME 2003 plus:
# 01) Launch any game with lr-mame2003-plus emulator
# 02) Open up the "Tab menu" with Left Thumbstick or maybe Tab on your keyboard 
# 03) Select "Generate XML DAT", press Y/"North button" (XBox 360 Controller)
# 04) Find mame2003-plus.xml in ~/RetroPie/roms/arcade/mame2003-plus
#

#
# now we start...
#
version=0.23
timingslogfile=/tmp/$(basename $0).log
rm -f ${timingslogfile}

# be quiet if called from script (f.e. runcommand-onstart.sh)
if [[ $2 == "quiet" || $3 == "quiet" || $4 == "quiet" ]] ; then
    exec 1> ${timingslogfile}
fi

# create a config file?
if [[ $2 == "cfg" || $3 == "cfg" || $4 == "cfg" ]] ; then
    CREATECFG=true
else
    CREATECFG=false
fi

# don't use XML cache?
if [[ $2 == "refresh" || $3 == "refresh" || $4 == "refresh" ]] ; then
    REFRESHXML=true
else
    REFRESHXML=false
fi



# some information
echo -e "Usage: $0 <romname|romname.zip> <quiet> <cfg> <refresh>\n"
echo -e "quiet      be quiet (for call from runcommand-onstart.sh)"
echo -e "cfg        create or change .cfg file to calculated emulator resolution"
echo -e "\nGenerate HDMI Timings for Arcade systems\n========================================"
echo -e "\nVersion: ${version} - jedcooper"
# WIP for using general emulator XML file
echo -e "\nThis script needs the 'mame' and 'bc' package to work. Install via 'sudo apt install mame bc'."
echo -e "I also use the open source VESA GTF calculation program,\nget source code here: https://sourceforge.net/projects/gtf/"
echo -e "It compiles fine on RPi 3B+ RetroPie Buster with 'gcc gtf.c -o gtf -lm -Wall'."
echo -e "Put it in the same folder as this generation script or change location in this script.\n"

# some variables ^^
romname=$1
if [[ $romname == "" ]] ; then
    echo -e "No ROM name given! Bailing out..."
    exit 1
fi
rom=${romname%.*}
gtfpath=/opt/retropie/configs/all
gtfexec=${gtfpath}/gtf

# MAME and ROM XML files locations
mame2003plusXML="/home/pi/RetroPie/roms/arcade/mame2003-plus/mame2003-plus.xml"
romXML="/home/pi/RetroPie/roms/arcade/mame2003-plus/${rom}.xml"

# maybe change timingsfile to some sort of like 
# $rom.timings (gauntlet.timings) in ROM directory? or config directory?
#
timingsfile="/home/pi/RetroPie/roms/arcade/mame2003-plus/${rom}.timings"
rm -f ${timingsfile} 

# SuperResolution ranges
# Horizontal resolution range min/max
# common H res are: 1440, 1600, 1680, 1920, 2048
# common Y res are: 192, 200, 224, 240, 256, 288
#
rangeXMIN=1600
rangeXMAX=1920
# array of valid H res for scanline SuperResolutions
validHRES=(1600 1680 1920 2048)
# Vertical resolution range min/max
rangeYMIN=192
rangeYMAX=288
validYRES=(192 200 224 240 256 288)

# NormalResolution ranges
#
range_N_XMIN=640
range_N_XMAX=1280
valid_N_HRES=(640 720 800 1024 1152 1280)
range_N_YMIN=300
range_N_YMAX=1024
valid_N_YRES=(300 384 400 480 512 600 768 864 1024)
refresh_N_MIN=50
refresh_N_MAX=75

# generate XML file from mame2003-plus.xml
#
echo "Generating XML file for ${rom} ($(basename ${mame2003plusXML}))..."
if [ -f ${romXML} ] && [ $REFRESHXML = false ] ; then
    echo "Game ROM XML already exists. Using ${romXML}."
else
    echo -n "Game ROM XML not exists or needs updating. Creating/Refreshing."
    xmlstarlet sel -t -c "//game[@name=\"${rom}\"]" "${mame2003plusXML}" > ${romXML}
    if [ ! -f ${romXML} ] || [ ! -s ${romXML} ]  ; then
        echo -e "\nERROR! Invalid ROM name or ROM not found in MAME DB. Exiting...\n"
        exit 1
    fi
    echo "Done."
fi

# get the values from the <rom>.xml file
#
romclearname=$(xmlstarlet sel -t -v "//description" ${romXML})
refreshrate=$(xmlstarlet sel -t -v "//video/@refresh" ${romXML})
width=$(xmlstarlet sel -t -v "//video/@width" ${romXML})
height=$(xmlstarlet sel -t -v "//video/@height" ${romXML})
rotation=$(xmlstarlet sel -t -v "//video/@orientation" ${romXML})

# # old method for rotation in degrees
# if [ $rotation = 0 ] || [ $rotation = 180 ] ; then
    # rottext=horizontal
# else
    # rottext=vertical
    # echo -e "\nWARN: Rotation is vertical: ${rotation}°! Yet not thoroughly tested in this program and others in CRTPi-cooper repo.\n"
# fi

if [ $rotation == "vertical" ] ; then
    echo -e "\nWARN: Rotation is: ${rotation}! Yet not thoroughly tested in this program and others in CRTPi-cooper repo."
fi

# main
echo -e "\n*** Overview ***\n"
echo -e "ROM filename:      ${romname}"
echo -e "ROM name:          ${rom}"
echo -e "ROM clear name:    ${romclearname}"
echo -e "ROM width:         ${width}"
echo -e "ROM height:        ${height}"
echo -e "ROM refresh:       ${refreshrate}"
# echo -e "ROM rotation:      ${rottext} (${rotation}°)"
echo -e "ROM rotation:      ${rotation}"

# Resolution calculations
#
echo -e "\n*** Emulator and screenmode resolution values ***\n"

intfactorX=$(bc <<< ${rangeXMAX}/${width})
emuresX=$(bc <<< ${intfactorX}*${width})
intfactorY=$(bc <<< ${rangeYMAX}/${height})
emuresY=$(bc <<< ${intfactorY}*${height})

if [ $height -le $rangeYMAX ] ; then
    echo "SuperResolution mode."
    arrayHRES=${validHRES[*]}
    arrayYRES=${validYRES[*]}
    # Refresh rate for SuperResolution
    screenrefresh=$(bc <<< ${refreshrate}*2)
    # +1.5 for CVT because RetroArch measurement states refresh rate is too low?!?!?
    auxSR=$(bc <<< "scale=0; ($screenrefresh+1.5)/1")
    screenrefresh=$auxSR
else
    echo "NormalResolution mode."
    arrayHRES=${valid_N_HRES[*]}
    arrayYRES=${valid_N_YRES[*]}
    if [ ${refreshrate%.*} -lt 50 ] ; then
        screenrefresh=$(bc <<< ${refreshrate}*2)
    else
        screenrefresh=${refreshrate}
    fi
fi

echo ""

# Get optimal emulator and screen resolutions
#
prevoffset=10000
smallestoffset=10000
for HRES in ${arrayHRES[*]}; do
    echo -n "Testing HRES: $HRES "
    intX=$(bc <<< ${HRES}/${width})
    echo -n "Integer Factor: $intX "
    resX=$(bc <<< ${intX}*${width})
    echo -n "Emu Res X: $resX "
    offset=$(bc <<< ${HRES}-${resX})
    echo -n "Offset: $offset "
    if [ $offset -eq 0 ] ; then
        echo -n "   perfect match!"
    fi
    echo ""
    if [ $offset -le $prevoffset ] && [ $offset -le $smallestoffset ]; then
        emuresX=$resX
        intfactorX=$intX
        screenresX=$HRES
        echo "Emu Res X set to: $emuresX - Int Factor X set to: $intfactorX - Screen Res X set to: $screenresX"
        smallestoffset=$offset
    fi
    prevoffset=$offset
done

echo ""

prevoffset=10000
smallestoffset=10000
for YRES in ${arrayYRES[*]}; do
    echo -n "Testing YRES: $YRES "
    intY=$(bc <<< ${YRES}/${height})
    echo -n "Integer Factor: $intY "
    resY=$(bc <<< ${intY}*${height})
    echo -n "Emu Res Y: $resY "
    offset=$(bc <<< ${YRES}-${resY})
    echo -n "Offset: $offset "
    if [ $offset -eq 0 ] ; then
        echo -n "   perfect match!"
    fi
    echo ""
    if [ $offset -le $prevoffset ] && [ $offset -le $smallestoffset ]; then
        emuresY=$resY
        intfactorY=$intY
        screenresY=$YRES
        echo "Emu Res Y set to: $emuresY - Int Factor Y set to: $intfactorY - Screen Res Y set to: $screenresY"
        smallestoffset=$offset
    fi
    prevoffset=$offset
done

# Print summary
#
echo -e "\nInteger Factor X:      ${intfactorX}"
echo -e "Emulator Res X:        ${emuresX}"

if [[ ${intfactorY} -lt 1 ]] ; then
    echo -e "\nERR: Emulator resolution would have to be greater than defined maximum Y-Range!\nERR: This is on my ToDo list and yet to come in the future...\n\nExiting...\n"
    exit 1
fi

echo -e "Integer Factor Y:      ${intfactorY}"
echo -e "Emulator Res Y:        ${emuresY}"
echo -e "Screen Resolution X:   ${screenresX}"
echo -e "Screen Resolution Y:   ${screenresY}"
echo -e "Screen Refresh Rate:   ${screenrefresh}"

# some rotation "magic" ...
#
# a bit more intelligence needed than "just 2" :-)
#
if [ $rotation == "vertical" ] ; then
    rotintX=$(bc <<< ${intfactorX}-2)
    intfactorX=$rotintX
    emuresX=$(bc <<< ${width}*${rotintX})
    echo "Due to rotation ${rotation} Integer factor of X is reduced by two: ${intfactorX}, so new Emulator X Res is: ${emuresX}"    
fi

# modeline generation with GTF
# source: https://sourceforge.net/projects/gtf/
#
echo -e "\n*** vcgencmd hdmi_timings ***"

modelinecmd="${gtfexec} ${screenresX} ${screenresY} ${screenrefresh} -v"
#$modelinecmd

echo -e -n "\nGenerating modeline..."

# vcgencmd conform hdmi_timings
# source: https://www.raspberrypi.org/documentation/configuration/config-txt/video.md
#
# yeah DIRTY grep'n'cut, but works, so what? 
# BUT! Does it really work?
# see "# calculated by GTF" section with the if command...
# maybe other values are ALSO out of the cut range!
# so we need an alternative parsinge here urgently!
#
# also calling the program EVERYTIME is not good approach!
#

#
# GTF Calculation
#
h_active_pixels=${screenresX}
echo -n "."

if [[ $(${modelinecmd} | grep "Modeline" | cut -f18 -d " ") = "+HSync" ]] ; then
    h_sync_polarity=1
else 
    h_sync_polarity=0
fi
echo -n "."
h_front_porch=$(${modelinecmd} | grep "H FRONT PORCH" | cut -f15 -d " " | cut -f1 -d ".")
echo -n "."
h_sync_pulse=$(${modelinecmd} | grep "H SYNC" | cut -f20 -d " " | cut -f1 -d ".")
echo -n "."
# aux. variable to calculate H Back Porch (not sure if correct tho!)
h_blank=$(${modelinecmd} | grep "H BLANK" | cut -f19 -d " " | cut -f1 -d ".")
echo -n "."
h_back_porch=$(bc <<< $h_blank-$h_sync_pulse-$h_front_porch)
echo -n "."
v_active_lines=${screenresY}
echo -n "."
if [[ $(${modelinecmd} | grep "Modeline" | cut -f19 -d " ") = "+Vsync" ]] ; then
    v_sync_polarity=1
else 
    v_sync_polarity=0
fi
echo -n "."
v_front_porch=$(${modelinecmd} | grep "V ODD FRONT" | cut -f14 -d " " | cut -f1 -d ".")
echo -n "."
v_sync_pulse=$(${modelinecmd} | grep "V SYNC" | cut -f27 -d " " | cut -f1 -d ".")
echo -n "."
v_back_porch=$(${modelinecmd} | grep "V BACK" | cut -f25 -d " " | cut -f1 -d ".")
echo -n "."
v_sync_offset_a=0
v_sync_offset_b=0
pixel_rep=0
# frame rate has to be integer?! for sure, but rounded or cut?
#
# rounded
frame_rate_rnd=$(bc <<< "scale=0; ($screenrefresh+0.5)/1")
echo -n "."
# not rounded, scaled 2
frame_rate_s2=$(bc <<< "scale=2; $screenrefresh/1")
echo -n "."
# calculated by GTF
frame_rate_calc=$(${modelinecmd} | grep "V FRAME RATE" | cut -f23 -d " ")
if [[ $frame_rate_calc = "" ]] ; then
    frame_rate_calc=$(${modelinecmd} | grep "V FRAME RATE" | cut -f24 -d " ")
fi
echo -n "."
# so what now? I chose calculated rounded... yet. To see... 
frame_rate=$(bc <<< "scale=0; ($frame_rate_calc+0.5)/1")
echo -n "."
interlaced=0
# pixel freq in Hz
pixel_freq_mhz=$(${modelinecmd} | grep "Modeline" | cut -f6 -d " ") 
pixel_freq=$(bc <<< "scale=0; ($pixel_freq_mhz*1000000)/1")
echo "."
aspect_ratio=1

echo -e "\nh_active_pixels =  ${h_active_pixels}"
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
echo -e "frame_rate =       ${frame_rate}           rounded scr: ${frame_rate_rnd}  xxx.xx scr: ${frame_rate_s2}    calculated: ${frame_rate_calc}"
echo -e "interlaced =       ${interlaced}"
echo -e "pixel_freq =       ${pixel_freq}"
echo -e "aspect_ratio =     ${aspect_ratio}"

echo -e "\nFinal hdmi_timings command line:\nvcgencmd hdmi_timings ${h_active_pixels} ${h_sync_polarity} ${h_front_porch} ${h_sync_pulse} ${h_back_porch} ${v_active_lines} ${v_sync_polarity} ${v_front_porch} ${v_sync_pulse} ${v_back_porch} ${v_sync_offset_a} ${v_sync_offset_b} ${pixel_rep} ${frame_rate} ${interlaced} ${pixel_freq} ${aspect_ratio}"

echo -e "\nWriting timings to ${timingsfile}"

touch ${timingsfile}
#touch ${timingsfile}.cvt

echo "${h_active_pixels} ${h_sync_polarity} ${h_front_porch} ${h_sync_pulse} ${h_back_porch} ${v_active_lines} ${v_sync_polarity} ${v_front_porch} ${v_sync_pulse} ${v_back_porch} ${v_sync_offset_a} ${v_sync_offset_b} ${pixel_rep} ${frame_rate} ${interlaced} ${pixel_freq} ${aspect_ratio}" > ${timingsfile}

# create a cvt file for comparison
#vcgencmd hdmi_cvt ${screenresX} ${screenresY} ${screenrefresh} 1 0 0 0 > ${timingsfile}.cvt

# Creating .cfg file (if wanted)
if [ $CREATECFG = true ] ; then
    echo -e "\nCreating / changing .cfg file..."
    # .cfg file for emulator resolution
    romcfgfile="$HOME/RetroPie/roms/arcade/MAME 2003-Plus/${rom}.cfg"
    echo -e -n "\nROM cfg file: ${romcfgfile} and "
    if [ -f "$romcfgfile" ] ; then
        echo ".cfg file exists."
        echo "NO changes made to .cfg file (comes in future)"
    else 
        echo -n ".cfg file not exists. Creating..."
        echo "audio_max_timing_skew = \"0.100000\"" > "$romcfgfile"
        echo "custom_viewport_height = \"${emuresY}\"" >> "$romcfgfile"
        echo "custom_viewport_width = \"${emuresX}\"" >> "$romcfgfile"
        # Refresh rate is testing...
        echo "video_hard_sync = \"true\"" >> "$romcfgfile"
        echo "video_max_swapchain_images = \"2\"" >> "$romcfgfile"
        echo "video_refresh_rate = \"${refreshrate}\"" >> "$romcfgfile"
        echo "done."
    fi
else
    echo -e "\nNO .cfg file created or changed!"
fi

echo -e "\nALL Done."

exit 0