#!/usr/bin/env bash
# shellcheck disable=SC2076,SC2207
#------------------------------------------------------------------------------
# Easily move Synology packages from one volume to another volume.
# Also can backup and restore packages.
#
# Github: https://github.com/007revad/Synology_app_mover
# Script verified at https://www.shellcheck.net/
#
# To run in a shell (replace /volume1/scripts/ with path to script):
# sudo -s /volume1/scripts/syno_app_mover.sh
#------------------------------------------------------------------------------
#
# Cannot uninstall packages with dependers 
# "failed to uninstall a package who has dependers installed"
#
# TODO
# Add warning that processing extra folder can take a long while.
#
# Add volume space check for all extras folders.
#  Should check the volume space BEFORE moving or backing up package.
#
# Add timeout to stopping, and starting, packages.
#
#
# DONE Get package display name from package's INFO file.
# DONE Added Synology Calendar's '@calendar' folder.
# DONE Added Download Station's '@downloads' folder.
#
# DONE Added support to backup/restore ActiveBackup
# DONE Check all PS3 sections validate choice.
#
# DONE Added support to backup/restore ContainerManager/Docker
# DONE Added check that installed package version matches backup version
#
# DONE Added backup and restore modes
# DONE Only start package if we stopped it
# DONE Check exit status of package uninstall and install
# DONE Added syno_app_mover.conf file for setting backup location
# DONE Change so when progress bar showing cursor doesn't cover first letter
# DONE Confirm folder was created when creating folder
# DONE Copy files/folders with same permissions when using cp command
# DONE Change package selection to avoid invalid key presses
# DONE Bug fix when script updates itself and user ran the script from ./scriptname.sh


scriptver="v3.0.16"
script=Synology_app_mover
repo="007revad/Synology_app_mover"
scriptname=syno_app_mover


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

# Save options used
args=("$@")


if [[ $1 == "--debug" ]] || [[ $1 == "-d" ]]; then
    set -x
    export PS4='`[[ $? == 0 ]] || echo "\e[1;31;40m($?)\e[m\n "`LINE $LINENO '
fi

if [[ ${1,,} == "--fix" ]]; then
    # Bypass exit if dependant package failed to stop
    # For restoring broken package to original volume
    fix="yes"
fi

# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    ding
    echo -e "${Error}ERROR${Off} This script must be run as sudo or root!"
    exit 1
fi

# Check script is running on a Synology NAS
if ! /usr/bin/uname -a | grep -i synology >/dev/null; then
    echo "This script is NOT running on a Synology NAS!"
    echo "Copy the script to a folder on the Synology"
    echo "and run it from there."
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
majorversion=$(get_key_value /etc.defaults/VERSION majorversion)

# Show DSM full version and model
if [[ $buildphase == GM ]]; then buildphase=""; fi
if [[ $smallfixnumber -gt "0" ]]; then smallfix="-$smallfixnumber"; fi
echo -e "$model DSM $productversion-$buildnumber$smallfix $buildphase\n"


#------------------------------------------------------------------------------
# Check latest release with GitHub API

# Get latest release info
# Curl timeout options:
# https://unix.stackexchange.com/questions/94604/does-curl-have-a-timeout
release=$(curl --silent -m 10 --connect-timeout 5 \
    "https://api.github.com/repos/$repo/releases/latest")

