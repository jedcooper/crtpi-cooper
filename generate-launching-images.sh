#!/usr/bin/env bash
# generate-launching-images.sh
##############################
#
# This script creates launching images for a specific theme.
# If you don't know what it is, take a look at these links:
# - https://github.com/retropie/retropie-setup/wiki/runcommand#adding-custom-launching-images
# - https://retropie.org.uk/forum/topic/4611/runcommand-system-splashscreens
#
# Requirements:
# - RetroPie 4.0.3+
# - the imagemagick package installed (it means 26.1 MB of disk space used).
#
# TODO: 
# - check every <include>d file and dump in a big temporary xml file.
# - --loading-text-belt
# - --press-button-text-belt
# - --es-view
# - --logo-color
# - --ratio

# globals ###################################################################

# avoiding problems when running via sudo
user="$SUDO_USER"
[[ -z "$user" ]] && user="$(id -un)"
home="$(eval echo ~$user)"

readonly ES_DIR=("$home/.emulationstation" "/etc/emulationstation")
readonly CONFIGDIR="/opt/retropie/configs"
readonly TMP_BACKGROUND="/tmp/background.png"
readonly TMP_LOGO="/tmp/system_logo.png"
readonly TMP_CRTPILOGO="/tmp/crtpi_logo.png"
readonly TMP_LAUNCHING="/tmp/tmp_launching.png"
readonly FINAL_IMAGE="/tmp/launching"
readonly IS_RUNNING_X="$([[ -n "$DISPLAY" ]] && echo true || echo false )"
THEME_DIR=
ES_SYSTEMS_CFG=
FAILED_SYSTEMS=()
FAILED_MSGS=()


# settings variables ########################################################

THEME=
EXT="png"
LOADING_TEXT="NOW LOADING"
PRESS_BUTTON_TEXT="PRESS A BUTTON TO CONFIGURE LAUNCH OPTIONS"
LOADING_TEXT_COLOR="white"
PRESS_BUTTON_TEXT_COLOR="gray50"
DESTINATION_DIR="$CONFIGDIR"
SHOW_TIMEOUT="5"
NO_ASK="0"
NO_LOGO="0"
LOGO_BELT="0"
SYSTEMS_ARRAY=()
ALL_SYSTEMS_FLAG="0"
SOLID_BG_COLOR=
SOLID_BG_COLOR_FLAG=
# CRTPi-cooper 4:3 HiRes Image
WIDTH="1441"
HEIGHT="1080"

# CRTPi-cooper Launching Images Resolution
WIDTHCRT="1920"
HEIGHTCRT="240"


# functions #################################################################

function safe_exit() {
    rm -f "$TMP_BACKGROUND" "$TMP_LOGO" "$TMP_CRTPILOGO" "$TMP_LAUNCHING" "$FINAL_IMAGE.$EXT"
    exit "$1"
}



# checking dependencies
function check_dep() {
    # checking if we have the imagemagick installed
    if ! which convert > /dev/null; then
        echo "ERROR: The imagemagick package isn't installed!"
        echo "Please install it with 'sudo apt-get install imagemagick'."
        exit 1
    fi
    # if we are running under X we need feh and xrandr
    if [[ "$IS_RUNNING_X" == 'true' ]] && ! which feh xrandr > /dev/null; then
        echo "ERROR: command(s) feh and/or xrandr not found!"
        echo "Please install them with 'sudo apt-get install feh x11-xserver-utils'."
        exit 1
    fi
}



function usage() {
    echo
    echo "USAGE: $(basename "$0") -t theme-name [options]"
    echo
    echo "Use '--help' to see all the options"
    echo
}



# deal with command line arguments
function get_options() {
    local dir
    for dir in "${ES_DIR[@]}"; do
        if [[ -f "$dir/es_systems.cfg" ]]; then
            ES_SYSTEMS_CFG="$dir/es_systems.cfg"
            break
        fi
    done
    while [[ -n "$1" ]]; do
        case "$1" in

#H -h, --help                   Print the help message and exit.
        -h|--help)
            usage
            # getting the help message from the comments in this source code
            sed '/^#H /!d; s/^#H //' "$0"
            exit 0
            ;;

