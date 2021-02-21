#!/usr/bin/env bash
#=====================================================================================================================================
#title           :	runcommand-onstart.sh
#description     :	This script perform the following - #Mike Vencio
#					Determines if the game being run is a console or an arcade/fba
#					For arcades, it will dynamically determine the resolution based on MAME resolution.ini file
#					For consoles, hdmi_timings can be set based on emulator or system
#					Dynamically creates the game_name.zip.cfg file and sets the custom_viewport_height for MAME/FBA/NeoGeo
#					Dynamically add these parameters (video_allow_rotate = "true" and video_rotation = 1) for vertical games
#					vertical.txt contains all the mame 0.184 vertical games
#					Ability to set custom_viewport_width for MAME/FBA/NeoGeo
#					Fix arcade custom_viewport_width for 320x224 and 320x240 resolutions
#					Added amiga and C64 support
#	                Automatically set custom_viewport_y to center vertically (Removed on 0.7.1)
#					Added support for 480 height arcade games like tapper
#					Disable resolution change for non libretto cores
#					Added support for 448 height arcade games like popeye
#					Added support for 254 height arcade games like mk3
#					Arcade/FBA/Mame-Libretro/NeoGeo - Set custom_viewport_width to be rom_resolution_width closest to 1920
#					Removed text output when running scripts
#					Reverted hdmi_timings to previous version
#					Removed all logging
#					Default non supported non-lr emulators to 320x240
#					Default non supported non-lr emulators to 1600x240p - #CRTpi-Project
#					Added config-per core scripting to change between 2048x224p / 2048x240p / 2048x192p - #CRTPi-Project
#					Added config-per core scripting to change between 1920x224p / 1920x240p / 1920x200p / 1920x192p - #CRTPi-Project
#					Added per-game user scripting using heavily modified Sakitoshi tv-out script - #CRTPi-Project
#og. author		 :	Michael Vencio
#ad. author		 :  Sakitoshi
#revision		 :  CRTPi-Project v3.1
#rev. author     :  http://reddit.com/r/u_erantyint
#rev. date		 :  July10-2020
#notes           :	For advance users only and would need to be tweaked 
#					to cater to your needs and preference
#					resolution.ini (MAME 0.184) file needed http://www.progettosnaps.net/renameset/
#=====================================================================================================================================

#### jedcooper runcommand debug log ####
logdir=$HOME/runcmd_log
debugdt=$(date +%Y-%m-%d_%H-%M-%S)
#logfile=${logdir}/runcommand_PALNTSC_debug_${debugdt}.log
logfile=${logdir}/runcommand_PALNTSC_debug.log
mkdir -p ${logdir}
touch ${logfile}
curtime=$(cat /proc/uptime | cut -f1 -d " ")
echo -e "***\n*** START of logfile: ${curtime} - ${debugdt} - ${logfile} ***\n***" >> ${logfile}

# PAL variables
ISPAL=false
IS240p=false

# Emulator LUT
emulatorLUT="/opt/retropie/configs/all/emulator_lut.txt"

#### Michael Vencio ####

# get the system name
system=$1

# get the emulator name
emul=$2
emul_lr=${emul:0:2}

# get the full path filename of the ROM
rom_fp=$3
rom_bn=$3

# Game or Rom name
rom_bn="${rom_bn%.*}"
rom_bn="${rom_bn##*/}"

# why two times the same command line parsing? - jedcooper

# get the system name
system=$1

# get the emulator name
emul=$2
emul_lr=${emul:0:2}

# get the full path filename of the ROM
rom_fp=$3
rom_bn=$3

# Game or Rom name
rom_bn="${rom_bn%.*}"
rom_bn="${rom_bn##*/}"

#### Sakitoshi X CRTPi ####

#If Value found in 256.txt for Consoles
if [ -f "/opt/retropie/configs/$1/256.txt" ]; then 
	TwoFiveSix=$(tr -d "\r" < "/opt/retropie/configs/$1/256.txt" | sed -e 's/\[/\\\[/'); 
fi > /dev/null

#If Value found in 256.txt for Ports
if [ -f "/opt/retropie/configs/ports/$1/256.txt" ]; then 
	TwoFiveSix=$(tr -d "\r" < "/opt/retropie/configs/ports/$1/256.txt" | sed -e 's/\[/\\\[/'); 
fi > /dev/null

# If 256.txt is Empty
if [ ! -s "/opt/retropie/configs/$1/256.txt" ] && [ ! -s "/opt/retropie/configs/ports/$1/256.txt" ] || [ -z "$TwoFiveSix" ]; then 
	TwoFiveSix="empty"; 
fi > /dev/null

#If Value found in 320.txt for Consoles
if [ -f "/opt/retropie/configs/$1/320.txt" ]; then 
	ThreeTwenty=$(tr -d "\r" < "/opt/retropie/configs/$1/320.txt" | sed -e 's/\[/\\\[/'); 
fi > /dev/null

#If Value found in 320.txt for Ports
if [ -f "/opt/retropie/configs/ports/$1/320.txt" ]; then 
	ThreeTwenty=$(tr -d "\r" < "/opt/retropie/configs/ports/$1/320.txt" | sed -e 's/\[/\\\[/'); 
