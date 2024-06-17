#!/usr/bin/env bash
# shellcheck disable=SC2076,SC2207
#------------------------------------------------------------------------------

trace="no"
mode="Backup"

#scriptver="v3.0.50"
#script=Synology_app_mover
#repo="007revad/Synology_app_mover"
scriptname=syno_app_mover
scriptpath="$(dirname "$(realpath "$0")")"
#echo "$scriptpath"

# Shell Colors
#Red='\e[0;31m'      # ${Red}
Yellow='\e[0;33m'   # ${Yellow}
Cyan='\e[0;36m'     # ${Cyan}
Error='\e[41m'      # ${Error}
Off='\e[0m'         # ${Off}


conffile="${scriptpath}/${scriptname}.conf"
# Fix line endings
# grep can't detect Windows or Mac line endings 
#   but can detect if there's no Linux endings.
if grep -rIl -m 1 $'\r' "$conffile" >/dev/null; then
    # Does not contain Linux line endings
    sed -i 's/\r\n/\n/g' "$conffile"  # Fix Windows line endings
    sed -i 's/\r/\n/g' "$conffile"    # Fix Mac line endings
fi


#------------------------------------------------------------------------------
# Functions

# shellcheck disable=SC2317,SC2329  # Don't warn about unreachable commands in this function
pause(){ 
    # When debugging insert pause command where needed
    read -s -r -n 1 -p "Press any key to continue..."
    read -r -t 0.1 -s -e --  # Silently consume all input
    stty echo echok  # Ensure read didn't disable echoing user input
    echo -e "\n"
}

# shellcheck disable=SC2317,SC2329  # Don't warn about unreachable commands in this function
debug(){ 
    if [[ $1 == "on" ]]; then
        set -x
        export PS4='`[[ $? == 0 ]] || echo "\e[1;31;40m($?)\e[m\n "`LINE $LINENO '
    elif [[ $1 == "off" ]]; then
        set +x
    fi
}

folder_size(){ 
    # $1 is folder to check size of
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}"
    need=""    # var is used later in script
    needed=""  # var is used later in script
    if [[ -d "$1" ]]; then
        # Get size of $1 folder
        need=$(du -s "$1" | awk '{ print $1 }')
        # Add buffer GBs so we don't fill volume
        buffer=$(/usr/syno/bin/synogetkeyvalue "$conffile" buffer)
        if [[ $buffer -gt "0" ]]; then
            buffer=$((buffer *1000000))
        else
            buffer=0
        fi
        needed=$((need +"$buffer"))
    fi
}

vol_free_space(){ 
    # $1 is volume to check free space
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}"
    free=""  # var is used later in script
    if [[ -d "$1" ]]; then
        # Get amount of free space on $1 volume
        free=$(df --output=avail "$1" | grep -A1 Avail | grep -v Avail)
    fi
}

check_space(){ 
    # $1 is /path/folder
    # $2 is source volume or target volume
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}"

    # Get size of extra @ folder
    folder_size "$1"

    # Get amount of free space on target volume
    vol_free_space "$2"

    # Check we have enough space
    if [[ ! $free -gt $needed ]]; then
        echo -e "${Yellow}WARNING${Off} Not enough space to ${mode,,}"\
            "/${sourcevol}/${Cyan}$(basename -- "$1")${Off} to $targetvol"
        echo -en "Free: $((free /1048576)) GB  Needed: $((need /1048576)) GB"
        if [[ $buffer -gt "0" ]]; then
            echo -e " (plus $((buffer /1000000)) GB buffer)\n"
        else
            echo -e "\n"
        fi
        return 1
    else
        return 0
    fi
}


#------------------------------------------------------------------------------
# Select mode

echo ""
echo -e "You selected ${Cyan}Move${Off}"
echo -e "You selected ${Cyan}Container Manager${Off}\n"


# Check backup path if mode is backup or restore
if [[ ${mode,,} != "move" ]]; then
    if [[ ! -f "$conffile" ]]; then
        echo -e "Line ${LINENO}: ${Error}ERROR${Off} $conffile not found!"
        exit 1  # Conf file not found
    fi
    if [[ ! -r "$conffile" ]]; then
        echo -e "Line ${LINENO}: ${Error}ERROR${Off} $conffile not readable!"
        exit 1  # Conf file not readable
    fi

    # Get and validate backup path
    backuppath="$(/usr/syno/bin/synogetkeyvalue "$conffile" backuppath)"

echo "debug: backup path: $backuppath"

    if [[ -z "$backuppath" ]]; then
        echo -e "Line ${LINENO}: ${Error}ERROR${Off} backuppath missing from ${conffile}!"
        exit 1  # Backup path missing in conf file
    elif [[ ! -d "$backuppath" ]]; then
        echo -e "Line ${LINENO}: ${Error}ERROR${Off} Backup folder ${Cyan}$backuppath${Off} not found!"
        exit 1  # Backup folder not found
    fi
fi

targetvol="$(echo "$backuppath" | cut -d"/" -f2)"
#echo "debug: targetvol 1: $targetvol"
targetvol="/${targetvol:?}"
echo "debug: target volume: $targetvol"
echo 

#------------------------------------------------------------------------------
# Move the package or packages


#trace=yes  # debug ##################################################


process_packages(){
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}"
    target=$(readlink "/var/packages/${pkg}/target")
    #sourcevol="/$(printf %s "${target:?}" | cut -d'/' -f2 )"
    sourcevol="$(printf %s "${target:?}" | cut -d'/' -f2 )"

    # Move package
    if [[ $pkg == "ContainerManager" ]] || [[ $pkg == "Docker" ]]; then
        # Move @docker if package is ContainerManager or Docker

        # Check if @docker is on same volume as Docker package
        if [[ -d "/${sourcevol}/@docker" ]]; then
            # Check we have enough space
            if ! check_space "/${sourcevol}/@docker" "${targetvol}"; then
                echo -e "${Error}ERROR${Off} Not enough space on $targetvol to ${mode,,} ${Cyan}@docker${Off}!"
                return 1
            fi
        fi

    fi

}

pkg=ContainerManager
#pkg_name="Container Manager"
#process_error=""

process_packages

exit

