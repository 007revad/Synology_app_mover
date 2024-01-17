#!/usr/bin/env bash
#-----------------------------------------------------------------------------------
# Easily move Synology packages from 1 volume to another volume.
#
# Github: https://github.com/007revad/Synology_app_mover
# Script verified at https://www.shellcheck.net/
#
# To run in a shell (replace /volume1/scripts/ with path to script):
# sudo -i /volume1/scripts/syno_app_mover.sh
#-----------------------------------------------------------------------------------

scriptver="v1.1.5"
script=Synology_app_mover
repo="007revad/Synology_app_mover"
#scriptname=syno_app_mover


# Shell Colors
#Black='\e[0;30m'   # ${Black}
Red='\e[0;31m'      # ${Red}
#Green='\e[0;32m'   # ${Green}
Yellow='\e[0;33m'   # ${Yellow}
#Blue='\e[0;34m'    # ${Blue}
#Purple='\e[0;35m'  # ${Purple}
Cyan='\e[0;36m'     # ${Cyan}
#White='\e[0;37m'   # ${White}
Error='\e[41m'      # ${Error}
Off='\e[0m'         # ${Off}

ding(){ 
    printf \\a
}

# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    ding
    echo -e "${Error}ERROR${Off} This script must be run as sudo or root!"
    exit 1
fi

# Get NAS model
model=$(cat /proc/sys/kernel/syno_hw_version)
#modelname="$model"

# Show script version
#echo -e "$script $scriptver\ngithub.com/$repo\n"
echo "$script $scriptver"

# Get DSM full version
productversion=$(get_key_value /etc.defaults/VERSION productversion)
buildphase=$(get_key_value /etc.defaults/VERSION buildphase)
buildnumber=$(get_key_value /etc.defaults/VERSION buildnumber)
smallfixnumber=$(get_key_value /etc.defaults/VERSION smallfixnumber)

# Show DSM full version and model
if [[ $buildphase == GM ]]; then buildphase=""; fi
if [[ $smallfixnumber -gt "0" ]]; then smallfix="-$smallfixnumber"; fi
echo -e "$model DSM $productversion-$buildnumber$smallfix $buildphase\n"


# Get list of available volumes
for volume in /volume*; do  # Get list of available volumes
    # Ignore /volumeUSB# and /volume0
    if [[ $volume =~ /volume[1-9][0-9]?$ ]]; then
        # Ignore unmounted volumes
        if df -h | grep "$volume" >/dev/null ; then
            volumes+=("$volume")
        fi
    fi
done