fi > /dev/null

# If 320.txt is Empty
if [ ! -s "/opt/retropie/configs/$1/320.txt" ] && [ ! -s "/opt/retropie/configs/ports/$1/320.txt" ] || [ -z "$ThreeTwenty" ]; 
	then ThreeTwenty="empty"; 
fi > /dev/null

##############################################################################
#### jedcooper's CRTPi PAL extension                                      ####
#### PAL extension for CRTPi Project, currently CRTPi-VGA                 ####
##############################################################################

#### PAL begin ####

#### *** CHANGE HERE TO ONLY PAL.txt, 320/256 horizontal handling is done in the if conditionals  *** ####

# PAL.txt for Consoles
if [ -f "/opt/retropie/configs/$1/PAL.txt" ]; then 
	PALGame=$(tr -d "\r" < "/opt/retropie/configs/$1/PAL.txt" | sed -e 's/\[/\\\[/');
	curtime=$(cat /proc/uptime | cut -f1 -d " ")
	echo -e "${curtime}: PAL.txt found!" >> $logfile
	# is game on list (or all) then set PAL = true 
	# Working: if { echo "$3" | grep -q -wi "$PALGame"; } then > /dev/null 
	if { echo "$3" | grep -q -wi "$PALGame" || echo "$PALGame" | grep -q -xi "all"; } then > /dev/null
		curtime=$(cat /proc/uptime | cut -f1 -d " ")
		ISPAL=true
		echo -e "${curtime}: Game is in PAL list! PAL mode set. ISPAL=${ISPAL}" >> $logfile
		# get filename w/o path
		romfile=$(basename -- "$3")
		# parse to LR Game-options filename
		optfilename=${romfile%.*}.opt
		# get the emulator config file folder from LUT
		optfolder=$(cat ${emulatorLUT} |grep ${emul} | cut -f2 -d ",")
		# .opt filename w/ path
		optfile=${optfolder}/${optfilename}
		# what directory are we working from?
		workdir=$(pwd)
		# get the key from LUT
		optkey=$(cat ${emulatorLUT} | grep ${emul} | cut -f3 -d ",")
		# get the desired PAL value from LUT
		optvalue=$(cat ${emulatorLUT} | grep ${emul} | cut -f4 -d ",")
		if [ ${optkey} != "" ] ; then
			curtime=$(cat /proc/uptime | cut -f1 -d " ")
			if [ -f "${optfile}" ] ; then > /dev/null
				curtime=$(cat /proc/uptime | cut -f1 -d " ")
				echo -e "${curtime}: OPT file: ${optfile} already exists." >> $logfile
				# fetch current value in OPT file
				currentval=$(grep "${optkey}" "${optfile}" | grep -o '".*"' | sed 's/"//g')
				echo -e "${curtime}: Current value in OPT file: ${currentval}" >> $logfile
				if [ ${currentval} != ${optvalue} ] ; then
					curtime=$(cat /proc/uptime | cut -f1 -d " ")
					echo -e "${curtime}: Changing OPT key: ${optkey} TO OPT value: ${optvalue}" >> $logfile
					# change the key to the PAL value in the option file
					sed -i "s/^\(${optkey} *= *\).*/\1\"${optvalue}\"/" "${optfile}"
				else
					curtime=$(cat /proc/uptime | cut -f1 -d " ")
					echo -e "${curtime}: NO change needed, value in OPT file already set for PAL." >> $logfile
				fi
			else
				curtime=$(cat /proc/uptime | cut -f1 -d " ")
				echo -e "${curtime}: NO OPT file available. Creating one..." >> $logfile
				# create key = "value" text
				optTOFILE=${optkey}' = ''"'${optvalue}'"'
				echo -e "${curtime}: Writing ${optTOFILE} to ${optfile}" >> $logfile
				# create file - mandatory?
				touch "${optfile}"
				# write key = "value" to file
				echo ${optTOFILE} > "${optfile}"
			fi
		else
			curtime=$(cat /proc/uptime | cut -f1 -d " ")
			echo -e "${curtime}: NO option in LUT file. Skipping OPT file creation." >> $logfile
		fi
		# Now for viewport change NTSC lines to (mostly more) PAL lines, 
		# f.e. 224 -> 240, IF the LUT contains the info :-)
		# AND if the game uses 240 lines actually!
		#
		# check if 240p needed - maybe rename to PALLines.txt, as there can be different lines in some cores
		if [ -f "/opt/retropie/configs/$1/240p.txt" ]; then
			x240pGame=$(tr -d "\r" < "/opt/retropie/configs/$1/240p.txt" | sed -e 's/\[/\\\[/');
			curtime=$(cat /proc/uptime | cut -f1 -d " ")
			echo -e "${curtime}: 240p.txt found!" >> $logfile
			if { echo "$3" | grep -q -wi "$x240pGame" || echo "$x240pGame" | grep -q -xi "all"; } then > /dev/null
				curtime=$(cat /proc/uptime | cut -f1 -d " ")
				IS240p=true
				echo -e "${curtime}: Game is in 240p list! 240p mode set. IS240p=${IS240p}" >> $logfile
				# fetch new key (viewport resolution)
				cfgkey=$(cat ${emulatorLUT} | grep ${emul} | cut -f5 -d ",")
				# fetch its value
				cfgvalue=$(cat ${emulatorLUT} | grep ${emul} | cut -f6 -d ",")
				# now we have a .cfg filename as override
				cfgfilename=${romfile%.*}.cfg
				# the .cfg file folder is fortunately the same as for the .opt file
				cfgfolder=$optfolder
				# .cfg filename w/ path
				cfgfile=${cfgfolder}/${cfgfilename}
				if [ ${cfgkey} != "" ] ; then
					curtime=$(cat /proc/uptime | cut -f1 -d " ")
					if [ -f "${cfgfile}" ] ; then
						curtime=$(cat /proc/uptime | cut -f1 -d " ")
						echo -e "${curtime}: CFG file: ${cfgfile} already exists." >> $logfile
						currentval=$(grep "${cfgkey}" "${cfgfile}" | grep -o '".*"' | sed 's/"//g')
						echo -e "${curtime}: Current value in CFG file: ${currentval}" >> $logfile
						if [ ${currentval} != ${cfgvalue} ] ; then
							curtime=$(cat /proc/uptime | cut -f1 -d " ")
							echo -e "${curtime}: Changing CFG key: ${cfgkey} TO CFG value: ${cfgvalue}" >> $logfile
							sed -i "s/^\(${cfgkey} *= *\).*/\1\"${cfgvalue}\"/" "${cfgfile}"
						else
							curtime=$(cat /proc/uptime | cut -f1 -d " ")
							echo -e "${curtime}: NO change needed, value in CFG file already set for 240p." >> $logfile
						fi
					else
						curtime=$(cat /proc/uptime | cut -f1 -d " ")
						echo -e "${curtime}: NO CFG file available. Creating one..." >> $logfile
						# create key = "value" text
						cfgTOFILE=${cfgkey}' = ''"'${cfgvalue}'"'
						echo -e "${curtime}: Writing ${cfgTOFILE} to ${cfgfile}" >> $logfile
						touch "${cfgfile}"
						echo ${cfgTOFILE} > "${cfgfile}"
					fi
				else
					curtime=$(cat /proc/uptime | cut -f1 -d " ")
					echo -e "${curtime}: NO option in LUT file. Skipping CFG file creation." >> $logfile
				fi
			else
				curtime=$(cat /proc/uptime | cut -f1 -d " ")
				echo -e "${curtime}: Game is NOT in 240p list! IS240p=${IS240p}" >> $logfile
			fi
		fi
	else
		curtime=$(cat /proc/uptime | cut -f1 -d " ")
		echo -e "${curtime}: Game is NOT in PAL list! NTSC mode set. ISPAL=${ISPAL}" >> $logfile
	fi > /dev/null