# Release version
tag=$(echo "$release" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
shorttag="${tag:1}"

# Get script location
# https://stackoverflow.com/questions/59895/
source=${BASH_SOURCE[0]}
while [ -L "$source" ]; do # Resolve $source until the file is no longer a symlink
    scriptpath=$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )
    source=$(readlink "$source")
    # If $source was a relative symlink, we need to resolve it
    # relative to the path where the symlink file was located
    [[ $source != /* ]] && source=$scriptpath/$source
done
scriptpath=$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )
scriptfile=$( basename -- "$source" )
echo "Running from: ${scriptpath}/$scriptfile"

#echo "Script location: $scriptpath"  # debug
#echo "Source: $source"               # debug
#echo "Script filename: $scriptfile"  # debug

#echo "tag: $tag"              # debug
#echo "scriptver: $scriptver"  # debug


cleanup_tmp(){ 
    # Delete downloaded .tar.gz file
    if [[ -f "/tmp/$script-$shorttag.tar.gz" ]]; then
        if ! rm "/tmp/$script-$shorttag.tar.gz"; then
            echo -e "${Error}ERROR${Off} Failed to delete"\
                "downloaded /tmp/$script-$shorttag.tar.gz!" >&2
        fi
    fi

    # Delete extracted tmp files
    if [[ -d "/tmp/$script-$shorttag" ]]; then
        if ! rm -r "/tmp/$script-$shorttag"; then
            echo -e "${Error}ERROR${Off} Failed to delete"\
                "downloaded /tmp/$script-$shorttag!" >&2
        fi
    fi
}


if ! printf "%s\n%s\n" "$tag" "$scriptver" |
        sort --check=quiet --version-sort >/dev/null ; then
    echo -e "\n${Cyan}There is a newer version of this script available.${Off}"
    echo -e "Current version: ${scriptver}\nLatest version:  $tag"
    scriptdl="$scriptpath/$script-$shorttag"
    if [[ -f ${scriptdl}.tar.gz ]] || [[ -f ${scriptdl}.zip ]]; then
        # They have the latest version tar.gz downloaded but are using older version
        echo "You have the latest version downloaded but are using an older version"
        sleep 10
    elif [[ -d $scriptdl ]]; then
        # They have the latest version extracted but are using older version
        echo "You have the latest version extracted but are using an older version"
        sleep 10
    else
        echo -e "${Cyan}Do you want to download $tag now?${Off} [y/n]"
        read -r -t 30 reply
        if [[ ${reply,,} == "y" ]]; then
            # Delete previously downloaded .tar.gz file and extracted tmp files
            cleanup_tmp

            if cd /tmp; then
                url="https://github.com/$repo/archive/refs/tags/$tag.tar.gz"
                if ! curl -JLO -m 30 --connect-timeout 5 "$url"; then
                    echo -e "${Error}ERROR${Off} Failed to download"\
                        "$script-$shorttag.tar.gz!"
                else
                    if [[ -f /tmp/$script-$shorttag.tar.gz ]]; then
                        # Extract tar file to /tmp/<script-name>
                        if ! tar -xf "/tmp/$script-$shorttag.tar.gz" -C "/tmp"; then
                            echo -e "${Error}ERROR${Off} Failed to"\
                                "extract $script-$shorttag.tar.gz!"
                        else
                            # Set script sh files as executable
                            if ! chmod a+x "/tmp/$script-$shorttag/"*.sh ; then
                                permerr=1
                                echo -e "${Error}ERROR${Off} Failed to set executable permissions"
                            fi

                            # Copy new script sh file to script location
                            if ! cp -p "/tmp/$script-$shorttag/${scriptname}.sh" "${scriptpath}/${scriptfile}";
                            then
                                copyerr=1
                                echo -e "${Error}ERROR${Off} Failed to copy"\
                                    "$script-$shorttag sh file(s) to:\n $scriptpath/${scriptfile}"
                            fi

                            # Copy script's conf file to script location if missing
                            if [[ ! -f "$scriptpath/${scriptname}.conf" ]]; then
                                # Set persmission on config file
                                if ! chmod 664 "/tmp/$script-$shorttag/${scriptname}.conf"; then
                                    permerr=1
                                    echo -e "${Error}ERROR${Off} Failed to set read/write permissions on:"
                                    echo "$scriptpath/${scriptname}.conf"
                                fi

                                # Copy conf file to script location
                                if ! cp -p "/tmp/$script-$shorttag/${scriptname}.conf"\
                                    "${scriptpath}/${scriptname}.conf"; then
                                    copyerr=1
                                    echo -e "${Error}ERROR${Off} Failed to copy"\
                                        "$script-$shorttag conf file to:\n $scriptpath/${scriptname}.conf"
                                else
                                    conftxt=", ${scriptname}.conf"
                                fi
                            fi

                            # Copy new CHANGES.txt file to script location (if script on a volume)
                            if [[ $scriptpath =~ /volume* ]]; then
                                # Set permsissions on CHANGES.txt
                                if ! chmod 664 "/tmp/$script-$shorttag/CHANGES.txt"; then
                                    permerr=1
                                    echo -e "${Error}ERROR${Off} Failed to set read/write permissions on:"
                                    echo "$scriptpath/CHANGES.txt"
                                fi

                                # Copy new CHANGES.txt file to script location
                                if ! cp -p "/tmp/$script-$shorttag/CHANGES.txt"\
                                    "${scriptpath}/${scriptname}_CHANGES.txt"; then
                                    echo -e "${Error}ERROR${Off} Failed to copy"\
                                        "$script-$shorttag/CHANGES.txt to:\n $scriptpath"
                                else
                                    changestxt=" and changes.txt"
                                fi
                            fi

                            # Delete downloaded tmp files
                            cleanup_tmp

                            # Notify of success (if there were no errors)
                            if [[ $copyerr != 1 ]] && [[ $permerr != 1 ]]; then
                                echo -e "\n$tag ${scriptfile}$conftxt$changestxt downloaded to: ${scriptpath}\n"

                                # Reload script
                                printf -- '-%.0s' {1..79}; echo  # print 79 -
                                exec "${scriptpath}/$scriptfile" "${args[@]}"
                            fi
                        fi
                    else
                        echo -e "${Error}ERROR${Off}"\
                            "/tmp/$script-$shorttag.tar.gz not found!"
                        #ls /tmp | grep "$script"  # debug
                    fi
                fi
                cd "$scriptpath" || echo -e "${Error}ERROR${Off} Failed to cd to script location!"
            else
                echo -e "${Error}ERROR${Off} Failed to cd to /tmp!"
            fi
        fi
    fi
fi

conffile="${scriptpath}/${scriptname}.conf"


#------------------------------------------------------------------------------
# Functions

# shellcheck disable=SC2317  # Don't warn about unreachable commands in this function
pause(){ 
    # When debugging insert pause command where needed
    read -s -r -n 1 -p "Press any key to continue..."
    read -r -t 0.1 -s -e --  # Silently consume all input
    stty echo echok  # Ensure read didn't disable echoing user input
    echo -e "\n"
}

# shellcheck disable=SC2317  # Don't warn about unreachable commands in this function
debug(){ 
    if [[ $1 == "on" ]]; then
        set -x
        export PS4='`[[ $? == 0 ]] || echo "\e[1;31;40m($?)\e[m\n "`LINE $LINENO '
    elif [[ $1 == "off" ]]; then
        set +x
    fi
}

progbar(){ 
    # $1 is pid of process
    # $2 is string to echo
    string="$2"
    local dots
    local progress
    dots=""
    while [[ -d /proc/$1 ]]; do
        dots="${dots}."
        progress="$dots"
        if [[ ${#dots} -gt "10" ]]; then
            dots=""
            progress="           "
        fi
        echo -ne "  ${2}$progress\r"; sleep 0.3
    done
}

progstatus(){ 
    # $1 is return status of process
    # $2 is string to echo
    if [[ $1 == "0" ]]; then
        echo -e "$2            "
    else
        ding
        echo -e "${Error}ERROR${Off} $2 failed!"
        if [[ $exitonerror != "no" ]]; then
            exit 1
        fi
    fi
    exitonerror=""
    #echo "return: $1"  # debug
}

package_status(){ 
    # $1 is package name
    local code
    synopkg status "${1}" >/dev/null
    code="$?"  # 0 = started, 17 = stopped, 255 = not_installed, 150 = broken
    if [[ $code == "0" ]]; then
        #echo "$1 is started"  # debug
        return 0
    elif [[ $code == "17" ]]; then
        #echo "$1 is stopped"  # debug
        return 1
    elif [[ $code == "255" ]]; then
        #echo "$1 is not installed"  # debug
        return 255
    elif [[ $code == "150" ]]; then
        #echo "$1 is broken"  # debug
        return 150
    else
        return "$code"
    fi
}

wait_status(){ 
    # Wait for package to finish stopping or starting
    # $1 is package
    # $2 is start or stop
    if [[ $2 == "start" ]]; then
        state="0"
    elif [[ $2 == "stop" ]]; then
        state="1"
    fi
    if [[ $state == "0" ]] || [[ $state == "1" ]]; then
        num="0"
        package_status "$1"
        while [[ $? != "$state" ]]; do
            sleep 1
            num=$((num +1))
            if [[ $num -gt "20" ]]; then
                break
            fi
            package_status "$1"
        done
    fi
}

package_stop(){ 
    # $1 is package name
    # $2 is package display name
    local num
    synopkg stop "$1" >/dev/null &
    pid=$!
    string="Stopping ${Cyan}${2}${Off}"
    progbar $pid "$string"
    wait "$pid"
    progstatus "$?" "$string"

    # Allow package processes to finish stopping
    wait_status "$1" stop
    #sleep 1
}

package_start(){ 
    # $1 is package name
    # $2 is package display name
    synopkg start "$1" >/dev/null &
    pid=$!
    string="Starting ${Cyan}${2}${Off}"
    progbar $pid "$string"
    wait "$pid"
    progstatus "$?" "$string"

    # Allow package processes to finish starting
    wait_status "$1" start
}

dependant_pkgs_stop(){ 
    if [[ ${#dependants[@]} -gt "0" ]]; then
        echo "Stopping dependant packages"
        for d in "${dependants[@]}"; do
            d_name="$(synogetkeyvalue "/var/packages/${d}/INFO" displayname)"
            if package_status "$d"; then
                # Get list of dependers that were running
                dependants2start+=( "$d" )
                package_stop "$d" "$d_name"

                # Check packaged stopped
                if package_status "$d"; then
                    ding
                    echo -e "${Error}ERROR${Off} Failed to stop ${d_name}!"
                    # If $fix = yes bypass exit for restoring to orig vol
                    if [[ $fix != "yes" ]]; then
                        exit 1
                    fi
                fi
            fi
        done
        echo ""
    fi
}

dependant_pkgs_start(){ 
    # Only start dependers that were running
    if [[ ${#dependants2start[@]} -gt "0" ]]; then
        #sleep 5  # Allow main package processes to finish starting
        echo "Starting dependant packages"
        for d in "${dependants2start[@]}"; do
            d_name="$(synogetkeyvalue "/var/packages/${d}/INFO" displayname)"
            package_start "$d" "$d_name"

            # Check packaged started
            if ! package_status "$d"; then
                echo -e "${Error}ERROR${Off} Failed to start ${d_name}!"
            fi
        done
        echo ""
    fi
}

# shellcheck disable=SC2317  # Don't warn about unreachable commands in this function
package_uninstall(){ 
    # $1 is package name
    synopkg uninstall "$1" >/dev/null &
    pid=$!
    string="Uninstalling ${Cyan}${1}${Off}"
    progbar "$pid" "$string"
    wait "$pid"
    progstatus "$?" "$string"
}

# shellcheck disable=SC2317  # Don't warn about unreachable commands in this function
package_install(){ 
    # $1 is package name
    # $2 is /volume2 etc
    synopkg install_from_server "$1" "$2" >/dev/null &
    pid=$!
    string="Installing ${Cyan}${1}${Off} on ${Cyan}$2${Off}"
    progbar "$pid" "$string"
    wait "$pid"
    progstatus "$?" "$string"
}

is_empty(){ 
    # $1 is /path/folder
    if [[ -d $1 ]]; then
        local contents
        contents=$(find "$1" -maxdepth 1 -printf '.')
        if [[ ${#contents} -gt 1 ]]; then
            return 1  # Not empty
        fi
    fi
}

backup_dir(){ 
    # $1 is folder to backup (@docker etc) 
    # $2 is volume (/volume1 etc)
    local perms
    if  [[ -d "$2/$1" ]]; then

        # Make backup folder on $2
        if [[ ! -d "${2}/${1}_backup" ]]; then
            # Set same permissions as original folder
            perms=$(stat -c %a "${2:?}/${1:?}")
            if ! mkdir -m "$perms" "${2:?}/${1:?}_backup"; then
                ding
                echo -e "${Error}ERROR${Off} Failed to create directory!"
                exit 1
            fi
        fi

        # Backup $1
        if ! is_empty "${2:?}/${1:?}_backup"; then
            # @docker_backup folder exists and is not empty
            echo -e "There is already a backup of $1"
            echo -e "Do you want to overwrite it? [y/n]"
            read -r answer
            echo ""
            if [[ ${answer,,} != "y" ]]; then
                return
            fi
        fi

        cp -prf "${2:?}/${1:?}/." "${2:?}/${1:?}_backup" &
        pid=$!
        # If string is too long progbar repeats string for each dot
        string="Backing up $1 to ${Cyan}${1}_backup${Off}"
        progbar $pid "$string"
        wait "$pid"
        progstatus "$?" "$string"
        echo ""
    fi
}

cdir(){ 
    # $1 is path to cd to
    if ! cd "$1"; then
        ding
        echo -e "${Error}ERROR${Off} cd to $1 failed!"
        exit 1
    fi
}

create_dir(){ 
    # $1 is source /path/folder
    # $2 is target /path/folder

    # Create target folder with source folder's permissions
    if [[ ! -d "$2" ]]; then
        # Set same permissions as original folder
        perms=$(stat -c %a "${1:?}")
        if ! mkdir -m "$perms" "${2:?}"; then
            ding
            echo -e "${Error}ERROR${Off} Failed to create directory!"
            exit 1
        fi
    fi
}

move_pkg_do(){ 
    # $1 is package name
    # $2 is destination volume or path

    # Move package's @app directories
    if [[ ${mode,,} == "move" ]]; then
        #mv -f "${source:?}" "${2:?}/${appdir:?}" &
        #pid=$!
        #string="${action} $source to ${Cyan}$2${Off}"
        #progbar $pid "$string"
        #wait "$pid"
        #progstatus "$?" "$string"

        if [[ ! -d "${2:?}/${appdir:?}/${1:?}" ]] ||\
            is_empty "${2:?}/${appdir:?}/${1:?}"; then

            # Move source folder to target folder
            mv -f "${source:?}" "${2:?}/${appdir:?}" &
            pid=$!
            string="${action} $source to ${Cyan}$2${Off}"
            progbar $pid "$string"
            wait "$pid"
            progstatus "$?" "$string"
        else
            # Copy source contents if target folder exists
            cp -prf "${source:?}" "${2:?}/${appdir:?}" &
            pid=$!
            string="Copying $source to ${Cyan}$2${Off}"
            progbar $pid "$string"
            wait "$pid"
            progstatus "$?" "$string"

            #rm -rf "${source:?}" &
            rm -r --preserve-root "${source:?}" &
            pid=$!
            exitonerror="no"
            string="Removing $source"
            progbar $pid "$string"
            wait "$pid"
            progstatus "$?" "$string"
        fi
    else
#        if ! is_empty "${destination:?}/${appdir:?}/${1:?}"; then
#            echo "Skipping ${action,,} ${appdir}/$1 as target is not empty:"
#            echo "  ${destination}/${appdir}/$1"
#        else
            #mv -f "${source:?}" "${2:?}/${appdir:?}" &
            #pid=$!
            #string="${action} $source to ${Cyan}$2${Off}"
            #progbar $pid "$string"
            #wait "$pid"
            #progstatus "$?" "$string"
            move_dir "$appdir"
#        fi
    fi
}

edit_symlinks(){ 
    # $1 is package name
    # $2 is destination volume

    # Edit /var/packages symlinks
    case "$appdir" in
        @appconf)  # etc --> @appconf
            rm "/var/packages/${1:?}/etc"
            ln -s "${2:?}/@appconf/${1:?}" "/var/packages/${1:?}/etc"

            # /usr/syno/etc/packages/$1
            # /volume1/@appconf/$1
            if [[ -L "/usr/syno/etc/packages/${1:?}" ]]; then
                rm "/usr/syno/etc/packages/${1:?}"
                ln -s "${2:?}/@appconf/${1:?}" "/usr/syno/etc/packages/${1:?}"
            fi
            ;;
        @apphome)  # home --> @apphome
            rm "/var/packages/${1:?}/home"
            ln -s "${2:?}/@apphome/${1:?}" "/var/packages/${1:?}/home"
            ;;
        @appshare)  # share --> @appshare
            rm "/var/packages/${1:?}/share"
            ln -s "${2:?}/@appshare/${1:?}" "/var/packages/${1:?}/share"
            ;;
        @appstore)  # target --> @appstore
            rm "/var/packages/${1:?}/target"
            ln -s "${2:?}/@appstore/${1:?}" "/var/packages/${1:?}/target"
            ;;
        @apptemp)  # tmp --> @apptemp
            rm "/var/packages/${1:?}/tmp"
            ln -s "${2:?}/@apptemp/${1:?}" "/var/packages/${1:?}/tmp"
            ;;
        @appdata)  # var --> @appdata
            rm "/var/packages/${1:?}/var"
            ln -s "${2:?}/@appdata/${1:?}" "/var/packages/${1:?}/var"
            ;;
        *)
            echo -e "${Red}Oops!${Off} appdir: ${appdir}\n"
            return
            ;;
    esac
}

move_pkg(){ 
    # $1 is package name
    # $2 is destination volume
    local appdir
    local perms
    local destination
    if [[ ${mode,,} == "backup" ]]; then
        destination="$bkpath"
        #cdir /var/packages
    elif [[ ${mode,,} == "restore" ]]; then
        destination="$2"
        #cdir "$bkpath"
    else
        destination="$2"
        #cdir /var/packages
    fi    

    if [[ $majorversion -gt 6 ]]; then
        applist=( "@appconf" "@appdata" "@apphome" "@appshare" "@appstore" "@apptemp" )
    else
        applist=( "@appstore" )
    fi
    if [[ ${mode,,} == "restore" ]]; then
        cdir "$bkpath"
        sourcevol=$(echo "$bkpath" | cut -d "/" -f2)  # var is used later in script
        while IFS=  read -r appdir; do
            if [[ "${applist[*]}" =~ "$appdir" ]]; then
                appdirs_tmp+=("$appdir")
            fi
        done < <(find . -name "@app*" -exec basename \{} \;)

        # Sort array
        IFS=$'\n' appdirs=($(sort <<<"${appdirs_tmp[*]}")); unset IFS

        if [[ ${#appdirs[@]} -gt 0 ]]; then
            for appdir in "${appdirs[@]}"; do
                create_dir "/${sourcevol:?}/${appdir:?}" "${destination:?}/${appdir:?}"
                move_pkg_do "$1" "$destination"
            done
        fi
    else
        cdir /var/packages
        while read -r link source; do
            app_paths_tmp+=("$source")
        done < <(find . -maxdepth 2 -type l -ls | grep "$1"'$' | awk '{print $(NF-2), $NF}')

        # Sort array
        IFS=$'\n' app_paths=($(sort <<<"${app_paths_tmp[*]}")); unset IFS

        if [[ ${#app_paths[@]} -gt 0 ]]; then
            for source in "${app_paths[@]}"; do
                appdir=$(echo "$source" | cut -d "/" -f3)
                sourcevol=$(echo "$source" | cut -d "/" -f2)  # var is used later in script
                create_dir "/${sourcevol:?}/${appdir:?}" "${destination:?}/${appdir:?}"
                move_pkg_do "$1" "$2"
                if [[ ${mode,,} == "move" ]]; then
                    edit_symlinks "$pkg" "$destination"
                fi
            done
        fi
    fi
}

folder_size(){ 
    # $1 is folder to check size of
    need=""    # var is used later in script
    needed=""  # var is used later in script
    if [[ -d "$1" ]]; then
        # Get size of $1 folder
        need=$(du -s "$1" | awk '{ print $1 }')
        # Add 50GB so we don't fill volume
        needed=$((need +50000000))
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
    # $1 is package name
    # $2 is share name
    echo -e "\nIf you want to move your $2 shared folder to $targetvol"
    echo "  While $1 is stopped:"
    echo "  1. Go to 'Control Panel > Shared Folders'."
    echo "  2. Select your $2 shared folder and click Edit."
    echo "  3. Change Location to $targetvol and click Save."
    echo "    - If $1 has more shared folders repeat steps 2 and 3."
    #echo -e "  4. After step 3 has finished start $1 from Package Center.\n"
    echo -e "  4. After step 3 has finished start $1 \n"
}

copy_dir(){ 
    # Used by package backup and restore

    # $1 is folder (@surveillance etc)
    # $2 is "extras" or null
    local pack
    local extras
    if [[ $2 == "extras" ]]; then
        #pack=""
        extras="/extras"
    else
        pack="/${pkg:?}"
        #extras=""
    fi

    if [[ ${mode,,} == "backup" ]]; then
        if  [[ $2 == "extras" ]] && [[ ! -d "${bkpath:?}/extras" ]]; then
            mkdir -m 700 "${bkpath:?}/extras"
        fi
        create_dir "/${sourcevol:?}/${1:?}$pack" "${bkpath:?}${extras}/${1:?}"
        #if ! is_empty "/${sourcevol:?}/${1:?}$pack"; then
            if  [[ $2 == "extras" ]]; then
                # If string is too long progbar gets messed up
                cp -prf "/${sourcevol:?}/${1:?}$pack" "${bkpath:?}${extras}" &
                pid=$!
                string="${action} /${sourcevol}/${1}/${Cyan}$pkg${Off}"
                progbar $pid "$string"
                wait "$pid"
                progstatus "$?" "$string"
            else
                # If string is too long progbar gets messed up
                cp -prf "/${sourcevol:?}/${1:?}$pack" "${bkpath:?}${extras}/${1:?}" &
                pid=$!
                string="${action} /${sourcevol}/${1}/${Cyan}$pkg${Off}"
                progbar $pid "$string"
                wait "$pid"
                progstatus "$?" "$string"
            fi
        #fi
    elif [[ ${mode,,} == "restore" ]]; then
        #if [[ -d "${bkpath}/$1" ]]; then
            # If string is too long progbar gets messed up
            #cp -prf "${bkpath}/$1" "${targetvol}" &
            cp -prf "${bkpath:?}${extras}/${1:?}" "${targetvol:?}" &
            pid=$!
            string="${action} ${Cyan}$1${Off} to $targetvol"
            progbar $pid "$string"
            wait "$pid"
            progstatus "$?" "$string"
        #fi
    fi
}

move_dir(){ 
    # $1 is folder (@surveillance etc)
    # $2 is "extras" or null
    if [[ ${mode,,} == "move" ]]; then
        if [[ ! -d "/${targetvol:?}/${1:?}" ]]; then
            mv -f "/${sourcevol:?}/${1:?}" "${targetvol:?}/${1:?}" &
            pid=$!
            string="${action} /${sourcevol}/$1 to ${Cyan}$targetvol${Off}"
            progbar $pid "$string"
            wait "$pid"
            progstatus "$?" "$string"
        elif ! is_empty "/${sourcevol:?}/${1:?}"; then

            # Copy source contents if target folder exists
            cp -prf "/${sourcevol:?}/${1:?}" "${targetvol:?}" &
            pid=$!
            string="Copying /${sourcevol}/$1 to ${Cyan}$targetvol${Off}"
            progbar $pid "$string"
            wait "$pid"
            progstatus "$?" "$string"

            # Delete source folder if empty
#            if [[ $1 != "@docker" ]]; then
                if is_empty "/${sourcevol:?}/${1:?}"; then
                    rm -rf --preserve-root "/${sourcevol:?}/${1:?}" &
                    pid=$!
                    exitonerror="no"
                    string="Removing /${sourcevol}/$1"
                    progbar $pid "$string"
                    wait "$pid"
                    progstatus "$?" "$string"
                fi
            fi
#        fi
    else
        copy_dir "$1" "$2"
    fi
}

move_extras(){ 
    # $1 is package name
    # $2 is destination /volume
    local file
    local value
    # Change /volume1 to /volume2 etc
    case "$1" in
        ActiveBackup)
            move_dir "@ActiveBackup" extras
            # /var/packages/ActiveBackup/target/log/
#            if [[ ${mode,,} == "move" ]]; then
            if [[ ${mode,,} != "backup" ]]; then
                if readlink /var/packages/ActiveBackup/target/log | grep "$1" >/dev/null; then
                    rm /var/packages/ActiveBackup/target/log
                    ln -s "${2:?}/@ActiveBackup/log" /var/packages/ActiveBackup/target/log
                fi
                file=/var/packages/ActiveBackup/target/etc/setting.conf
                if [[ -f "$file" ]]; then
                    echo "{\"conf_repo_volume_path\":\"$2\"}" > "$file"
                fi
            fi
            echo ""
            ;;
        ActiveBackup-GSuite)
            move_dir "@ActiveBackup-GSuite" extras
            echo ""
            ;;
        ActiveBackup-Office365)
            move_dir "@ActiveBackup-Office365" extras
            echo ""
            ;;
        Chat)
            if [[ ${mode,,} == "move" ]]; then
                echo -e "Are you going to move the ${Cyan}chat${Off} shared folder to ${Cyan}${targetvol}${Off}? [y/n]"
                read -r answer
                echo ""
                if [[ ${answer,,} == y ]]; then
                    # /var/packages/Chat/shares/chat --> /volume1/chat
                    rm "/var/packages/${1:?}/shares/chat"
                    ln -s "${2:?}/chat" "/var/packages/${1:?}shares/chat"
                    # /var/packages/Chat/target/synochat --> /volume1/chat/@ChatWorking
                    rm "/var/packages/${1:?}/target/synochat"
                    ln -s "${2:?}/chat/@ChatWorking" "/var/packages/${1:?}target/synochat"
                fi
            fi
            ;;
        Calendar)
            move_dir "@calendar" extras
            echo ""
            ;;
        ContainerManager|Docker)
            move_dir "@docker" extras
            if [[ ${mode,,} != "backup" ]]; then
                dsm="$(get_key_value /etc.defaults/VERSION majorversion)"
                if [[ $dsm -gt 6 ]]; then
                    # /var/packages/ContainerManager/var/docker/ --> /volume1/@docker
                    # /var/packages/Docker/var/docker/ --> /volume1/@docker
                    if [[ -L "/var/packages/${pkg:?}/var/docker" ]]; then
                        rm "/var/packages/${pkg:?}/var/docker"
                    fi
                    ln -s "${2:?}/@docker" "/var/packages/${pkg:?}/var/docker"
                else
                    # /var/packages/Docker/target/docker/ --> /volume1/@docker
                    if [[ -L "/var/packages/${pkg:?}/target/docker" ]]; then
                        rm "/var/packages/${pkg:?}/target/docker"
                    fi
                    ln -s "${2:?}/@docker" "/var/packages/${pkg:?}/target/docker"
                fi
            fi
            echo ""
            ;;
        DownloadStation)
            move_dir "@downloads" extras
            echo ""
            ;;
        GlacierBackup)
            move_dir "@GlacierBackup" extras
            if [[ ${mode,,} != "backup" ]]; then
                file=/var/packages/GlacierBackup/etc/common.conf
                if [[ -f "$file" ]]; then
                    echo "cache_volume=$2" > "$file"
                fi
            fi
            echo ""
            ;;
        MailPlus-Server)
            move_dir "@maillog" extras
            move_dir "@MailPlus-Server" extras
            echo ""
            ;;
        MailServer)
            move_dir "@maillog" extras
            move_dir "@MailScanner" extras
            move_dir "@clamav" extras
            echo ""
            ;;
        Node.js_v*)
            if [[ ${mode,,} != "backup" ]]; then
                if readlink /usr/local/bin/node | grep "$1" >/dev/null; then
                    rm /usr/local/bin/node
                    ln -s "${2:?}/@appstore/${1:?}/usr/local/bin/node" /usr/local/bin/node
                fi
                for n in /usr/local/node/nvm/versions/* ; do
                    if readlink "${n:?}/bin/node" | grep "${1:?}" >/dev/null; then
                        rm "${n:?}/bin/node"
                        ln -s "${2:?}/@appstore/${1:?}/usr/local/bin/node" "${n:?}/bin/node"
                    fi
                done
            fi
            ;;
        PrestoServer)
            move_dir "@presto" extras
            if [[ ${mode,,} != "backup" ]]; then
                file=/var/packages/PrestoServer/etc/db-path.conf
                if [[ -f "$file" ]]; then
                    echo "db-vol=${2:?}" > "$file"
                fi
            fi
            echo ""
            ;;
        SurveillanceStation)
            move_dir "@ssbackup" extras
            move_dir "@surveillance" extras
            if [[ ${mode,,} != "backup" ]]; then
                file=/var/packages/SurveillanceStation/etc/settings.conf
                if [[ -f "$file" ]]; then
                    synosetkeyvalue "$file" active_volume "${2:?}"
                    file=/var/packages/SurveillanceStation/target/@surveillance
                    rm "$file"
                    ln -s "${2:?}/@surveillance" /var/packages/SurveillanceStation/target
                    chown -h SurveillanceStation:SurveillanceStation "$file"
                fi
            fi
            echo ""
            ;;
        synocli*)
            #move_dir "@$1"
            #echo ""
            ;;
        SynologyApplicationService)
            move_dir "@SynologyApplicationService" extras
            if [[ ${mode,,} != "backup" ]]; then
                file=/var/packages/SynologyApplicationService/etc/settings.conf
                if [[ -f "$file" ]]; then
                    synosetkeyvalue "$file" volume "${2:?}/@SynologyApplicationService"
                fi
            fi
            echo ""
            ;;
        SynologyDrive)
            move_dir "@SynologyDrive" extras
            move_dir "@SynologyDriveShareSync" extras
            if [[ ${mode,,} != "backup" ]]; then
                file=/var/packages/SynologyDrive/etc/sharesync/daemon.conf
                if [[ -f "$file" ]]; then
                    sed -i 's|'/"$sourcevol"'|'"${2:?}"'|g' "$file"
                    chmod 644 "$file"
                fi

                file=/var/packages/SynologyDrive/etc/sharesync/monitor.conf
                if [[ -f "$file" ]]; then
                    value="$(synogetkeyvalue "$file" system_db_path)"
                    if [[ -n $value ]]; then
                        synosetkeyvalue "$file" system_db_path "${value/${sourcevol}/$(basename "${2:?}")}"
                    fi
                fi

                file=/var/packages/SynologyDrive/etc/sharesync/service.conf
                if [[ -f "$file" ]]; then
                    synosetkeyvalue "$file" volume "${2:?}"
                fi
            fi
            echo ""
            ;;
        WebDAVServer)
            move_dir "@webdav" extras
            echo ""
            ;;
        Virtualization)
            move_dir "@GuestImage" extras
            move_dir "@Repository" extras
            # VMM creates /volume#/vdsm_repo.conf so no need to move it
            echo ""
            ;;
        *)
            return
            ;;
    esac
}


#------------------------------------------------------------------------------
# Select mode

echo ""
modes=( "Move" "Backup" "Restore" )
PS3="Select the mode: "
select m in "${modes[@]}"; do
    case "$m" in
        Move)
            mode="Move"
            action="Moving"
            break
            ;;
        Backup)
            mode="Backup"
            action="Backing up"
            break
            ;;
        Restore)
            mode="Restore"
            action="Restoring"
            break
            ;;
        *)  
            echo "Invalid choice!"
            ;;
    esac
done
echo -e "You selected ${Cyan}${mode}${Off}\n"


# Check backup path if mode is backup or restore
if [[ ${mode,,} != "move" ]]; then
    if [[ ! -f "$conffile" ]]; then
        ding
        echo -e "${Error}ERROR${Off} $conffile not found!"
        exit 1
    fi
    if [[ ! -r "$conffile" ]]; then
        ding
        echo -e "${Error}ERROR${Off} $conffile not readable!"
        exit 1
    fi
    # Fix line endings
    if grep -rIl -m 1 $'\r' "$conffile" >/dev/null; then
        # Does not contain Linux line endings
        sed -i 's/\r\n/\n/g' "$conffile"  # Fix Windows line endings
        sed -i 's/\r/\n/g' "$conffile"    # Fix Mac line endings
    fi

    # Get and validate backup path
    backuppath="$(synogetkeyvalue "$conffile" backuppath)"
    if [[ -z "$backuppath" ]]; then
        ding
        echo -e "${Error}ERROR${Off} backuppath missing from ${conffile}!"
        exit 1
    elif [[ ! -d "$backuppath" ]]; then
        ding
        echo -e "${Error}ERROR${Off} Backup folder ${Cyan}$backuppath${Off} not found!"
        exit 1
    fi
fi
if [[ ${mode,,} == "backup" ]]; then
    echo -e "Backup path is: ${Cyan}${backuppath}${Off}\n"
elif [[ ${mode,,} == "restore" ]]; then
    echo -e "Restore from path is: ${Cyan}${backuppath}${Off}\n"
fi


#------------------------------------------------------------------------------
# Select package

declare -A package_names

if [[ ${mode,,} != "restore" ]]; then
    # Select package to move or backup

    # Add non-system packages to array
    cdir /var/packages
    package_infos=( )
    while read -r link target; do
        package="$(printf %s "$link" | cut -d'/' -f2 )"
        package_volume="$(printf %s "$target" | cut -d'/' -f1,2 )"
        package_name="$(synogetkeyvalue "/var/packages/${package}/INFO" displayname)"
        if [[ ! ${package_infos[*]} =~ "${package_volume}|${package_name}" ]]; then
            package_infos+=("${package_volume}|${package_name}")
        fi
#        if [[ ! ${package_names[*]} =~ "${package}|${package_name}" ]]; then
            package_names["${package_name}"]="${package}"
#        fi
    done < <(find . -maxdepth 2 -type l -ls | grep volume | awk '{print $(NF-2), $NF}')

    # Sort array
    IFS=$'\n' package_infos_sorted=($(sort <<<"${package_infos[*]}")); unset IFS

    # Select package to move
    if [[ ${#package_infos_sorted[@]} -gt 0 ]]; then
        #echo -e "\n[Installed package list]"
        echo -e "[Installed package list]"
        for ((i=1; i<=${#package_infos_sorted[@]}; i++)); do
            info="${package_infos_sorted[i-1]}"
            before_pipe="${info%%|*}"
            after_pipe="${info#*|}"
            package_infos_show+=("$before_pipe  $after_pipe")
        done

        PS3="Select the package to ${mode,,}: "
        select m in "${package_infos_show[@]}"; do
            case "$m" in
                /volume*)
                    # Parse selected element of array
                    package_volume="$(echo "$m" | awk '{print $1}')"
                    pkg_name=${m#"$package_volume  "}
                    pkg="${package_names[${pkg_name}]}"
                    break
                    ;;
                *)
                    echo "Invalid choice! $m"
                    ;;
            esac
        done
    else
        echo "No movable packages found!" && exit 1
    fi

    echo -e "You selected ${Cyan}${pkg_name}${Off} in ${Cyan}${package_volume}${Off}\n"
    target=$(readlink "/var/packages/${pkg}/target")
    linktargetvol="/$(printf %s "${target:?}" | cut -d'/' -f2 )"

elif [[ ${mode,,} == "restore" ]]; then
    # Select package to backup

    # Get list of backed up packages
    cdir "${backuppath}/syno_app_mover"
    for package in *; do
        if [[ -d "$package" ]] && [[ $package != "@eaDir" ]]; then
            if [[ ${package:0:1} != "-" ]]; then
                package_name="$(synogetkeyvalue "${backuppath}/syno_app_mover/${package}/INFO" displayname)"
                package_names["${package_name:?}"]="${package:?}"
            fi
        fi
    done < <(find . -maxdepth 2 -type d)

    # Select package to restore
    if [[ ${#package_names[@]} -gt 0 ]]; then
        echo -e "[Restorable package list]"
        PS3="Select the package to restore: "
        select pkg_name in "${!package_names[@]}"; do
            pkg="${package_names[${pkg_name}]}"
            if [[ $pkg ]]; then
                if [[ -d $pkg ]]; then
                    echo -e "You selected ${Cyan}${pkg_name}${Off}\n"
                    break
                else
                    ding
                    echo -e "${Error}ERROR${Off} $pkg_name not found!"
                    exit 1
                fi
            else
                echo "Invalid choice!"
            fi
        done

        # Check if package is installed
        synopkg status "${pkg}" >/dev/null
        if [[ $? == "255" ]]; then
            echo -e "${Cyan}${pkg_name}${Off} is not installed!"
            echo -e "Install ${Cyan}${pkg_name}${Off} then try Restore again"
            exit
        fi
    else
        ding
        echo -e "${Error}ERROR${Off} No package backups found!"
        exit 1
    fi
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
if [[ ${mode,,} == "move" ]]; then
    if [[ ${#volumes[@]} -gt 1 ]]; then
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
    elif [[ ${#volumes[@]} -eq 1 ]]; then
        targetvol="${volumes[0]}"
        echo -e "Destination volume is ${Cyan}${targetvol}${Off}\n"
    else
        ding
        echo -e "${Error}ERROR${Off} Only 1 volume found!"
        exit 1
    fi
elif [[ ${mode,,} == "backup" ]]; then
    targetvol="/$(echo "${backuppath:?}" | cut -d"/" -f2)"
    echo -e "Destination volume is ${Cyan}${targetvol}${Off}\n"
elif [[ ${mode,,} == "restore" ]]; then
    targetvol="/$(readlink "/var/packages/${pkg:?}/target" | cut -d"/" -f2)"
    echo -e "Destination volume is ${Cyan}${targetvol}${Off}\n"
fi

# Check user is ready
if [[ ${mode,,} == "backup" ]]; then
    echo -e "Ready to ${Yellow}${mode}${Off} ${Cyan}${pkg_name}${Off} to ${Cyan}${backuppath}${Off}? [y/n]"
else
    echo -e "Ready to ${Yellow}${mode}${Off} ${Cyan}${pkg_name}${Off} to ${Cyan}${targetvol}${Off}? [y/n]"
fi
read -r answer
echo ""
if [[ ${answer,,} != y ]]; then
    exit
fi


if [[ ${mode,,} == "backup" ]] || [[ ${mode,,} == "restore" ]]; then
    bkpath="${backuppath}/syno_app_mover/$pkg"
fi


#------------------------------------------------------------------------------
# Check installed package version and backup version

# Get package version
if [[ ${mode,,} != "move" ]]; then
    pkgversion=$(synogetkeyvalue "/var/packages/$pkg/INFO" version)
fi

# Get backup package version
if [[ ${mode,,} == "restore" ]]; then
    pkgbackupversion=$(synogetkeyvalue "$bkpath/INFO" version)
    if [[ $pkgversion ]] && [[ $pkgbackupversion ]]; then
        if [[ $pkgversion != "$pkgbackupversion" ]]; then
            ding
            echo -e "${Yellow}Backup and installed package versions don't match!${Off}"
            echo "  Backed up version: $pkgbackupversion"
            echo "  Installed version: $pkgversion"
            echo "Do you want to continue restoring ${pkg_name}? [y/n]"
            read -r reply
            if [[ ${reply,,} != "y" ]]; then
                exit
            else
                echo ""
            fi
        fi
    fi
fi


#------------------------------------------------------------------------------
# Create package folder if mode is backup

if [[ ${mode,,} == "backup" ]]; then
    if [[ ! -d "$bkpath" ]]; then
        if ! mkdir -p "${bkpath:?}"; then
            ding
            echo -e "${Error}ERROR${Off} Failed to create directory!"
            exit 1
        fi
    fi

#    # Create package version file
#    synosetkeyvalue "$bkpath/INFO" version "$pkgversion"

    # Backup package's INFO file
    cp -p "/var/packages/$pkg/INFO" "$bkpath/INFO"
fi


#------------------------------------------------------------------------------
# Move the package

# Check package is running
if package_status "$pkg"; then

    # Get list of dependant packages
    dependants=($(synopkg list --name --depend-on "$pkg"))

    # Stop dependant packages
    dependant_pkgs_stop

    # Stop package
    if package_status "$pkg"; then
        package_stop "$pkg" "$pkg_name"
        echo ""
    fi

    # Check package stopped
    if package_status "$pkg"; then
        ding
        echo -e "${Error}ERROR${Off} Failed to stop ${pkg_name}!"
        if [[ $fix != "yes" ]]; then  # bypass exit
            exit 1
        fi
    fi

    if [[ $pkg == "ContainerManager" ]] || [[ $pkg == "Docker" ]]; then
        # Stop containerd-shim
        killall containerd-shim >/dev/null
    fi
else
    skip_start="yes"
fi


target=$(readlink "/var/packages/${pkg}/target")
#sourcevol="/$(printf %s "${target:?}" | cut -d'/' -f2 )"
sourcevol="$(printf %s "${target:?}" | cut -d'/' -f2 )"

# Move package
if [[ $pkg =~ ActiveBackup* ]]; then 
    # Can't uninstall package which has dependers

#    # Backup @ActiveBackup folder
#    # $1 is folder to backup (@ActiveBackup etc) 
#    # $2 is volume (/volume1 etc)
#    backup_dir "@${pkg:?}" "${sourcevol:?}"
#
#    if [[ ${mode,,} == "move" ]]; then
#        # Uninstall and reinstall package
#        package_uninstall "$pkg"
#        sleep 2
#
#        # Check if package uninstalled
#        synopkg status "${pkg}" >/dev/null
#        if [[ $? != "255" ]]; then
#            echo -e "${Error}ERROR${Off} ${Cyan}${pkg_name}${Off} didn't uninstall!"
#            exit
#        fi
#
#        package_install "$pkg" "$targetvol"
#        #wait_status "$pkg" start
#
#        # Check if package installed
#        if ! synopkg status "${pkg}" >/dev/null; then
#            ding
#            echo -e "${Error}ERROR${Off} ${Cyan}${pkg_name}${Off} didn't install!"
#            exit
#        fi
#
#        # Stop package
#        package_stop "$pkg" "$pkg_name"
#        skip_start=""
#
#        # Delete @ActiveBackup on target volume
#        if [[ -d "${targetvol:?}/@${pkg:?}" ]]; then
#            #rm -r --preserve-root "${targetvol:?}/@${pkg:?}" &
#            #pid=$!
#            #string="Deleting new ${Cyan}$pkg${Off} settings and database"
#            #progbar $pid "$string"
#            #wait "$pid"
#            #progstatus "$?" "$string"
#            rm -r --preserve-root "${targetvol}/@${pkg}"
#        fi
#
#        # Copy source @ActiveBackup_backup to target @ActiveBackup
#        cp -prf "${sourcevol:?}/@${pkg:?}_backup" "${targetvol:?}/@${pkg:?}" &
#        pid=$!
#        string="Copying ${Cyan}$pkg${Off} settings and database to ${Cyan}$targetvol${Off}"
#        progbar $pid "$string"
#        wait "$pid"
#        progstatus "$?" "$string"
#    else
        # Backup, or restore and edit symlinks
        move_pkg "$pkg" "$targetvol"
#    fi

elif [[ $pkg == "ContainerManager" ]] || [[ $pkg == "Docker" ]]; then
    # Move @docker if package is ContainerManager or Docker

    # Backup @docker
    if [[ ${mode,,} != "backup" ]]; then
        if [[ ${mode,,} == "move" ]]; then
            dockerbakvol="$sourcevol"
        elif [[ ${mode,,} == "restore" ]]; then
            dockerbakvol="$targetvol"
        fi
        echo -e "Do you want to ${Yellow}backup${Off} the"\
            "${Cyan}@docker${Off} folder on $dockerbakvol? [y/n]"
        read -r answer
        echo ""
        if [[ ${answer,,} == "y" ]]; then
            backup_dir "@docker" "$dockerbakvol"
        fi
    fi

    # Check if @docker is on same volume as Docker package
    if [[ -d "/${sourcevol}/@docker" ]]; then
        # Get size of @docker folder
        folder_size "/${sourcevol}/@docker"

        # Get amount of free space on target volume
        vol_free_space "${targetvol}"

        # Check we have enough space
        if [[ ! $free -gt $needed ]]; then
            echo -e "${Yellow}WARNING${Off} Not enough space to ${mode,,} "\
                "/${sourcevol}/${Cyan}@docker${Off} to $targetvol"
            echo -e "Free: $((free /1048576)) GB  Needed: $((need /1048576)) GB\n"
            exit
        else
            move_pkg "$pkg" "$targetvol"
        fi
    fi
else
    # Move package and edit symlinks
    move_pkg "$pkg" "$targetvol"
fi
echo ""

# Move package's other folders
move_extras "$pkg" "$targetvol"


#------------------------------------------------------------------------------
# Show how to move related shared folder(s)

suggest_move_share(){ 
    # show_move_share <package-name> <share-name>
    if [[ ${mode,,} == "move" ]]; then
        case "$pkg" in
            ActiveBackup)
                show_move_share "Active Backup for Business" ActiveBackupforBusiness
                ;;
            AudioStation)
                share_link=$(readlink /var/packages/AudioStation/shares/music)
                if [[ $share_link == "/${sourcevol}/music" ]]; then
                    show_move_share "Audio Station" music
                fi
                ;;
            Chat)
                show_move_share "Chat Server" chat
                ;;
            CloudSync)
                show_move_share "Cloud Sync" CloudSync
                ;;
            ContainerManager)
                show_move_share "Container Manager" docker
                ;;
            Docker)
                show_move_share "Docker" docker
                ;;
            MailPlus-Server)
                show_move_share "MailPlus Server" MailPlus
                ;;
            MinimServer)
                show_move_share "Minim Server" MinimServer
                ;;
            Plex*Media*Server)
                dsm="$(get_key_value /etc.defaults/VERSION majorversion)"
                if [[ $dsm -lt 7 ]]; then
                    show_move_share "Plex Media Server" Plex
                else
                    show_move_share "Plex Media Server" PlexMediaServer
                fi
                ;;
            SurveillanceStation)
                show_move_share "Surveillance Station" surveillance
                ;;
            VideoStation)
                share_link=$(readlink /var/packages/VideoStation/shares/video)
                if [[ $share_link == "/${sourcevol}/video" ]]; then
                    show_move_share "Video Station" video
                fi
                ;;
            *)  
                ;;
        esac
    fi
}

if [[ ${mode,,} == "move" ]]; then
    suggest_move_share
fi


#------------------------------------------------------------------------------
# Start package and dependent packages

if [[ $skip_start != "yes" ]]; then
    if [[ ${mode,,} == "backup" ]]; then
        answer="y"
    else
        echo -e "Do you want to start ${Cyan}$pkg_name${Off} now? [y/n]"
        read -r answer
        echo ""
    fi
    if [[ ${answer,,} == "y" ]]; then
        # Start package
        package_start "$pkg" "$pkg_name"
        echo ""

        # Check package started
        if ! package_status "$pkg"; then
            ding
            echo -e "${Error}ERROR${Off} Failed to start ${pkg_name}!"
            exit 1
        fi

        # Start dependant packages
        dependant_pkgs_start
    fi
fi

echo -e "Finished ${action,,} $pkg_name\n"


#------------------------------------------------------------------------------
# Suggest change location of shared folder(s)

suggest_change_location(){ 
    # Suggest moving CloudSync database if package is CloudSync
    if [[ $pkg == CloudSync ]]; then
        # Show how to move CloudSync database
        echo -e "If you want to move the CloudSync database to $targetvol"
        echo "  1. Open 'CloudSync'."
        echo "  2. Click Settings."
        echo "  3. Change 'Database Location Settings' to $targetvol"
        echo -e "  4. Click Save.\n"
    fi

    # Suggest moving @downloads if package is DownloadStation
    if [[ $pkg == DownloadStation ]]; then
        # Show how to move DownloadStation database and temp files
        #file="/var/packages/DownloadStation/etc/db-path.conf"
        #value="$(synogetkeyvalue "$file" db-vol)"
        #if [[ $value != "$targetvol" ]]; then
            echo -e "If you want to move the DownloadStation database & temp files to $targetvol"
            echo "  1. Open 'DownloadStation'."
            echo "  2. Click Settings."
            echo "  3. Click General."
            echo "  4. Change 'Temporary location' to $targetvol"
            echo -e "  5. Click OK.\n"
        #fi
    fi

    # Suggest moving Note Station database if package is NoteStation
    if [[ $pkg == NoteStation ]]; then
        # Show how to move Note Station database
        echo -e "If you want to move the Note Station database to $targetvol"
        echo "  1. Open 'Note Station'."
        echo "  2. Click Settings."
        echo "  3. Click Administration."
        echo "  4. Change Volume to $targetvol"
        echo -e "  5. Click OK.\n"
    fi

    # Suggest moving Synology Drive database if package is SynologyDrive
    if [[ $pkg == SynologyDrive ]]; then
        # Show how to move Drive database
        file="/var/packages/SynologyDrive/etc/db-path.conf"
        value="$(synogetkeyvalue "$file" db-vol)"
        if [[ $value != "$targetvol" ]]; then
            echo -e "If you want to move the Synology Drive database to $targetvol"
            echo "  1. Open 'Synology Drive Admin Console'."
            echo "  2. Click Settings."
            echo "  3. Change Location to $targetvol"
            echo -e "  4. Click Apply.\n"
        fi
    fi

    # Suggest moving VMs if package is Virtualization
    if [[ $pkg == Virtualization ]]; then
        # Show how to move VMs
        echo -e "If you want to move your VMs to $targetvol\n"
        echo "1. Add $targetvol as Storage in Virtual Machine Manager"
        echo "  1. Open Virtual Machine Manager."
        echo "  2. Click Storage and Click Add."
        echo "  3. Complete the steps to add $targetvol"
        echo -e "\n2. Move the VM to $targetvol"
        echo "  1. Click on Virtual Machine."
        echo "  2. Click on the VM to move."
        echo "  3. Shut Down the VM."
        echo "  4. Click Action then click Migrate."
        echo "  5. Make sure Change Storage is selected."
        echo "  6. Click Next."
        echo -e "  7. Complete the steps to migrate the VM.\n"
    fi
}

if [[ ${mode,,} == "move" ]]; then
    suggest_change_location
fi

exit

