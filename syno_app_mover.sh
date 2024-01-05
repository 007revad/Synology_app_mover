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

scriptver="v1.0.3"
script=Synology_app_mover
repo="007revad/Synology_app_mover"
scriptname=syno_app_mover


# Shell Colors
#Black='\e[0;30m'   # ${Black}
Red='\e[0;31m'      # ${Red}
#Green='\e[0;32m'   # ${Green}
#Yellow='\e[0;33m'  # ${Yellow}
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
shorttag="${tag:1}"

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

package_status(){ 
    # $1 is package name
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
    package_status "$1"
}

package_start(){ 
    # $1 is package name
    echo -e "Starting ${Cyan}${1}${Off}..."
    synopkg start "$1" >/dev/null
    # Wait for package to start
    package_status "$1"
}

move_pkg(){ 
    # $1 is package name
    # $2 is destination volume
    while read -r link source; do

        #echo "link: $link"      # debug
        #echo "source: $source"  # debug

        appdir=$(echo "$source" | cut -d "/" -f3)
        echo -e "Moving $source to ${Cyan}$2${Off}"

        sourcevol=$(echo "$source" | cut -d "/" -f2)
        destination="${2}/${source#/"${sourcevol}"/}"

        if [[ ! -d "${targetvol}/$appdir" ]]; then
            mkdir "${targetvol}/$appdir"
        fi

        chmod 755 "${targetvol}/$appdir"

        mv "$source" "${targetvol}/$appdir"

        # Edit symlinks
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


#------------------------------------------------------------------------------
# Select package

if ! cd /var/packages; then 
    ding
    echo -e "${Error}ERROR${Off} cd to /var/packages failed!"
    exit 1
fi

packages=( )
while read -r link target; do
    package="$(printf %s "$link" | cut -d'/' -f2 )"
    if [[ ! ${packages[*]} =~ ${package}$ ]]; then
        packages+=("$package")
    fi
done < <(find . -type l -ls | grep volume | awk '{print $(NF-2), $NF}')

# Sort array
IFS=$'\n'
packagessorted=($(sort <<<"${packages[*]}"))
unset IFS


# Select package to move
if [[ ${#packagessorted[@]} -gt 0 ]]; then
    PS3="Select the package to move: "
    select pkg in "${packagessorted[@]}"; do
        echo -e "You selected ${Cyan}${pkg}${Off}\n"
        target=$(readlink "/var/packages/${pkg}/target")
        linktargetvol="/$(printf %s "$target" | cut -d'/' -f2 )"
        break
    done
else
    echo "No movable packages found!" && exit 1
fi


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
    # Let user select target volume
    PS3="Select the destination volume: "
    select targetvol in "${volumes[@]}"; do
        if [[ -d $targetvol ]]; then
            echo -e "You selected ${Cyan}${targetvol}${Off}\n"
            break
        else
            ding
            echo -e "${Error}ERROR${Off} $targetvol not found!"
            exit 1
        fi
    done
else
    ding
    echo -e "${Error}ERROR${Off} Only 1 volume found!"
    exit 1
fi


#------------------------------------------------------------------------------
# Move the package

echo "Ready to move $pkg to ${targetvol}? [y/n]"
read -r answer
echo ""
if [[ ${answer,,} != y ]]; then
    exit 1
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