# Check there is more than 1 volume
if [[ ! ${#volumes[@]} -gt 1 ]]; then
    ding
    echo -e "${Error}ERROR${Off} Only 1 volume found!"
    exit 1
fi


#------------------------------------------------------------------------------
# Get latest release info

# Curl timeout options:
# https://unix.stackexchange.com/questions/94604/does-curl-have-a-timeout
release=$(curl --silent -m 10 --connect-timeout 5 \
    "https://api.github.com/repos/$repo/releases/latest")

# Release version
tag=$(echo "$release" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
#shorttag="${tag:1}"

# Release published date
published=$(echo "$release" | grep '"published_at":' | sed -E 's/.*"([^"]+)".*/\1/')
published="${published:0:10}"
published=$(date -d "$published" '+%s')

if ! printf "%s\n%s\n" "$tag" "$scriptver" |
        sort --check=quiet --version-sort >/dev/null ; then
    echo -e "\n${Cyan}There is a newer version of this script available.${Off}"
    echo -e "Current version: ${scriptver}\nLatest version:  $tag"
fi


#------------------------------------------------------------------------------
# Functions

progbar(){ 
    # $1 is pid of process
    # $2 is string to echo
    local PROC
    local delay
    local dots
    local progress
    PROC="$1"
    delay="0.3"
    dots=""
    while [[ -d /proc/$PROC ]]; do
        dots="${dots}."
        progress="$dots"
        if [[ ${#dots} -gt "10" ]]; then
            dots=""
            progress="           "
        fi
        echo -ne "$2 $progress\r"; sleep "$delay"
    done
    echo -e "$2           "
    return 0
}

package_status(){ 
    # $1 is package name
    local code
    synopkg status "${1}" >/dev/null
    code="$?"  # 0 = started, 17 = stopped, 255 = not_installed
    if [[ $code == "0" ]]; then
        #echo "$1 is started"  # debug
        return 0
    elif [[ $code == "17" ]]; then
        #echo "$1 is stopped"  # debug
        return 1
    fi
}

package_stop(){ 
    # $1 is package name
    echo -e "Stopping ${Cyan}${1}${Off}..."
    synopkg stop "$1" >/dev/null
}

package_start(){ 
    # $1 is package name
    echo -e "Starting ${Cyan}${1}${Off}..."
    synopkg start "$1" >/dev/null
}

backup_pkg(){
    # $1 is folder to backup (@docker etc) 
    # $2 is volume (/volume1 etc)
    local perms

    # Make backup folder on $2
    if [[ ! -d "/${2}/${1}_backup" ]]; then
        # Set same permissions as original folder
        perms=$(stat -c %a "/${2}/${1}")
        mkdir -m "$perms" "/${2}/${1}_backup"
    fi

    # Backup $1
    if [[ -d "/${2}/${1}_backup" ]]; then
        echo -e "There appears to already be backup of ${pkg}"
        echo -e "Do you still want to backup ${pkg}? [y/n]"
        read -r answer
        echo ""
        if [[ ${answer,,} != "y" ]]; then
            return
        fi
    fi

    cp -rf "/${2}/${1}/." "/${2}/${1}_backup" &
    progbar $! "Backing up ${2}/$1 to ${Cyan}${2}/${1}_backup${Off}"
    echo ""
}

move_pkg(){ 
    # $1 is package name
    # $2 is destination volume
    local appdir
    local perms
    while read -r link source; do
        appdir=$(echo "$source" | cut -d "/" -f3)
        sourcevol=$(echo "$source" | cut -d "/" -f2)  # var is used later in script

        # Make target folder
        if [[ ! -d "${2}/$appdir" ]]; then
            # Set same permissions as original folder
            perms=$(stat -c %a "/${sourcevol}/$appdir")
            mkdir -m "$perms" "${2}/$appdir"
        fi

        # Move package
        mv "$source" "${2}/$appdir" &
        progbar $! "Moving $source to ${Cyan}$2${Off}"

        # Edit /var/packages symlinks
        case "$appdir" in
            @appconf)  # etc --> @appconf
                rm "/var/packages/${1}/etc"
                ln -s "${2}/@appconf/$1" "/var/packages/${1}/etc"
                ;;
            @apphome)  # home --> @apphome
                rm "/var/packages/${1}/home"
                ln -s "${2}/@apphome/$1" "/var/packages/${1}/home"
                ;;
            @appshare)  # share --> @appshare
                rm "/var/packages/${1}/share"
                ln -s "${2}/@appshare/$1" "/var/packages/${1}/share"
                ;;
            @appstore)  # target --> @appstore
                rm "/var/packages/${1}/target"
                ln -s "${2}/@appstore/$1" "/var/packages/${1}/target"
                ;;
            @apptemp)  # tmp --> @apptemp
                rm "/var/packages/${1}/tmp"
                ln -s "${2}/@apptemp/$1" "/var/packages/${1}/tmp"
                ;;
            @appdata)  # var --> @appdata
                rm "/var/packages/${1}/var"
                ln -s "${2}/@appdata/$1" "/var/packages/${1}/var"
                ;;
            *)
                echo -e "${Red}Oops!${Off} $appdir"
                return
                ;;
        esac
    done < <(find . -maxdepth 2 -type l -ls | grep "$1" | awk '{print $(NF-2), $NF}')
}