#H -t, --theme THEME            Create launching images based on THEME. This is
#H                              the only mandatory option in order to generate
#H                              the images (see --list-themes).
        -t|--theme)
            check_argument "$1" "$2" || exit 1
            shift

            local dir=
            for dir in "${ES_DIR[@]}"; do
                dir="$dir/themes/$1"
                if [[ -d "$dir" ]]; then
                    THEME_DIR="$dir"
                    break
                fi
            done

            if ! [[ -d "$THEME_DIR" ]]; then
                echo "ERROR: there's no theme named \"$1\" installed." >&2
                list_themes
                exit 1
            fi
            # if reached this point, the THEME_DIR is OK
            THEME="$1"
            ;;

#H --list-themes                List the available themes and exit.
        --list-themes)
            list_themes
            exit
            ;;

#H --system SYSTEM              Create image only for SYSTEM (the default is
#H                              create for all systems found in es_systems.cfg,
#H                              see --list-systems).
        --system)
            check_argument "$1" "$2" || exit 1
            shift
            SYSTEMS_ARRAY="$1"
            ;;

#H --all-systems                Create image for all systems of the chosen theme.
        --all-systems)
            ALL_SYSTEMS_FLAG="1"
            ;;

#H --list-systems               List the installed systems on your RetroPie
#H                              (get this info from es_systems.cfg)
        --list-systems)
            list_systems
            exit
            ;;

#H --extension EXT              Set the extension of the created image file
#H                              (valid options: png|jpg).
        --extension)
            check_argument "$1" "$2" || exit 1
            shift
            if ! [[ "$1" =~ ^(png|jpg)$ ]]; then
                echo "ERROR: invalid extension: $1" >&2
                echo "Valid extensions: png jpg" >&2
                exit 1
            fi
            EXT="$1" 
            ;;

#H --loading-text "TEXT"        Set the "LOADING" text (default: "NOW LOADING").
        --loading-text)
            if check_argument "$1" "$2"; then
                shift
                LOADING_TEXT="$1"
            else
                LOADING_TEXT=""
            fi
            ;;

#H --press-button-text "TEXT"   Set the "PRESS A BUTTON" text (default:
#H                              "PRESS A BUTTON TO CONFIGURE LAUNCH OPTIONS").
        --press-button-text)
            if check_argument "$1" "$2"; then
                shift
                PRESS_BUTTON_TEXT="$1"
            else
                PRESS_BUTTON_TEXT=""
            fi
            ;;

#H --loading-text-color COLOR   Set the color for the "LOADING" text
#H                              (default: white).
        --loading-text-color)
            check_argument "$1" "$2" || exit 1
            shift
            validate_color "$1"
            LOADING_TEXT_COLOR="$1"
            ;;
            
#H --press-button-text-color COLOR  Set the color for the "PRESS A BUTTON" text.
#H                                  (default: gray50).
        --press-button-text-color)
            check_argument "$1" "$2" || exit 1
            shift
            validate_color "$1"
            PRESS_BUTTON_TEXT_COLOR="$1"
            ;;

#H --no-ask                     Do not show the created images and ask for
#H                              confirmation (blindly accept the created images).
        --no-ask)
            NO_ASK="1"
            ;;

#H --no-logo                    Do not put the system logo on the created image.
        --no-logo)
            NO_LOGO="1"
            ;;

#H --logo-belt                  Put a semi-transparent white belt behind the logo.
        --logo-belt)
            LOGO_BELT="1"
            ;;

#H --show-timeout TIME          Show the created image for TIME seconds before
#H                              ask if the user accept it (see --no-ask).
        --show-timeout)
            check_argument "$1" "$2" || exit 1
            shift
            SHOW_TIMEOUT=$1
            ;;

#H --solid-bg-color [COLOR]     Use a solid color as background. If COLOR is
#H                              omitted, use the color specified by the theme.
        --solid-bg-color)
            if check_argument "$1" "$2"; then
                validate_color "$2"
                SOLID_BG_COLOR="$2"
                shift
            fi
            SOLID_BG_COLOR_FLAG="1"
            ;;

#H --destination-dir DIR        Save the created images in DIR directory tree.
        --destination-dir)
            check_argument "$1" "$2" || exit 1
            shift
            DESTINATION_DIR="$1"

            mkdir -p "$DESTINATION_DIR"
            if ! [[ -w "$DESTINATION_DIR" && -x "$DESTINATION_DIR" ]]; then
                dialog \
                  --title " ERROR " \
                  --msgbox "ERROR: '$DESTINATION_DIR': Permission denied" \
                  6 65
                exit 1
            fi
            ;;

        *)
            echo "ERROR: invalid option \"$1\"" >&2
            exit 2
            ;;
        esac
        shift
    done

    if [[ -z "$THEME" ]]; then
        echo "ERROR: missing theme"
        usage
        exit 1
    fi
}



