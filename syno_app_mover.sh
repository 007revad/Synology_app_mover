#!/usr/bin/env bash
# shellcheck disable=SC2076,SC2207
#------------------------------------------------------------------------------
# Easily move Synology packages from 1 volume to another volume.
#
# Github: https://github.com/007revad/Synology_app_mover
# Script verified at https://www.shellcheck.net/
#
# To run in a shell (replace /volume1/scripts/ with path to script):
# sudo -i /volume1/scripts/syno_app_mover.sh
#------------------------------------------------------------------------------
# TODO
#
# Cannot uninstall packages with dependers 
# "failed to uninstall a package who has dependers installed"
#
# Check exit status of package uninstall and install


scriptver="v2.0.7"
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
    export PS4='`[[ $? == 0 ]] || echo "\e[1;31;40m($?)\e[m\n "`:.$LINENO:'
fi

if [[ ${1,,} == "--fix" ]]; then
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

                            # Copy new CHANGES.txt file to script location (if script on a volume)
                            if [[ $scriptpath =~ /volume* ]]; then
                                # Set permsissions on CHANGES.txt
                                if ! chmod 664 "/tmp/$script-$shorttag/CHANGES.txt"; then
                                    permerr=1
                                    echo -e "${Error}ERROR${Off} Failed to set permissions on:"
                                    echo "$scriptpath/CHANGES.txt"
                                fi

                                # Copy new CHANGES.txt file to script location
                                if ! cp -p "/tmp/$script-$shorttag/CHANGES.txt"\
                                    "${scriptpath}/${scriptname}_CHANGES.txt";
                                then
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
                                echo -e "\n$tag ${scriptfile}$changestxt downloaded to: ${scriptpath}\n"

                                # Reload script
                                printf -- '-%.0s' {1..79}; echo  # print 79 -
                                exec "$0" "${args[@]}"
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
        echo -ne "${2}$progress\r"; sleep "$delay"
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
    local num
    synopkg stop "$1" >/dev/null &
    progbar $! "Stopping ${Cyan}${1}${Off}"

    # Allow package processes to finish stopping
    wait_status "$1" stop
    #sleep 1
}

package_start(){ 
    # $1 is package name
    synopkg start "$1" >/dev/null &
    progbar $! "Starting ${Cyan}${1}${Off}"
    wait_status "$1" start
}

