#!/bin/bash
#
# v0.05
#
# Generate CSV gamelist with refreshrates etc.
#
#

# Variables
version=0.05
scanfolder="$HOME/RetroPie/roms/arcade"
mame2003plusXML="/home/pi/RetroPie/roms/arcade/mame2003-plus/mame2003-plus.xml"
delimiter=";"
csvfile="/home/pi/RetroPie/roms/arcade/mame2003-plus/gamelist.csv"
tableheader=('ROM filename' 'ROM name' 'Clear name' 'Year' 'Res. X' 'Res. Y' 'Aspect X' 'Aspect Y' 'Refresh' 'Orientation' 'Sound chan.' 'Players' 'Control' 'Buttons')

# maybe commandline flags
CREATENEW=false

# Some info
echo -e "\nWelcome to $0 :-)"
echo "=============================================================================="
echo -e "\nVersion:  ${version} - jedcooper"

rm -f "${csvfile}"

# Generate table header
echo -e -n "\nGenerating table header"
for col in "${tableheader[@]}" ; do
    echo -n ${col}${delimiter} >> "${csvfile}"
    echo -n "."
done
echo "" >> "${csvfile}"
echo "Done."

echo -e -n "\nGenerating rows"
for ROM in ${scanfolder}/*.zip ; do
    romfilename=$(basename ${ROM})
    rom=${romfilename%.*}
    romXML="/home/pi/RetroPie/roms/arcade/mame2003-plus/${rom}.xml"
    if [ ! -f ${romXML} ] || [ $(stat -c '%s' ${romXML}) -lt 100 ] || [ $CREATENEW = true ] ; then
        xmlstarlet sel -t -c "//game[@name=\"${rom}\"]" "${mame2003plusXML}" > ${romXML}
        if [ ! -f ${romXML} ] || [ $(stat -c '%s' ${romXML}) -lt 100 ]  ; then
            echo -e "\nERROR! ${romfilename} (${rom}) = Invalid ROM name or ROM not found in MAME DB."
            rm -f ${romXML}
            continue
        fi
    fi
    romclearname=$(xmlstarlet sel -t -v "//description" ${romXML})
    year=$(xmlstarlet sel -t -v "//year" ${romXML})
    resx=$(xmlstarlet sel -t -v "//video/@width" ${romXML})
    resy=$(xmlstarlet sel -t -v "//video/@height" ${romXML})
    aspx=$(xmlstarlet sel -t -v "//video/@aspectx" ${romXML})
    aspy=$(xmlstarlet sel -t -v "//video/@aspecty" ${romXML})
    refresh=$(xmlstarlet sel -t -v "//video/@refresh" ${romXML})
    orientation=$(xmlstarlet sel -t -v "//video/@orientation" ${romXML})
    soundchan=$(xmlstarlet sel -t -v "//sound/@channels" ${romXML})
    players=$(xmlstarlet sel -t -v "//input/@players" ${romXML})
    control=$(xmlstarlet sel -t -v "//input/@control" ${romXML})
    buttons=$(xmlstarlet sel -t -v "//input/@buttons" ${romXML})
    echo ${romfilename}${delimiter}${rom}${delimiter}${romclearname}${delimiter}${year}${delimiter}${resx}${delimiter}${resy}${delimiter}${aspx}${delimiter}${aspy}${delimiter}${refresh}${delimiter}${orientation}${delimiter}${soundchan}${delimiter}${players}${delimiter}${control}${delimiter}${buttons} >> ${csvfile}
    echo -n "."
done
echo "Done."