function detect_aspect_ratio() {
    local resolution
    local width
    local height
    local aspectRatio

    # running on X
    if [[ "$IS_RUNNING_X" == true ]]; then
        # from https://superuser.com/a/1207339
        resolution="$(xrandr --current | sed -n 's/.* connected [a-z ]*\([0-9]\+\)x\([0-9]\+\)+.*/\1x\2/p')"
    else # running on a raspi
        local resFile="/sys/class/graphics/fb0/virtual_size"
        if [[ -f "$resFile" ]]; then
            resolution="$(tr , x < "$resFile")"
        else
            resolution="$(fbset -s | grep -oE '[0-9]+x[0-9]+')"
        fi
    fi
    # manually set resolution CRTPi-cooper
    resolution=${WIDTH}x${HEIGHT}
    # if unable to detect the resolution, just use the default ones
    [[ "$resolution" =~ [0-9]+x[0-9]+ ]] || return

    width="$(cut -d 'x' -f1 <<< "$resolution")"
    height="$(cut -d 'x' -f2 <<< "$resolution")"
    aspectRatio="$(( width * 1000 / height ))"
    WIDTH="$(( HEIGHT * aspectRatio / 1000 ))"
}



function list_themes() {
    local dir
    local list
    for dir in "${ES_DIR[@]}"; do
        dir+="/themes"
        list=$( 
            find "$dir" -mindepth 1 -maxdepth 1 -type d -regex "$dir/.+" 2>/dev/null \
            | sort | xargs
        )
        [[ -n "$list" ]] && basename -a $list   # "quotes" absence is mandatory
    done
}



function list_systems() {
    xmlstarlet sel -t -v "/systemList/system/name" "$ES_SYSTEMS_CFG" | grep -v retropie
}



function check_argument() {
    # XXX: it'll be a problem if a theme name starts with '-'
    if [[ -z "$2" || "$2" =~ ^- ]]; then
        echo "$1: missing argument" >&2
        return 1
    fi
}



# check if $1 is a valid color, exit if it's not.
function validate_color() {
    if convert -list color | grep -q "^$1\b"; then
        return 0
    fi
    echo "ERROR: invalid color \"$1\"." >&2
    echo "Short list of available colors:" >&2
    echo "black white gray gray10 gray25 gray50 gray75 gray90" >&2
    echo "pink red orange yellow green silver blue cyan purple brown" >&2
    echo "TIP: run the 'convert -list color' command to get a full list" >&2
    exit 1
}



function show_image() {
    [[ -f "$1" ]] || return 1

    local image="$1"

    # if we are running under X use feh otherwise try to use fbi
    if [[ "$IS_RUNNING_X" == 'true' ]]; then
        feh \
          --cycle-once \
          --hide-pointer \
          --fullscreen \
          --auto-zoom \
          --no-menus \
          --slideshow-delay "$SHOW_TIMEOUT" \
          --quiet \
          "$image"
    else
        fbi \
          --once \
          --timeout "$SHOW_TIMEOUT" \
          --noverbose \
          --autozoom \
          "$image" </dev/tty &>/dev/null
    fi
}