move_docker(){ 
    # $1 is source volume
    # $2 is destination volume
    local source
    local perms

    # Backup @docker
    echo -e "Do you want to backup ${pkg}? [y/n]"
    read -r answer
    echo ""
    if [[ ${answer,,} == "y" ]]; then
        # $1 is folder to backup (@docker etc) 
        # $2 is package volume (volume1 etc)
        backup_pkg "@docker" "${1}"
    fi

    source="${1}/@docker"
    echo -e "Moving $source to ${Cyan}$2${Off}"
    sourcevol=$(echo "$source" | cut -d "/" -f2)  # var is used later in script

    # Create target folder
    if [[ ! -d "${2}/@docker" ]]; then
        # Set same permissions as original folder
        perms=$(stat -c %a "/${sourcevol}/@docker")
        mkdir -m "$perms" "${2}/@docker"
    fi

    # Move @docker
    for i in "$source"/*; do
        if [[ -d "${i}" ]]; then
            mv "${i}" "${2}/@docker" &
            progbar $! "Moving $i to ${Cyan}$2${Off}"
        else
            echo -e "${Yellow}Warning${Off} $source is empty"
        fi
    done

    # Fix symlink if DSM 7
    if [[ -L "${2}/@docker/@docker" ]]; then
        rm "${2}/@docker/@docker"
        ln -s "${2}/@docker" "${2}/@docker"
    fi
}

folder_size(){
    # $1 is folder to check size of
    needed=""  # var is used later in script
    if [[ -d "$1" ]]; then
        # Get size of $1 folder
        needed=$(du -s "$1" | awk '{ print $1 }')
        # Add 50GB
        needed=$((needed +50000000))
    fi
}

vol_free_space(){
    # $1 is volume to check free space
    free=""  # var is used later in script
    if [[ -d "$1" ]]; then
        # Get amount of free space on $1 volume
        free=$(df --output=avail "$1" | grep -A1 Avail | grep -v Avail)
    fi
}

show_move_share(){ 
    # $1 is share name
    echo -e "\nIf you want to move your $1 shared folder to $targetvol"
    echo "  1. Go to 'Control Panel > Shared Folders'."
    echo "  2. Select your $pkg shared folder and click Edit."
    echo "  3. Change Location to $targetvol and click Save."
    echo -e "  4. After step 3 has finished start $pkg from Package Center.\n"
    # Allow starting package now
    echo -e "Or do you want to start $pkg now? [y/n]"
    read -r answer
    echo ""
    if [[ ${answer,,} != "y" ]]; then
        exit  # Skip starting package
    fi
}


#------------------------------------------------------------------------------
# Select package

if ! cd /var/packages; then 
    ding
    echo -e "${Error}ERROR${Off} cd to /var/packages failed!"
    exit 1
fi

# Add non-system packages to array
package_infos=( )
while read -r link target; do
    package="$(printf %s "$link" | cut -d'/' -f2 )"
    package_volume="$(printf %s "$target" | cut -d'/' -f1,2 )"
    if [[ ! ${package_infos[*]} =~ "${package_volume}|${package}" ]]; then
        package_infos+=("${package_volume}|${package}")
    fi
done < <(find . -maxdepth 2 -type l -ls | grep volume | awk '{print $(NF-2), $NF}')

# Sort array
IFS=$'\n' package_infos_sorted=($(sort <<<"${package_infos[*]}")); unset IFS

# Select package to move
echo "[Installed package list]"
for ((i=1; i<=${#package_infos_sorted[@]}; i++)); do
    info="${package_infos_sorted[i-1]}"
    before_pipe="${info%%|*}"
    after_pipe="${info#*|}"
    printf "%-5s %-15s %s\n" "$i)" "$before_pipe" "$after_pipe"
done

if [[ ${#package_infos_sorted[@]} -eq 0 ]]; then
    echo "No movable packages found!" && exit 1
fi

# Parse selected element of array
read -rp "Select the package to move: " choice
IFS="|" read -r package_volume pkg <<< "${package_infos_sorted[choice-1]}"

echo -e "You selected ${Cyan}${pkg}${Off} in ${Cyan}${package_volume}${Off}\n"
target=$(readlink "/var/packages/${pkg}/target")
linktargetvol="/$(printf %s "$target" | cut -d'/' -f2 )"

#------------------------------------------------------------------------------
# Select volume

# Get list of available volumes
volumes=( )
for volume in /volume*; do
    # Ignore /volumeUSB# and /volume0
    if [[ $volume =~ /volume[1-9][0-9]?$ ]]; then
        # Skip volume package is currently installed on
        if [[ $volume != "$linktargetvol" ]]; then
            # Ignore unmounted volumes
            if df -h | grep "$volume" >/dev/null ; then
                volumes+=("$volume")
            fi
        fi
    fi
done

# Select destination volume
if [[ ${#volumes[@]} -ge 1 ]]; then
    PS3="Select the destination volume: "
    select targetvol in "${volumes[@]}"; do
        if [[ $targetvol ]]; then
            if [[ -d $targetvol ]]; then
                echo -e "You selected ${Cyan}${targetvol}${Off}\n"
                break
            else
                ding
                echo -e "${Error}ERROR${Off} $targetvol not found!"
                exit 1
            fi
        else
            echo "Invalid choice!"
        fi
    done
else
    ding
    echo -e "${Error}ERROR${Off} Only 1 volume found!"
    exit 1
fi


#------------------------------------------------------------------------------
# Move the package

echo -e "Ready to move ${Cyan}${pkg}${Off} to ${Cyan}${targetvol}${Off}? [y/n]"
read -r answer
echo ""
if [[ ${answer,,} != y ]]; then
    exit
fi

# Stop package if running
if package_status "$pkg"; then
    package_stop "$pkg"
fi

# Check package stopped
if ! package_status "$pkg"; then
    echo -e "$pkg is stopped\n"
else
    ding
    echo -e "${Error}ERROR${Off} Failed to stop ${pkg}!"
    exit 1
fi

# Move package and edit symlinks
move_pkg "$pkg" "$targetvol"
echo ""


#------------------------------------------------------------------------------
# Move @docker if package is ContainerManager or Docker

if [[ "$pkg" == "ContainerManager" ]] || [[ "$pkg" == "Docker" ]]; then
    # Check if @docker is on same volume as Docker package
    if [[ -d "/${sourcevol}/@docker" ]]; then
        # Get size of @docker folder
        folder_size "/${sourcevol}/@docker"

        # Get amount of free space on target volume
        vol_free_space "${targetvol}"

        # Check we have enough space
        if [[ ! $free -gt $needed ]]; then
            echo -e "Not enough space to move /${sourcevol}/@docker to $targetvol"
        else
            move_docker "/$sourcevol" "$targetvol"
            # Show how to move docker share
            show_move_share docker
        fi
    fi
fi


#------------------------------------------------------------------------------
# Suggest moving PlexMediaServer share if package is Plex

if [[ "$pkg" =~ Plex.*Media.*Server ]]; then
    # Show how to move Plex share
    show_move_share "$pkg"
fi


#------------------------------------------------------------------------------
# Suggest moving PlexMediaServer share if package is Plex

if [[ "$pkg" =~ Plex.*Media.*Server ]]; then
    # Show how to move Plex share
    show_move_share "$pkg"
fi


#------------------------------------------------------------------------------
# Finished

echo -e "Do you want to start $pkg now? [y/n]"
read -r answer
echo ""
if [[ ${answer,,} != "y" ]]; then
    exit  # Skip starting package
fi

# Start package
package_start "$pkg"

# Check package started
if package_status "$pkg"; then
    echo -e "$pkg is running\n"
else
    ding
    echo -e "${Error}ERROR${Off} Failed to start ${pkg}!"
    exit 1
fi

exit