dependant_pkgs_stop(){ 
    if [[ ${#dependants[@]} -gt "0" ]]; then
        echo "Stopping dependant packages"
        for d in "${dependants[@]}"; do
            if package_status "$d"; then
                # Get list of dependers that were running
                dependants2start+=( "$d" )
                package_stop "$d"

                # Check packaged stopped
                if package_status "$d"; then
                    ding
                    echo -e "${Error}ERROR${Off} Failed to stop ${d}!"
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
            package_start "$d"

            # Check packaged started
            if ! package_status "$d"; then
                echo -e "${Error}ERROR${Off} Failed to start ${d}!"
            fi
        done
        echo ""
    fi
}

package_uninstall(){ 
    # $1 is package name
    synopkg uninstall "$1" >/dev/null &
    progbar $! "Uninstalling ${Cyan}${1}${Off}"
}

package_install(){ 
    # $1 is package name
    # $2 is /volume2 etc
    synopkg install_from_server "$1" "$2" >/dev/null &
    progbar $! "Installing ${Cyan}${1}${Off} on ${Cyan}$2${Off}"
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
            perms=$(stat -c %a "${2}/${1}")
            mkdir -m "$perms" "${2}/${1}_backup"
        fi

        # Backup $1
        if ! is_empty "${2}/${1}_backup"; then
            # @docker_backup folder exists and is not empty
            echo -e "There is already a backup of $1"
            echo -e "Do you want to overwrite it? [y/n]"
            read -r answer
            echo ""
            if [[ ${answer,,} != "y" ]]; then
                return
            fi
        fi

        cp -rf "${2}/${1}/." "${2}/${1}_backup" &
        # If string is too long progbar repeats string for each dot
        #progbar $! "Backing up ${2}/$1 to ${Cyan}${2}/${1}_backup${Off}"
        progbar $! "Backing up $1 to ${Cyan}${1}_backup${Off}"
        echo ""
    fi
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
        if ! is_empty "${2}/${appdir}/${1}"; then
            echo "Skipping moving ${appdir}/$1 as target is not empty:"
            echo "  ${2}/${appdir}/$1"
        else
            mv "$source" "${2}/$appdir" &
            progbar $! "Moving $source to ${Cyan}$2${Off}"
        fi

        # Edit /var/packages symlinks
        case "$appdir" in
            @appconf)  # etc --> @appconf
                rm "/var/packages/${1}/etc"
                ln -s "${2}/@appconf/$1" "/var/packages/${1}/etc"

                # /usr/syno/etc/packages/$1
                # /volume1/@appconf/$1
                if [[ -L "/usr/syno/etc/packages/$1" ]]; then
                    rm "/usr/syno/etc/packages/$1"
                    ln -s "${2}/@appconf/$1" "/usr/syno/etc/packages/$1"
                fi
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
                echo -e "${Red}Oops!${Off} appdir: ${appdir}\n"
                return
                ;;
        esac
    done < <(find . -maxdepth 2 -type l -ls | grep "$1"'$' | awk '{print $(NF-2), $NF}')
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
        backup_dir "@docker" "${1}"
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

    # /var/packages/ContainerManager/var/docker/ --> /volume1/@docker
    rm "/var/packages/${pkg}/var/docker"
    ln -s "${2}/@docker" "/var/packages/${pkg}/var/docker"

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

move_dir(){ 
    # $1 is folder (@surveillance etc)
    if [[ -d "/${sourcevol}/$1" ]]; then
        mv "/${sourcevol}/$1" "/${targetvol}/$1" &
        progbar $! "Moving /${sourcevol}/$1 to ${Cyan}$targetvol${Off}"
    fi
}

move_extras(){ 
    # $1 is package name
    # $2 is destination /volume
    local file
    local source
    local value
    # Change /volume1 to /volume2 etc
    case "$1" in
        ActiveBackup)
#            move_dir "@ActiveBackup"
#            # /var/packages/ActiveBackup/target/log --> /volume1/@ActiveBackup/log
#            if readlink /var/packages/ActiveBackup/target/log | grep "$sourcevol" >/dev/null; then
#                rm /var/packages/ActiveBackup/target/log
#                ln -s "$2/@ActiveBackup/log" /var/packages/ActiveBackup/target/log
#            fi
#            echo ""
            ;;
        Chat)
            echo -e "Are you going to move the ${Cyan}chat${Off} shared folder to ${Cyan}${targetvol}${Off}? [y/n]"
            read -r answer
            echo ""
            if [[ ${answer,,} == y ]]; then
                chat_move="yes"
                # /var/packages/Chat/shares/chat --> /volume1/chat
                rm "/var/packages/${1}/shares/chat"
                ln -s "${2}/chat" "/var/packages/${1}/shares/chat"
                # /var/packages/Chat/target/synochat --> /volume1/chat/@ChatWorking
                rm "/var/packages/${1}/target/synochat"
                ln -s "${2}/chat/@ChatWorking" "/var/packages/${1}/target/synochat"
            fi
            ;;
        GlacierBackup)
            file=/var/packages/GlacierBackup/etc/common.conf
            if [[ -f "$file" ]]; then
                echo "cache_volume=$2" > "$file"
                move_dir "@GlacierBackup"
                echo ""
            fi
            ;;
        HyperBackup)

            # This section is not needed for moving HyperBackup.
            # I left it here in case I can use it for some other package in future.

            # Moving "@img_bkp_cache" and editing synobackup.conf
            # to point the repos to the new location causes backup tasks
            # to show as offline with no way to fix them or delete them!
            #
            # Thankfully HyperBackup recreates the data in @img_bkp_cache
            # when the backup task is run, or a resync is done.

            file=/var/packages/HyperBackup/etc/synobackup.conf
            # [repo_1]
            # client_cache="/volume1/@img_bkp_cache/ClientCache_image_image_local.oJCDvd"
            if [[ -f "$file" ]]; then

                # Get list of [repo_#] in $file
                readarray -t contents < "$file"
                for r in "${contents[@]}"; do
                    l=$(echo "$r" | grep -E "repo_[0-9]+")
                    if [[ -n "$l" ]]; then
                        l="${l/]/}" && l="${l/[/}"
                        repos+=("$l")
                    fi
                done

                # Edit values with sourcevol to targetvol
                for section in "${repos[@]}"; do
                    value="$(get_section_key_value "$file" "$section" client_cache)"
                    #echo "$value"  # debug
                    if echo "$value" | grep "$sourcevol" >/dev/null; then
                        newvalue="${value/$sourcevol/$targetvol}"
                        #echo "$newvalue"  # debug
                        #echo ""  # debug
                #        set_section_key_value "$file" "$section" client_cache "$newvalue"
                        #echo "set_section_key_value $file $section client_cache $newvalue"  # debug
                        #echo ""  # debug
                        #echo ""  # debug
                    fi
                done
            fi

            # Move @img_bkp folders
            if [[ -d "/${sourcevol}/@img_bkp_cache" ]] ||\
                [[ -d "/${sourcevol}/@img_bkp_mount" ]]; then
            #    backup_dir "@img_bkp_cache" "$sourcevol"
            #    backup_dir "@img_bkp_mount" "$sourcevol"

            #    move_dir "@img_bkp_cache"
            #    move_dir "@img_bkp_mount"
                echo ""
            fi
            ;;
        MailPlus-Server)
            move_dir "@maillog"
            move_dir "@MailPlus-Server"
            echo ""
            ;;
        MailServer)
            move_dir "@maillog"
            move_dir "@MailScanner"
            move_dir "@clamav"
            echo ""
            ;;
        Node.js_v*)
            if readlink /usr/local/bin/node | grep "$1" >/dev/null; then
                rm /usr/local/bin/node
                ln -s "$2/@appstore/$1/usr/local/bin/node" /usr/local/bin/node
            fi
            for n in /usr/local/node/nvm/versions/* ; do
                if readlink "$n/bin/node" | grep "$1" >/dev/null; then
                    rm "$n/bin/node"
                    ln -s "$2/@appstore/$1/usr/local/bin/node" "$n/bin/node"
                fi
            done
            ;;
        PrestoServer)
            file=/var/packages/PrestoServer/etc/db-path.conf
            if [[ -f "$file" ]]; then
                echo "db-vol=$2" > "$file"
                move_dir "@presto"
                echo ""
            fi
            ;;
        SurveillanceStation)
            file=/var/packages/SurveillanceStation/etc/settings.conf
            if [[ -f "$file" ]]; then
                synosetkeyvalue "$file" active_volume "$2"
                move_dir "@ssbackup"
                move_dir "@surveillance"
                file=/var/packages/SurveillanceStation/target/@surveillance
                rm "$file"
                ln -s "$2/@surveillance" /var/packages/SurveillanceStation/target
                chown -h SurveillanceStation:SurveillanceStation "$file"
                echo ""
            fi
            ;;
        synocli*)
            #move_dir "@$1"
            #echo ""
            ;;
        SynologyApplicationService)
            file=/var/packages/SynologyApplicationService/etc/settings.conf
            if [[ -f "$file" ]]; then
                synosetkeyvalue "$file" volume "$2/@SynologyApplicationService"
                move_dir "@SynologyApplicationService"
                echo ""
            fi
            ;;
        SynologyDrive)
            #file=/var/packages/SynologyDrive/etc/db-path.conf
            #if [[ -f "$file" ]]; then
                #echo "db-vol=$2" > "$file"
                move_dir "@synologydrive"
                move_dir "@SynologyDriveShareSync"
                echo ""
            #fi
            file=/var/packages/SynologyDrive/etc/sharesync/daemon.conf
            if [[ -f "$file" ]]; then
                sed -i 's|'/"$sourcevol"'|'"$2"'|g' "$file"
                chmod 644 "$file"
            fi

            file=/var/packages/SynologyDrive/etc/sharesync/monitor.conf
            if [[ -f "$file" ]]; then
                value="$(synogetkeyvalue "$file" system_db_path)"
                if [[ -n $value ]]; then
                    #synosetkeyvalue "$file" system_db_path "${value/${sourcevol}/"$2"}"
                    synosetkeyvalue "$file" system_db_path "${value/${sourcevol}/$(basename "$2")}"
                fi
            fi

            file=/var/packages/SynologyDrive/etc/sharesync/service.conf
            if [[ -f "$file" ]]; then
                synosetkeyvalue "$file" volume "$2"
            fi
            ;;
        WebDAVServer)
            move_dir "@webdav"
            move_dir "@webdav"
            echo ""
            ;;
        Virtualization)
            move_dir "@GuestImage"
            move_dir "@Repository"
            # VMM creates /volume#/vdsm_repo.conf so no need to move it
            ;;
        *)
            return
            ;;
    esac
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
if [[ ${#package_infos_sorted[@]} -gt 0 ]]; then
    echo -e "\n[Installed package list]"
    for ((i=1; i<=${#package_infos_sorted[@]}; i++)); do
        info="${package_infos_sorted[i-1]}"
        before_pipe="${info%%|*}"
        after_pipe="${info#*|}"
        printf "%-3s %-9s %s\n" "$i)" "$before_pipe" "$after_pipe"
    done
else
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

# Get list of dependant packages
dependants=($(synopkg list --name --depend-on "$pkg"))

# Stop dependant packages
dependant_pkgs_stop

# Stop package if running
if package_status "$pkg"; then
    package_stop "$pkg"
    echo ""
fi

# Check package stopped
if package_status "$pkg"; then
    ding
    echo -e "${Error}ERROR${Off} Failed to stop ${pkg}!"
    if [[ $fix != "yes" ]]; then  # bypass exit
        exit 1
    fi
fi


# Move package
if [[ ${pkg} =~ ActiveBackup* ]]; then 
    # Can't uninstall package which has dependers

    target=$(readlink "/var/packages/${pkg}/target")
    sourcevol="/$(printf %s "$target" | cut -d'/' -f2 )"

    # Backup @ActiveBackup folder
    # $1 is folder to backup (@ActiveBackup etc) 
    # $2 is volume (/volume1 etc)
    backup_dir "@${pkg}" "$sourcevol"

    # Uninstall and reinstall package
    package_uninstall "$pkg"
    sleep 2
    package_install "$pkg" "$targetvol"
    #wait_status "$pkg" start

    # Stop package
    package_stop "$pkg"

    # Delete @ActiveBackup on target volume
    if [[ -d "${targetvol}/@${pkg}" ]]; then
        #rm -r "${targetvol}/@${pkg}" &
        #progbar $! "Deleting new ${Cyan}$pkg${Off} settings and database"
        rm -r "${targetvol}/@${pkg}"
    fi

    # Copy source @ActiveBackup_backup to target @ActiveBackup
    cp -prf "${sourcevol}/@${pkg}_backup" "${targetvol}/@${pkg}" &
    progbar $! "Copying ${Cyan}$pkg${Off} settings and database to ${Cyan}$targetvol${Off}"
else
    # Move package and edit symlinks
    move_pkg "$pkg" "$targetvol"
fi
echo ""

# Move package's other folders
move_extras "$pkg" "$targetvol"


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
            show_move_share "$pkg" docker
        fi
    fi
fi


#------------------------------------------------------------------------------
# Show how to move related shared folder

# show_move_share <package-name> <share-name>
case "$pkg" in
    ActiveBackup)
        # show_move_share "Active Backup for Business" ActiveBackupforBusiness
        ;;
    ActiveBackup-GSuite)
        # Need to check the shared folder name is correct
        # show_move_share "Active Backup for Google Workspace" ActiveBackup-GSuite
        ;;
    ActiveBackup-Office365)
        # Need to check the shared folder name is correct
        # show_move_share "Active Backup for Microsoft 365" ActiveBackup-Office365
        ;;
    AudioStation)
        share_link=$(readlink /var/packages/AudioStation/shares/music)
        if [[ $share_link == "/${sourcevol}/music" ]]; then
            show_move_share "Audio Station" music
        fi
        ;;
    Chat)
        if [[ $chat_move == "yes" ]]; then
            echo "  1. Go to 'Control Panel > Shared Folders'."
            echo "  2. Select the chat shared folder and click Edit."
            echo "  3. Change Location to /volume2 and click Save."
            echo -e "  4. After step 3 has finished start Chat from Package Center.\n"
            exit
        fi
        ;;
    CloudSync)
        show_move_share "Cloud Sync" CloudSync
        ;;
    MailPlus-Server)
        show_move_share "MailPlus-Server" MailPlus
        ;;
    MinimServer)
        show_move_share "MinimServer" MinimServer
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


#------------------------------------------------------------------------------
# Start package and dependent packages

echo -e "Do you want to start ${Cyan}$pkg${Off} now? [y/n]"
read -r answer
echo ""
if [[ ${answer,,} == "y" ]]; then
    # Start package
    package_start "$pkg"
    echo ""

    # Check package started
    if ! package_status "$pkg"; then
        ding
        echo -e "${Error}ERROR${Off} Failed to start ${pkg}!"
        exit 1
    fi

    # Start dependant packages
    dependant_pkgs_start
fi

echo -e "Finished moving $pkg\n"


#------------------------------------------------------------------------------

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

exit