function get_systems() {
    # interrupt if user explicitly defined the system with --system
    [[ -n "$SYSTEMS_ARRAY" ]] && return 0
    local system_list
    if [[ "$ALL_SYSTEMS_FLAG" = "1" ]]; then
        system_list=$(ls -d "$THEME_DIR"/*/ | xargs basename -a | grep -v 'retropie\|art\|_inc\|assets')
    else
        system_list=$(list_systems)
    fi
    [[ -z "$system_list" ]] && return 1
    SYSTEMS_ARRAY=($system_list)
}



# Get the useful data for a theme of a specific system. The "system" global
# variable must be filled.
function get_data_from_theme_xml() {
    if [[ -z "$1" ]]; then
        echo "ERROR: get_data_from_theme_xml(): missing argument."
        echo "Available options: background font logo tile bg_color"
        exit 1
    fi

    if [[ -z "$SYSTEM" ]]; then
        echo "ERROR: get_data_from_theme_xml(): the system is undefined."
        exit 1
    fi

    local xml_path=
    local system_theme_dir=
    local xml_file=
    local data=""
    local dir=
    local included_xml=()
    local i=

    case "$1" in
    "background")
        # TODO: find a more elegant way to deal with different names
        xml_path="/theme/view[contains(@name,'system')]/image[@name='background' or @name='SystemBackground']/path"
        ;;
    "tile")
        xml_path="/theme/view[contains(@name,'system')]/image[@name='background' or @name='SystemBackground']/tile"
        ;;
    "bg_color")
        xml_path="/theme/view[contains(@name,'system')]/image[@name='background' or @name='SystemBackground']/color"
        ;;
    "logo")
        xml_path="/theme/view[contains(@name,'detailed') or contains(@name,'system')]/image[@name='logo']/path"
        ;;
    "font")
        xml_path="/theme/view[contains(@name,'detailed')]/textlist/fontPath"
        ;;
    *)
        echo "ERROR: get_data_from_theme_xml(): invalid argument"
        exit 1
        ;;
    esac

    if [[ "$ALL_SYSTEMS_FLAG" = "1" ]]; then
        system_theme_dir="$SYSTEM"
    else
        system_theme_dir=$(
            xmlstarlet sel -t -v \
              "/systemList/system[name='$SYSTEM']/theme" \
              "$ES_SYSTEMS_CFG"
        )
    fi

    [[ -z "$system_theme_dir" ]] && system_theme_dir="$SYSTEM"

    xml_file="$THEME_DIR/$system_theme_dir/theme.xml"
    [[ -f "$xml_file" ]] || return 2

    # dealing with <include>s
    # TODO: get every <include>d file and dump in a big temporary xml file.
    while [[ -f "$xml_file" ]]; do
        data=$(
            xmlstarlet sel -t -v \
              "$xml_path" \
              "$xml_file" 2> /dev/null | head -1
        )

        [[ -n "$data" ]] && break
    
        included_xml=( $(xmlstarlet sel -t -v "/theme/include" "$xml_file" 2> /dev/null) )
        [[ "${#included_xml[@]}" -eq 0 ]] && return 1
        for i in "${included_xml[@]}"; do
            xml_file="$(dirname "$xml_file")/$i"
            data=$(xmlstarlet sel -t -v "$xml_path" "$xml_file" 2> /dev/null | head -1)
            [[ -n "$data" ]] && break 2
        done
    done

    [[ -z "$data" ]] && return

    if [[ "$1" = "tile" || "$1" = "bg_color" ]]; then
        echo "$data"
        return
    fi
    
    # XXX: it's an ugly workaround!
    # dealing with known issues in themes
    if [[ "$THEME" = "carbon" ]]; then
        if [[ "$1" = "logo" ]]; then
            # due to color problems, we use system3.png for gameandwatch
            # and system2.png for steam and gamecube (gc).
            case "$SYSTEM" in
            "gameandwatch")
                data="${data/%system.svg/system3.svg}"
                ;;
            "steam")
                data="${data/%system.svg/system2.svg}"
                ;;
            "gc")
                data="${data/%system.svg/system2.svg}"
                ;;
            esac
        fi
    fi

    echo "$(dirname "$xml_file")/$data"
} # end of get_data_from_theme_xml()



function proceed() {
    local number_of_systems=$(echo "${SYSTEMS_ARRAY[@]}" | wc -w)
    local msg=$(
        echo    "Destination directory......: \"$DESTINATION_DIR\"\n"
        echo    "Theme......................: $THEME\n"
        echo    "System.....................: $( 
            if [[ "$number_of_systems" != 1 ]]; then 
                echo "all systems in es_systems.cfg" 
            else 
                echo "$SYSTEMS_ARRAY"
            fi 
            echo "\n"
        )"

        echo    "Image extension............: $EXT\n"
        echo    "\"LOADING\" text.............: $LOADING_TEXT\n"
        echo    "\"LOADING\" text color.......: $LOADING_TEXT_COLOR\n"
        echo    "\"PRESS A BUTTON\" text......: $PRESS_BUTTON_TEXT\n"
        echo    "\"PRESS A BUTTON\" text color: $PRESS_BUTTON_TEXT_COLOR\n"

        [[ "$NO_ASK" = "1" ]] \
        && echo "Do not ask for confirmation (blindly accept generated images).\n" \
        || echo "Show image timeout.........: $SHOW_TIMEOUT\n"

        [[ "$SOLID_BG_COLOR_FLAG" = "1" ]] \
        && echo "Solid background color.....: ${SOLID_BG_COLOR:-get from the theme}\n"

        [[ "$NO_LOGO" = "1" ]] \
        && echo "The images will be created with no system logo.\n"

        [[ "$LOGO_BELT" = "1" ]] \
        && echo "Put a semitransparent horizontal belt behind the system logo.\n"

        echo "\n\nDO YOU WANT TO PROCEED?\n"
    )

    dialog \
      --title " SETTINGS SUMMARY " \
      --yesno "$msg" \
      20 75 || exit 0
}



function create_launching_image() {
    if [[ -z "$SYSTEM" ]]; then
        echo "ERROR: create_launching_image(): the system is undefined."
        exit 1
    fi

    rm -f "$TMP_BACKGROUND" "$TMP_LOGO" "$TMP_CRTPILOGO" "$TMP_LAUNCHING"

    local ret_val
    prepare_background
    ret_val=$?
    if [[ "$ret_val" -ne 0 ]]; then
        FAILED_SYSTEMS+=($SYSTEM)
        if [[ "$ret_val" -eq 2 ]]; then
            FAILED_MSGS+=("there's no theme.xml for this system")
        else
            FAILED_MSGS+=("failed to prepare the background image.")
        fi
        return 1
    fi

    if ! add_logo; then
        FAILED_SYSTEMS+=($SYSTEM)
        FAILED_MSGS+=("failed to add the logo image.")
        return 1
    fi
    if ! add_crtpilogo; then
		FAILED_SYSTEMS+=($SYSTEM)
    	FAILED_MSGS+=("failed to add the crtpi logo image.")
    	return 1
    fi
    if ! add_text; then
        FAILED_SYSTEMS+=($SYSTEM)
        FAILED_MSGS+=("failed to add text to the image.")
        return 1
    fi

    # XXX: decide if this quality reducing is needed.
    # CRTPi-cooper resize for CRT 1920x240!
    convert "$TMP_LAUNCHING" -resize ${WIDTHCRT}x${HEIGHTCRT}! -quality 80 "$FINAL_IMAGE.$EXT"
    convert "$TMP_LAUNCHING" -quality 80 "${FINAL_IMAGE}_orig.$EXT"
} # end of create_launching_image



# ImageMagick tricks go in these functions ###################################

function prepare_background() {
    local background=
    local bg_color=
    local convert_cmd=(convert)
    local colorize=

    # getting the background file
    background=$(get_data_from_theme_xml background) || return $?

    # getting the background color
    if [[ -n "$SOLID_BG_COLOR" ]]; then
        bg_color="$SOLID_BG_COLOR"
    else
        bg_color="#$(get_data_from_theme_xml bg_color)"
    fi

    if [[ -n "$bg_color" && "$bg_color" != "#" ]]; then
        if [[ "$SOLID_BG_COLOR_FLAG" ]]; then
            colorize="100,100,100"
        else
            colorize="25,25,25"
        fi

        convert -fill "$bg_color" -colorize "$colorize" \
          "$background" "$TMP_BACKGROUND"
        background="$TMP_BACKGROUND"
    fi

    if [[ "$(get_data_from_theme_xml tile)" =~ ^[Tt][Rr][Uu][Ee]$ ]]; then
        convert_cmd+=(-size "${WIDTH}x${HEIGHT}" "tile:")
    else
        convert_cmd+=(-resize "x${HEIGHT}" " ") # the trailing space is needed
    fi
    
    ${convert_cmd[@]}"$background" "$TMP_LAUNCHING" || return $?

    if [[ "$LOGO_BELT" = "1" ]]; then
        convert "$TMP_LAUNCHING" \
          -fill white \
          -gravity center \
          -region "${WIDTH}x190" \
          -colorize 40,40,40 \
          "$TMP_LAUNCHING"
    fi
}



function add_logo() {
    [[ "$NO_LOGO" = "1" ]] && return

    local logo=

    logo=$(get_data_from_theme_xml logo)
    if [[ -z "$logo" ]]; then
        echo "WARNING: No logo found for \"$SYSTEM\" system."
        return 1
    fi
    # resize original was 450x176
    convert -background none \
      -resize "900x352" \
      "$logo" "$TMP_LOGO"
    
    if ! [[ -f "$TMP_LOGO" ]]; then
        echo "WARNING: we had some problem when converting \"$SYSTEM\" logo image."
        return 1
    fi

    convert "$TMP_LAUNCHING" \
      -gravity center "$TMP_LOGO" \
      -composite "$TMP_LAUNCHING"

    return $?
}



function add_crtpilogo() {

	local logo=
	logo=/opt/retropie/supplementary/launchingimages/CRTPi-cooper.png

	if [[ -z "$logo" ]]; then
		echo "WARNING: No crtpi logo found."
        return 1
	fi
	
	convert "$TMP_LAUNCHING" \
	  -gravity center "$logo" \
	  -geometry +0-340 \
	  -composite "$TMP_LAUNCHING"

	return $?

}



function add_text() {
    local font=

    font=$(get_data_from_theme_xml font)
    if [[ -z "$font" ]]; then
        echo "WARNING: No font found for \"$SYSTEM\" system."
        return 1
    fi

    # pointsizes original were 24 and 14, annotations were 170 and 230

    convert "$TMP_LAUNCHING" \
      -gravity center \
      -font "$font" \
      -weight 700 \
      -pointsize 48 \
      -fill "$LOADING_TEXT_COLOR" \
      -annotate +0+340 "$LOADING_TEXT" \
      "$TMP_LAUNCHING" \
    && convert "$TMP_LAUNCHING" \
      -gravity center \
      -font "$font" \
      -weight 700 \
      -pointsize 36 \
      -fill "$PRESS_BUTTON_TEXT_COLOR" \
      -annotate +0+460 "$PRESS_BUTTON_TEXT" \
      "$TMP_LAUNCHING"

    return $?
}



# start here ################################################################

trap safe_exit SIGHUP SIGINT SIGQUIT SIGKILL SIGTERM

check_dep

get_options "$@"

if ! get_systems; then
    echo "ERROR: failed to get the installed systems!" >&2
    exit 1
fi

proceed

detect_aspect_ratio

for SYSTEM in "${SYSTEMS_ARRAY[@]}"; do
    dialog \
      --title ' Please wait ' \
      --infobox "Generating launching image for \"$SYSTEM\"..." \
      3 60

    if ! create_launching_image ; then
        echo "WARNING: The launching image for \"$SYSTEM\" was NOT created." >&2
        continue
    fi


    if [[ "$NO_ASK" != "1" ]]; then
        show_image "$FINAL_IMAGE.$EXT"
        dialog \
          --yesno "Do you accept this as the launching image for \"$SYSTEM\" system?" \
          8 45 \
          || continue
    fi

    mkdir -p "$DESTINATION_DIR/$SYSTEM"
    if ! mv "$FINAL_IMAGE.$EXT" "$DESTINATION_DIR/$SYSTEM/launching.$EXT"; then
        FAILED_SYSTEMS+=($SYSTEM)
        FAILED_MSGS+=("unable to put the created image in \"$DESTINATION_DIR/$SYSTEM\".")
        continue
    fi
    if ! mv "${FINAL_IMAGE}_orig.$EXT" "$DESTINATION_DIR/$SYSTEM/launching_orig.$EXT"; then
        FAILED_SYSTEMS+=($SYSTEM)
	FAILED_MSGS+=("unable to put the created image in \"$DESTINATION_DIR/$SYSTEM\".")
	continue
    fi
    case "$EXT" in
        jpg)    rm -f "$DESTINATION_DIR/$SYSTEM/launching.png" ;;
        png)    rm -f "$DESTINATION_DIR/$SYSTEM/launching.jpg" ;;
    esac
done


fail_msg=$(
    if [[ -n "$FAILED_SYSTEMS" ]]; then
        echo "Failed to create image for the following systems:\n"
        for i in $(seq 0 $(( ${#FAILED_SYSTEMS[@]} - 1 )) ); do
            echo "${FAILED_SYSTEMS[$i]}: ${FAILED_MSGS[$i]}\n"
        done
    fi
)

dialog \
  --title " INFO " \
  --msgbox "Launching images generation for \"$THEME\" theme completed!\n\n$fail_msg" \
  20 60

safe_exit 0