fi > /dev/null

# PAL.txt for Ports
# N/A yet, as I think there's no use (yet) 

# PAL.txt is empty
if [ ! -s "/opt/retropie/configs/$1/PAL.txt" ] && [ ! -s "/opt/retropie/configs/ports/$1/PAL.txt" ] || [ -z "$PALGame" ]; then 
	PALGame="empty"; 
	curtime=$(cat /proc/uptime | cut -f1 -d " ")
	echo -e "${curtime}: PAL.txt not found or empty, no PAL games configured for System: ${system}\n${curtime}: Variables: PALGame=${PALGame}, ISPAL=${ISPAL}" >> $logfile
fi > /dev/null

#### PAL end ####

#### Michael Vencio ####

# Determine if arcade or fba then determine resolution, set hdmi_timings else goto console section
if [[ "$system" == "arcade" ]] || [[ "$system" == "fba" ]] || [[ "$system" == "mame-libretro" ]] || [[ "$system" == "neogeo" ]] ; then
	# get the line number matching the rom
	rom_ln=$(tac /opt/retropie/configs/all/resolution.ini | grep -w -n $rom_bn | cut -f1 -d":")
	
	# get resolution of rom
	rom_resolution=$(tac /opt/retropie/configs/all/resolution.ini | sed -n "$rom_ln,$ p" | grep -m 1 -F '[') 
	rom_resolution=${rom_resolution#"["}
	rom_resolution=${rom_resolution//]}
	rom_resolution=$(echo $rom_resolution | sed -e 's/\r//g')
	rom_resolution_width=$(echo $rom_resolution | cut -f1 -d"x")
	rom_resolution_height=$(echo $rom_resolution | cut -f2 -d"x")
	
# Set rom_resolution_height for 480p and 448p roms
	if [ $rom_resolution_height == "480" ]; then
		rom_resolution_height="240"
	elif [ $rom_resolution_height == "448" ]; then
		rom_resolution_height="224"
	fi	
	
# Create rom_name.cfg
	if ! [ -f "$rom_fp"".cfg" ]; then 
		touch "$rom_fp"".cfg" 
	fi
	
# Set custom_viewport_height
	if ! grep -q "custom_viewport_height" "$rom_fp"".cfg"; then
		echo -e "custom_viewport_height = ""\"$rom_resolution_height\"" >> "$rom_fp"".cfg" 2>&1
	fi
	
# determine if vertical  
	if grep -w "$rom_bn" /opt/retropie/configs/all/vertical.txt ; then 
		# Add vertical parameters (video_allow_rotate = "true")
		if ! grep -q "video_allow_rotate" "$rom_fp"".cfg"; then
			echo -e "video_allow_rotate = \"true\"" >> "$rom_fp"".cfg" 2>&1
		fi
		
		# Add vertical parameters (video_rotation = 3)
		if ! grep -q "video_rotation" "$rom_fp"".cfg"; then
			echo -e "video_rotation = \"3\"" >> "$rom_fp"".cfg" 2>&1
		fi	
		
		# Add integer scale parameters (video_scale_integer = true)
		if ! grep -q "video_scale_integer" "$rom_fp"".cfg"; then
			echo -e "video_scale_integer = \"true\"" >> "$rom_fp"".cfg" 2>&1
		fi
	fi

# set the custom_viewport_width 
	if ! grep -q "custom_viewport_width" "$rom_fp"".cfg"; then 
		echo -e "custom_viewport_width = ""\"1920\"" >> "$rom_fp"".cfg"  2>&1
	fi
fi

#### Michael Vencio X CRTPi X Sakitoshi ####

# determine and set variable resolutions for libretto cores

##############################################################################
#### NTSC section                                                         ####
##############################################################################

if [[ "$emul_lr" == "lr" ]] && [[ "${ISPAL}" == false ]] ; then
	# re-get the system name
	system=$1
	# write log file for NTSC game
	curtime=$(cat /proc/uptime | cut -f1 -d " ")
	echo "${curtime}: libretro NTSC Game found. System name: $1 - Emulator name: $2 - ROM name: $3" >> $logfile
	
# change timings for 256.txt to 2048x240p
	if { ! echo "$3" | grep -q -wi "$ThreeTwenty" || echo "$ThreeTwenty" | grep -q empty; } && ! echo "$ThreeTwenty" | grep -q -xi "all" && { echo "$3" | grep -q -wi "$TwoFiveSix"; } then > /dev/null
		vcgencmd hdmi_timings 2048 1 180 202 300 240 1 3 5 14 0 0 0 120 0 85909090 1 > /dev/null; #CRTPi 2048x240p Timing Adjusted
		tvservice -e "DMT 87" > /dev/null
		sleep 1 > /dev/null
		fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 2048 -yres 240 > /dev/null; #24b depth
		curtime=$(cat /proc/uptime | cut -f1 -d " ")
		echo "${curtime}: NTSC 256.txt 2048x240 (256x240) applied" >> $logfile
		
# change timings for 320.txt to 1920x240p
	elif { ! echo "$3" | grep -q -wi "$TwoFiveSix" || echo "$TwoFiveSix" | grep -q empty; } && ! echo "$TwoFiveSix" | grep -q -xi "all" && { echo "$3" | grep -q -wi "$ThreeTwenty"; } then > /dev/null
		vcgencmd hdmi_timings 1920 1 137 247 295 240 1 3 7 12 0 0 0 120 0 81720000 1 > /dev/null #CRTPi 1920x240p Timing Adjusted
		tvservice -e "DMT 87" > /dev/null
		sleep 1 > /dev/null
		fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 1920 -yres 240 > /dev/null #24b depth
		curtime=$(cat /proc/uptime | cut -f1 -d " ")
		echo "${curtime}: NTSC 320.txt 1920x240 (320x240) applied" >> $logfile

# change timings for 256x224 systems to 2048x224p
	elif 
		[[ "$system" == "snes" ]] || 
		[[ "$system" == "nes" ]] || 
		[[ "$system" == "romhacks" ]] ; then
			vcgencmd hdmi_timings 2048 1 160 202 320 224 1 11 5 22 0 0 0 120 0 85909090 1 > /dev/null #CRTPi 2048x224p Timing Adjusted
			tvservice -e "DMT 87" > /dev/null
			sleep 1 > /dev/null
			fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 2048 -yres 224 > /dev/null #24b depth
			curtime=$(cat /proc/uptime | cut -f1 -d " ")
			echo "${curtime}: NTSC 2048x224 (256x224) applied" >> $logfile
			
# change timings for 256x240 systems to 2048x240p
	elif 
		[[ "$system" == "fds" ]] || 
		[[ "$system" == "mastersystem" ]] || 
		[[ "$system" == "pcengine" ]] || 
		[[ "$system" == "pce-cd" ]] ||
		[[ "$system" == "ngp" ]] || 
		[[ "$system" == "ngpc" ]] || 
		[[ "$system" == "gb" ]] || 
		[[ "$system" == "gbc" ]] || 
		[[ "$system" == "gba" ]] || 
		[[ "$system" == "psp" ]] || 		
		[[ "$system" == "gamegear" ]] || 
		[[ "$system" == "virtualboy" ]] || 
		[[ "$system" == "atarilynx" ]] || 
		[[ "$system" == "wonderswan" ]] || 
		[[ "$system" == "wonderswancolor" ]] ; then
			vcgencmd hdmi_timings 2048 1 160 202 320 240 1 3 5 14 0 0 0 120 0 85909090 1 > /dev/null #CRTPi 2048x240p Timing Adjusted
			tvservice -e "DMT 87" > /dev/null
			sleep 1 > /dev/null
			fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 2048 -yres 240 > /dev/null #24b depth
			curtime=$(cat /proc/uptime | cut -f1 -d " ")
			echo "${curtime}: NTSC 2048x240 (256x240) applied" >> $logfile
			
# change timings for 256x192 systems to 2048x192p
	elif 		
		[[ "$system" == "sg-1000" ]] ; then
			vcgencmd hdmi_timings 2048 1 160 202 320 192 1 27 5 38 0 0 0 120 0 85909090 1 > /dev/null #CRTPi 2048x192p Timing Adjusted
			tvservice -e "DMT 87" > /dev/null
			sleep 1 > /dev/null
			fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 2048 -yres 192 > /dev/null #24b depth
			curtime=$(cat /proc/uptime | cut -f1 -d " ")
			echo "${curtime}: NTSC 2048x192 (256x192) applied" >> $logfile
			
# change timings for 320x224 & 384x224 systems to 1920x224p
	elif 
		[[ "$system" == "megadrive" ]] || 
		[[ "$system" == "segacd" ]] || 
		[[ "$system" == "sega32x" ]] || 
		[[ "$system" == "fba" ]] || 
		[[ "$system" == "neogeo" ]] ; then
			vcgencmd hdmi_timings 1920 1 137 247 295 224 1 11 7 20 0 0 0 120 0 81720000 1 > /dev/null #CRTPi 1920x224p Timing Adjusted
			tvservice -e "DMT 87" > /dev/null
			sleep 1 > /dev/null
			fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 1920 -yres 224 > /dev/null #24b depth
			curtime=$(cat /proc/uptime | cut -f1 -d " ")
			echo "${curtime}: NTSC 1920x224 (320x224 & 384x224) applied" >> $logfile

# change timings for 320x200 systems to 1920x200p
	elif 
		[[ "$system" == "quake" ]] || 
		[[ "$system" == "doom" ]] ; then
			vcgencmd hdmi_timings 1920 1 137 247 295 200 1 23 7 32 0 0 0 120 0 81720000 1 > /dev/null #CRTPi 1920x200p Timing Adjusted
			tvservice -e "DMT 87" > /dev/null
			sleep 1 > /dev/null
			fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 1920 -yres 200 > /dev/null #24b depth
			curtime=$(cat /proc/uptime | cut -f1 -d " ")
			echo "${curtime}: NTSC 1920x200 (320x200) applied" >> $logfile
			
# change timings for 320x192 systems to 1920x192p
	elif 
		## [[ "$system" == "atari5200" ]] || 
		[[ "$system" == "atari800" ]] || 
		[[ "$system" == "amiga" ]] || 
		[[ "$system" == "zxspectrum" ]] ; then
			vcgencmd hdmi_timings 1920 1 137 247 295 192 1 27 7 36 0 0 0 120 0 81720000 1 > /dev/null #CRTPi 1920x192p Timing Adjusted
			tvservice -e "DMT 87" > /dev/null
			sleep 1 > /dev/null
			fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 1920 -yres 192 > /dev/null #24b depth
			curtime=$(cat /proc/uptime | cut -f1 -d " ")
			echo "${curtime}: NTSC 1920x192 (320x192) applied" >> $logfile
			
# change timings for 320x240 systems to 1920x240p
	elif 
		[[ "$system" == "psx" ]] || 
		[[ "$system" == "atari2600" ]] || 
		[[ "$system" == "atari5200" ]] || 
		[[ "$system" == "dreamcast" ]] || 
		[[ "$system" == "saturn" ]] || 
		[[ "$system" == "atari7800" ]] || 
		[[ "$system" == "n64" ]] || 
		[[ "$system" == "arcade" ]] || 
		[[ "$system" == "mame-libretro" ]] || 
		[[ "$system" == "cavestory" ]] ; then 
			vcgencmd hdmi_timings 1920 1 137 247 295 240 1 3 7 12 0 0 0 120 0 81720000 1 > /dev/null #CRTPi 1920x240p Timing Adjusted
			tvservice -e "DMT 87" > /dev/null
			sleep 1 > /dev/null
			fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 1920 -yres 240 > /dev/null #24b depth
			curtime=$(cat /proc/uptime | cut -f1 -d " ")
			echo "${curtime}: NTSC 1920x240 (320x240) applied" >> $logfile

# change timings for C64 NTSC to 1600x240p 50 Hz - jedcooper 
	elif 
		[[ "$system" == "c64" ]] ; then
			vcgencmd hdmi_cvt 1600 240 120 1 0 0 0 > /dev/null
			tvservice -e "DMT 87" > /dev/null
			sleep 1 > /dev/null
			fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 1600 -yres 240 > /dev/null #24b depth
			curtime=$(cat /proc/uptime | cut -f1 -d " ")
			echo "${curtime}: NTSC 1600x240 (320x240) applied (C64 LR TESTING)" >> $logfile

# change timings for for Kodi to 1280x720p
	elif
    	[[ "$system" == "kodi" ]] ||
		[[ "$system" == "kodi-standalone" ]] ; then
		vcgencmd hdmi_timings 1280 1 80 72 216 720 1 5 3 22 0 0 0 60 0 74239049 1 > /dev/null #Retrotink 1280x720p@60hz Timing
		tvservice -e "DMT 87" > /dev/null
		sleep 1 > /dev/null
		fbset -depth 8 && fbset -depth 16 -xres 1280 -yres 720 > /dev/null #VGA666 16b depth
		tvservice -s > /dev/null
		curtime=$(cat /proc/uptime | cut -f1 -d " ")
		echo "${curtime}: NTSC 1280x720 (Kodi) applied" >> $logfile

	# otherwise default to 1600x240p
	else
		vcgencmd hdmi_timings 1600 1 95 157 182 240 1 4 3 15 0 0 0 120 0 64000000‬ 1 > /dev/null #VGA666 Generic 1600x240p@120hz Timing
		tvservice -e "DMT 87" > /dev/null
		sleep 1 > /dev/null
		fbset -depth 8 && fbset -depth 16 -xres 1600 -yres 240 > /dev/null #VGA666 16b depth
		tvservice -s > /dev/null
		curtime=$(cat /proc/uptime | cut -f1 -d " ")
		echo "${curtime}: NTSC 1600x240 (320x240) applied (DEFAULT)" >> $logfile

	fi

# otherwise -- determine and set variable resolutions for non-libretto cores	
elif [[ "${ISPAL}" == false ]] &&
# for 320x200 systems switch to 640x400p@65hz
	[[ "$system" == "eduke32" ]] ||
	[[ "$system" == "duke3d" ]] ||
	[[ "$system" == "scummvm" ]] ||
	[[ "$system" == "dosbox" ]] ||
	[[ "$system" == "pc" ]] ; then
	# [[ "$system" == "c64" ]] ; then
	#vcgencmd hdmi_timings 640 1 56 56 80 400 0 41 3 65 0 0 0 65 0 36000000 1 > /dev/null #CRTPi 640x400p@65 Adjusted
	vcgencmd hdmi_cvt 640 400 120 1 0 0 0 > /dev/null
	tvservice -e "DMT 87" > /dev/null
	sleep 1 > /dev/null
	fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 640 -yres 400 > /dev/null #24b depth
	curtime=$(cat /proc/uptime | cut -f1 -d " ")
	echo "${curtime}: Screenmode 640x400 @60 Hz (320x200) applied" >> $logfile
	
elif [[ "${ISPAL}" == false ]] &&
# C64 PAL Screenmode NON-libretro! - jedcooper
	[[ "$system" == "c64" ]] ; then
	vcgencmd hdmi_cvt 1600 240 100 1 0 0 0 > /dev/null
	tvservice -e "DMT 87" > /dev/null
	sleep 1 > /dev/null
	fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 1600 -yres 240 > /dev/null #24b depth
	curtime=$(cat /proc/uptime | cut -f1 -d " ")
	echo "${curtime}: PAL 1600x240 (320x240) applied (C64 NON-LR TESTING)" >> $logfile
       
elif [[ "${ISPAL}" == false ]] ; then
# for all other non-libretro emulators switch to 640x480p@65hz - changed to 50 Hz for general PAL purpose - jedcooper
	#vcgencmd hdmi_timings 640 1 56 56 80 480 0 1 3 25 0 0 0 65 0 36000000 1 > /dev/null #CRTPi 640x480p@65 Timing Adjusted
	vcgencmd hdmi_cvt 640 480 120 1 0 0 0 > /dev/null
	tvservice -e "DMT 87" > /dev/null
	sleep 1 > /dev/null
	fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 640 -yres 480 > /dev/null #24b depth
	curtime=$(cat /proc/uptime | cut -f1 -d " ")
	echo "${curtime}: NO system match for ${system}! NTSC Screenmode 640x480 @60 Hz applied (FALLBACK)" >> $logfile
	
fi

##############################################################################
#### PAL section - jedcooper                                              ####
##############################################################################

if [[ "$emul_lr" == "lr" ]] && [[ "${ISPAL}" == true ]] ; then
	# re-get the system name
	system=$1
	# write log file for PAL game
	curtime=$(cat /proc/uptime | cut -f1 -d " ")
	echo "${curtime}: libretro PAL Game found. System name: $1 - Emulator name: $2 - ROM name: $3" >> $logfile
	
# change timings for 256.txt to 2048x240p (PAL)
	if { ! echo "$3" | grep -q -wi "$ThreeTwenty" || echo "$ThreeTwenty" | grep -q empty; } && ! echo "$ThreeTwenty" | grep -q -xi "all" && { echo "$3" | grep -q -wi "$TwoFiveSix"; } then > /dev/null
		#vcgencmd hdmi_timings 2048 1 180 202 300 240 1 3 5 14 0 0 0 120 0 85909090 1 > /dev/null; #CRTPi 2048x240p Timing Adjusted
		vcgencmd hdmi_cvt 2048 240 100 1 0 0 0 > /dev/null 
		tvservice -e "DMT 87" > /dev/null
		sleep 1 > /dev/null
		fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 2048 -yres 240 > /dev/null; #24b depth
		curtime=$(cat /proc/uptime | cut -f1 -d " ")
		echo "${curtime}: PAL 256.txt 2048x240 (256x240) applied" >> $logfile
		
# change timings for 320.txt to 1920x256p (PAL)
	elif { ! echo "$3" | grep -q -wi "$TwoFiveSix" || echo "$TwoFiveSix" | grep -q empty; } && ! echo "$TwoFiveSix" | grep -q -xi "all" && { echo "$3" | grep -q -wi "$ThreeTwenty"; } then > /dev/null
		#vcgencmd hdmi_timings 1920 1 137 247 295 240 1 3 7 12 0 0 0 120 0 81720000 1 > /dev/null #CRTPi 1920x240p Timing Adjusted
		vcgencmd hdmi_cvt 1920 256 100 1 0 0 0 > /dev/null 
		tvservice -e "DMT 87" > /dev/null
		sleep 1 > /dev/null
		fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 1920 -yres 256 > /dev/null #24b depth
		curtime=$(cat /proc/uptime | cut -f1 -d " ")
		echo "${curtime}: PAL 320.txt 1920x256 (320x256) applied" >> $logfile

# change timings for 256x240 systems to 2048x240p (PAL)
	elif 
		[[ "$system" == "snes" ]] || 
		[[ "$system" == "nes" ]] || 
		[[ "$system" == "romhacks" ]] ; then
			#vcgencmd hdmi_timings 2048 1 160 202 320 224 1 11 5 22 0 0 0 120 0 85909090 1 > /dev/null #CRTPi 2048x224p Timing Adjusted
			vcgencmd hdmi_cvt 2048 240 100 1 0 0 0 > /dev/null 
			tvservice -e "DMT 87" > /dev/null
			sleep 1 > /dev/null
			fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 2048 -yres 240 > /dev/null #24b depth
			curtime=$(cat /proc/uptime | cut -f1 -d " ")
			echo "${curtime}: PAL 2048x240 (256x240) applied" >> $logfile
			
# change timings for 256x240 systems to 2048x240p (PAL)
	elif 
		[[ "$system" == "fds" ]] || 
		[[ "$system" == "mastersystem" ]] || 
		[[ "$system" == "pcengine" ]] || 
		[[ "$system" == "pce-cd" ]] ; then
			#vcgencmd hdmi_timings 2048 1 160 202 320 240 1 3 5 14 0 0 0 120 0 85909090 1 > /dev/null #CRTPi 2048x240p Timing Adjusted
			# mainly mastersystem - jedcooper
			vcgencmd hdmi_cvt 2048 240 100 1 0 0 0 > /dev/null 
			tvservice -e "DMT 87" > /dev/null
			sleep 1 > /dev/null
			fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 2048 -yres 240 > /dev/null #24b depth
			curtime=$(cat /proc/uptime | cut -f1 -d " ")
			echo "${curtime}: PAL 2048x240 (256x240) applied" >> $logfile
			
# change timings for 256x192 systems to 2048x192p - needed? - jedcooper
	elif 		
		[[ "$system" == "sg-1000" ]] ; then
			vcgencmd hdmi_timings 2048 1 160 202 320 192 1 27 5 38 0 0 0 120 0 85909090 1 > /dev/null #CRTPi 2048x192p Timing Adjusted
			tvservice -e "DMT 87" > /dev/null
			sleep 1 > /dev/null
			fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 2048 -yres 192 > /dev/null #24b depth
			curtime=$(cat /proc/uptime | cut -f1 -d " ")
			echo "${curtime}: NTSC 2048x192 (256x192) applied" >> $logfile
			
# change timings for 320x240 & 384x240 systems to 1920x240p (PAL)
	elif 
		[[ "$system" == "megadrive" ]] || 
		[[ "$system" == "segacd" ]] || 
		[[ "$system" == "sega32x" ]] || 
		[[ "$system" == "fba" ]] || 
		[[ "$system" == "neogeo" ]] ; then
			#vcgencmd hdmi_timings 1920 1 137 247 295 224 1 11 7 20 0 0 0 120 0 81720000 1 > /dev/null #CRTPi 1920x224p Timing Adjusted
			vcgencmd hdmi_cvt 1920 240 100 1 0 0 0 > /dev/null 
			tvservice -e "DMT 87" > /dev/null
			sleep 1 > /dev/null
			fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 1920 -yres 240 > /dev/null #24b depth
			curtime=$(cat /proc/uptime | cut -f1 -d " ")
			echo "${curtime}: PAL 1920x240 (320x240 & 384x240) applied" >> $logfile

# change timings for 320x200 systems to 1920x200p - needed? - jedcooper
	elif 
		[[ "$system" == "quake" ]] || 
		[[ "$system" == "doom" ]] ; then
			vcgencmd hdmi_timings 1920 1 137 247 295 200 1 23 7 32 0 0 0 120 0 81720000 1 > /dev/null #CRTPi 1920x200p Timing Adjusted
			tvservice -e "DMT 87" > /dev/null
			sleep 1 > /dev/null
			fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 1920 -yres 200 > /dev/null #24b depth
			curtime=$(cat /proc/uptime | cut -f1 -d " ")
			echo "${curtime}: NTSC 1920x200 (320x200) applied" >> $logfile
			
# change timings for 320x192 systems to 1920x192p
	elif 
		## [[ "$system" == "atari5200" ]] || 
		[[ "$system" == "atari800" ]] || 
		[[ "$system" == "amiga" ]] || 
		[[ "$system" == "zxspectrum" ]] ; then
			#vcgencmd hdmi_timings 1920 1 137 247 295 192 1 27 7 36 0 0 0 120 0 81720000 1 > /dev/null #CRTPi 1920x192p Timing Adjusted
			vcgencmd hdmi_cvt 1920 224 100 1 0 0 0 > /dev/null
			tvservice -e "DMT 87" > /dev/null
			sleep 1 > /dev/null
			fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 1920 -yres 224 > /dev/null #24b depth
			curtime=$(cat /proc/uptime | cut -f1 -d " ")
			echo "${curtime}: PAL 1920x224 (320x224) applied" >> $logfile
			
# change timings for 320x240 systems to 1920x240p (PAL)
	elif 
		[[ "$system" == "psx" ]] || 
		[[ "$system" == "atari2600" ]] || 
		[[ "$system" == "atari5200" ]] || 
		[[ "$system" == "dreamcast" ]] || 
		[[ "$system" == "saturn" ]] || 
		#[[ "$system" == "atari7800" ]] || 
		[[ "$system" == "n64" ]] || 
		[[ "$system" == "arcade" ]] || 
		[[ "$system" == "mame-libretro" ]] || 
		[[ "$system" == "cavestory" ]] ; then 
			#vcgencmd hdmi_timings 1920 1 137 247 295 240 1 3 7 12 0 0 0 120 0 81720000 1 > /dev/null #CRTPi 1920x240p Timing Adjusted
			vcgencmd hdmi_cvt 1920 240 100 1 0 0 0 > /dev/null
			tvservice -e "DMT 87" > /dev/null
			sleep 1 > /dev/null
			fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 1920 -yres 240 > /dev/null #24b depth
			curtime=$(cat /proc/uptime | cut -f1 -d " ")
			echo "${curtime}: PAL 1920x240 (320x240) applied" >> $logfile

# change timings for C64 PAL to 1600x240p 50 Hz - jedcooper
	elif 
		[[ "$system" == "c64" ]] ; then
			vcgencmd hdmi_cvt 1600 240 100 1 0 0 0 > /dev/null
			tvservice -e "DMT 87" > /dev/null
			sleep 1 > /dev/null
			fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 1600 -yres 240 > /dev/null #24b depth
			curtime=$(cat /proc/uptime | cut -f1 -d " ")
			echo "${curtime}: PAL 1600x240 (320x240) applied (C64 libretro)" >> $logfile

# change timings for Atari 7800 PAL to 1920x288 50 Hz - jedcooper
	elif
		[[ "$system" == "atari7800" ]] ; then
			vcgencmd hdmi_cvt 1920 288 100 1 0 0 0 > /dev/null
			tvservice -e "DMT 87" > /dev/null
			sleep 1 > /dev/null
			fbset -depth 8 && fbset -depth 16 && fbset -depth 24 -xres 1920 -yres 288 > /dev/null #24b depth
			curtime=$(cat /proc/uptime | cut -f1 -d " ")
			echo "${curtime}: PAL 1920x288 (320x288) applied (Atari 7800 PAL)" >> $logfile
		
# change timings for for Kodi to 1280x720p (720p50)
	elif
		[[ "$system" == "kodi" ]] ||
		[[ "$system" == "kodi-standalone" ]] ; then
		#vcgencmd hdmi_timings 1280 1 80 72 216 720 1 5 3 22 0 0 0 60 0 74239049 1 > /dev/null #Retrotink 1280x720p@60hz Timing
		vcgencmd hdmi_cvt 1280 720 50 1 0 0 0 > /dev/null
		tvservice -e "DMT 87" > /dev/null
		sleep 1 > /dev/null
		fbset -depth 8 && fbset -depth 16 -xres 1280 -yres 720 > /dev/null #VGA666 16b depth
		tvservice -s > /dev/null
		curtime=$(cat /proc/uptime | cut -f1 -d " ")
		echo "${curtime}: HD 720p50 (Kodi) applied" >> $logfile

	# otherwise default to 1600x240p (PAL)
	else
		# vcgencmd hdmi_timings 1600 1 95 157 182 240 1 4 3 15 0 0 0 120 0 64000000‬ 1 > /dev/null #VGA666 Generic 1600x240p@120hz Timing
		vcgencmd hdmi_cvt 1600 240 100 1 0 0 0 > /dev/null
		tvservice -e "DMT 87" > /dev/null
		sleep 1 > /dev/null
		fbset -depth 8 && fbset -depth 16 -xres 1600 -yres 240 > /dev/null #VGA666 16b depth
		tvservice -s > /dev/null
		curtime=$(cat /proc/uptime | cut -f1 -d " ")
		echo "${curtime}: PAL 1600x240 (320x240) applied (DEFAULT)" >> $logfile

	fi
	
fi

curtime=$(cat /proc/uptime | cut -f1 -d " ")
echo -e "***\n*** END of logfile: ${curtime} ***\n***" >> ${logfile}

#####
