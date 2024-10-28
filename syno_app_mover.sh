#!/usr/bin/env bash
# shellcheck disable=SC2076,SC2207,SC2238,SC2129
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
# TODO
# Instead of moving large extra folders copy them to the target volume.
#   Then rename the source volume's @downloads to @downloads_backup.
#
# Add ability to move all apps
# https://www.reddit.com/r/synology/comments/1eybzc1/comment/ljcj8re/
#
# Maybe add backing up "/volume#/@iSCSI/VDISK_BLUN" (VMM VMs)
# https://www.synology-forum.de/threads/backup-der-vms.135462/post-1194705
# https://www.synology-forum.de/threads/virtual-machine-manager-vms-sichern.91952/post-944113
#
#------------------------------------------------------------------------------
# DONE Add `@database` as an app that can be moved.
# DONE Added logging
# DONE Added USB Copy to show how to move USB Copy database (move mode only)
#------------------------------------------------------------------------------

scriptver="v4.2.75"
script=Synology_app_mover
repo="007revad/Synology_app_mover"
scriptname=syno_app_mover
logpath="$(dirname "$(realpath "$0")")"
logfile="$logpath/scriptname_$(date +%Y-%m-%d_%H-%M).log"

# Prevent Entware or user edited PATH causing issues
# shellcheck disable=SC2155  # Declare and assign separately to avoid masking return values
export PATH=$(echo "$PATH" | sed -e 's/\/opt\/bin:\/opt\/sbin://')

ding(){ 
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}"
    printf \\a
}

# Save options used
args=("$@")


if [[ $1 == "--debug" ]] || [[ $1 == "-d" ]]; then
    set -x
    export PS4='`[[ $? == 0 ]] || echo "\e[1;31;40m($?)\e[m\n "`LINE $LINENO '
fi

if [[ $1 == "--trace" ]] || [[ $1 == "-t" ]]; then
    trace="yes"
fi

if [[ ${1,,} == "--fix" ]]; then
    # Bypass exit if dependent package failed to stop
    # For restoring broken package to original volume
    fix="yes"
fi

# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    ding
    echo -e "${Error}ERROR${Off} This script must be run as sudo or root!"
    exit 1  # Not running as root
fi

# Check script is running on a Synology NAS
if ! /usr/bin/uname -a | grep -i synology >/dev/null; then
    echo "This script is NOT running on a Synology NAS!"
    echo "Copy the script to a folder on the Synology"
    echo "and run it from there."
    exit 1  # Not a Synology NAS
fi

# Get NAS model
model=$(cat /proc/sys/kernel/syno_hw_version)
#modelname="$model"

# Show script version
#echo -e "$script $scriptver\ngithub.com/$repo\n"
echo "$script $scriptver"

# Get DSM full version
productversion=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION productversion)
buildphase=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION buildphase)
buildnumber=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION buildnumber)
smallfixnumber=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION smallfixnumber)
majorversion=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION majorversion)
#minorversion=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION minorversion)

# Show DSM full version and model
if [[ $buildphase == GM ]]; then buildphase=""; fi
if [[ $smallfixnumber -gt "0" ]]; then smallfix="-$smallfixnumber"; fi
echo -e "$model DSM $productversion-$buildnumber$smallfix $buildphase\n"


usage(){ 
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -h, --help            Show this help message
  -v, --version         Show the script version
      --autoupdate=AGE  Auto update script (useful when script is scheduled)
                          AGE is how many days old a release must be before
                          auto-updating. AGE must be a number: 0 or greater

      --auto=APP        Automatically backup APP (for scheduling backups)
                          APP can be a single app or a comma separated list
                          Examples:
                          --auto=radarr
                          --auto=Calender,ContainerManager,radarr

                          APP needs to be the app's system name
                          View the system names with the --list option

      --list            Display installed apps' system names
                          
EOF
}

list_names(){ 
    # List app system names
    if ! cd /var/packages; then
        echo "Failed to cd to /var/packages!"
        exit 1
    fi

    # Print header
    echo -e "Use app system name for --auto option or exclude in conf file\n"
    printf -- '-%.0s' {1..62}; echo  # print 62 -
    echo "APP SYSTEM NAME              APP DISPLAY NAME"
    printf -- '-%.0s' {1..62}; echo  # print 62 -

    for p in *; do
        if [[ -d "$p" ]]; then
            if [[ ! -a "$p/target" ]] ; then
                echo -e "\e[41mBroken symlink\e[0m $p"
            else
                long_name="$(/usr/syno/bin/synogetkeyvalue "/var/packages/${p}/INFO" displayname)"
                if [[ -z "$long_name" ]]; then
                    long_name="$(/usr/syno/bin/synogetkeyvalue "/var/packages/${p}/INFO" package)"
                fi
                # Pad with spaces to 29 chars
                pad=$(printf -- ' %.0s' {1..29})
                printf '%.*s' 29 "$p${pad}"

                echo "$long_name"
            fi
        fi
    done < <(find . -maxdepth 1 -type d)
    echo ""
    exit 0
}

scriptversion(){ 
    cat <<EOF
$script $scriptver - by 007revad

See https://github.com/$repo
EOF
    exit 0
}


# Save options used for getopt
args=("$@")

autoupdate=""

# Check for flags with getopt
if options="$(getopt -o abcdefghijklmnopqrstuvwxyz0123456789 -l \
    auto:,list,help,version,autoupdate:,log,debug -- "${args[@]}")"; then
    eval set -- "$options"
    while true; do
        case "${1,,}" in
            -h|--help)          # Show usage options
                usage
                exit
                ;;
            -v|--version)       # Show script version
                scriptversion
                ;;
            -l|--log)           # Log
                log=yes
                ;;
            -d|--debug)         # Show and log debug info
                debug=yes
                ;;
            --list)             # List installed app's system names
                list_names
                ;;
            --auto)             # Specify pkgs for scheduled backup
                auto="yes"
                color=no        # Disable colour text in task scheduler emails
                mode="Backup"
                action="Backing up"
                if [[ ${2,,} == "all" ]]; then
                    all="yes"
                elif [[ $2 ]]; then
                    IFS=',' read -r -a autos <<< "$2"; unset IFS
                    if [[ ${#autos[@]} -gt "0" ]]; then
                        for i in "${autos[@]}"; do
                            # Trim leading and trailing spaces
                            j=$(echo -n "$i" | xargs)
                            # Check pkg name exists
                            if [[ ! -d "/var/packages/$j" ]]; then
                                echo -e "Invalid auto argument '$j'\n"
                            else
                                if readlink -f "/var/packages/$j/target" | grep -q -E '^/volume'; then
                                    autolist+=("$j")
                                else
                                    skipped+=("$j")
                                fi
                            fi
                        done
                    else
                        ding
                        echo -e "Missing argument to auto!\n"
                        usage
                        exit 2  # Missing argument
                    fi
                else
                    ding
                    echo -e "Missing argument to auto!\n"
                    usage
                    exit 2  # Missing argument
                fi
                shift
                ;;
            --autoupdate)       # Auto update script
                autoupdate=yes
                if [[ $2 =~ ^[0-9]+$ ]]; then
                    delay="$2"
                    shift
                else
                    delay="0"
                fi
                ;;
            --)
                shift
                break
                ;;
            *)                  # Show usage options
                ding
                echo -e "Invalid option '$1'\n"
                usage
                exit 2  # Invalid argument
                ;;
        esac
        shift
    done
else
    echo
    usage
    exit
fi

# Abort if autolist is empty
if [[ $auto == "yes" ]] && [[ ! ${#autolist[@]} -gt "0" ]]; then
    ding
    echo -e "No apps to backup!\n"
    exit 2  # autolist empty
fi

# Show apps to auto backup
#if [[ ${#autolist[@]} -gt "0" ]]; then     # debug
#    echo -e "Backing up ${autolist[*]}\n"  # debug
#fi                                         # debug

if [[ $debug == "yes" ]]; then
    set -x
    export PS4='`[[ $? == 0 ]] || echo "\e[1;31;40m($?)\e[m\n "`:.$LINENO:'
fi

# Shell Colors
if [[ $color != "no" ]]; then
    #Black='\e[0;30m'   # ${Black}
    Red='\e[0;31m'      # ${Red}
    #Green='\e[0;32m'   # ${Green}
    Yellow='\e[0;33m'   # ${Yellow}
    #Blue='\e[0;34m'    # ${Blue}
    #Purple='\e[0;35m'  # ${Purple}
    Cyan='\e[0;36m'     # ${Cyan}
    #White='\e[0;37m'   # ${White}
    Error='\e[41m'      # ${Error}
    #Warn='\e[47;31m'   # ${Warn}
    Off='\e[0m'         # ${Off}
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

# Release published date
published=$(echo "$release" | grep '"published_at":' | sed -E 's/.*"([^"]+)".*/\1/')
published="${published:0:10}"
published=$(date -d "$published" '+%s')

# Today's date
now=$(date '+%s')

# Days since release published
age=$(((now - published)/(60*60*24)))


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
        if [[ $autoupdate == "yes" ]]; then
            if [[ $age -gt "$delay" ]] || [[ $age -eq "$delay" ]]; then
                echo "Downloading $tag"
                reply=y
            else
                echo "Skipping as $tag is less than $delay days old."
            fi
        else
            echo -e "${Cyan}Do you want to download $tag now?${Off} [y/n]"
            read -r -t 30 reply
        fi

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
                                # Set permission on config file
                                if ! chmod 664 "/tmp/$script-$shorttag/${scriptname}.conf"; then
                                    permerr=1
                                    echo -e "${Error}ERROR${Off} Failed to set read/write permissions on:"
                                    echo "$scriptpath/${scriptname}.conf"
                                fi

                                # Copy existing conf file settings to new conf file
                                while read -r LINE; do
                                    if [[ ${LINE:0:1} != "#" ]]; then
                                        if [[ $LINE =~ ^[a-z_]+=.* ]]; then
                                            oldfile="${scriptpath}/${scriptname}.conf"
                                            newfile="/tmp/$script-$shorttag/${scriptname}.conf"
                                            key="${LINE%=*}"
                                            oldvalue="$(synogetkeyvalue "$oldfile" "$key")"
                                            newvalue="$(synogetkeyvalue "$newfile" "$key")"
                                            if [[ $oldvalue != "$newvalue" ]]; then
                                                synosetkeyvalue "$newfile" "$key" "$oldvalue"
                                            fi
                                        fi
                                    fi    
                                done < "${scriptpath}/${scriptname}.conf"

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
                                # Set permissions on CHANGES.txt
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
# Fix line endings
# grep can't detect Windows or Mac line endings 
#   but can detect if there's no Linux endings.
if grep -rIl -m 1 $'\r' "$conffile" >/dev/null; then
    # Does not contain Linux line endings
    sed -i 's/\r\n/\n/g' "$conffile"  # Fix Windows line endings
    sed -i 's/\r/\n/g' "$conffile"    # Fix Mac line endings
fi

# Add log header
echo "$script $scriptver" > "$logfile"
echo -e "$model DSM $productversion-$buildnumber$smallfix $buildphase\n" >> "$logfile"
echo "Running from: ${scriptpath}/$scriptfile" >> "$logfile"


#------------------------------------------------------------------------------
# Functions

# shellcheck disable=SC2317,SC2329  # Don't warn about unreachable commands in this function
pause(){ 
    # When debugging insert pause command where needed
    read -s -r -n 1 -p "Press any key to continue..."
    read -r -t 0.1 -s -e --  # Silently consume all input
    stty echo echok  # Ensure read didn't disable echoing user input
    echo -e "\n" |& tee -a "$logfile"
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
        echo -ne "  ${2}$progress\r"; /usr/bin/sleep 0.3
    done
}

progstatus(){ 
    # $1 is return status of process
    # $2 is string to echo
    # $3 line number function was called from
    local tracestring
    local pad
    tracestring="${FUNCNAME[0]} called from ${FUNCNAME[1]} $3"
    pad=$(printf -- ' %.0s' {1..80})
    [ "$trace" == "yes" ] && printf '%.*s' 80 "${tracestring}${pad}" && echo ""
    if [[ $1 == "0" ]]; then
        echo -e "$2            "
    else
        ding
        echo -e "Line ${LINENO}: ${Error}ERROR${Off} $2 failed!" |& tee -a "$logfile"
        echo "$tracestring ($scriptver)" |& tee -a "$logfile"
        if [[ $exitonerror != "no" ]]; then
            exit 1  # Skip exit if exitonerror != no
        fi
    fi
    exitonerror=""
    #echo "return: $1"  # debug
}

package_status(){ 
    # $1 is package name
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
#    local code
    /usr/syno/bin/synopkg status "${1}" >/dev/null
    code="$?"
    # DSM 7.2       0 = started, 17 = stopped, 255 = not_installed, 150 = broken
    # DSM 6 to 7.1  0 = started,  3 = stopped,   4 = not_installed, 150 = broken
    if [[ $code == "0" ]]; then
        #echo "$1 is started"  # debug
        return 0
    elif [[ $code == "17" ]] || [[ $code == "3" ]]; then
        #echo "$1 is stopped"  # debug
        return 1
    elif [[ $code == "255" ]] || [[ $code == "4" ]]; then
        #echo "$1 is not installed"  # debug
        return 255
    elif [[ $code == "150" ]]; then
        #echo "$1 is broken"  # debug
        return 150
    else
        return "$code"
    fi
}

package_is_running(){ 
    # $1 is package name
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
    /usr/syno/bin/synopkg is_onoff "${1}" >/dev/null
    code="$?"
    return "$code"
}

wait_status(){ 
    # Wait for package to finish stopping or starting
    # $1 is package
    # $2 is start or stop
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
    local num
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
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
    timeout 5.0m /usr/syno/bin/synopkg stop "$1" >/dev/null &
    pid=$!
    string="Stopping ${Cyan}${2}${Off}"
    echo "Stopping $2" >> "$logfile"
    progbar "$pid" "$string"
    wait "$pid"
    progstatus "$?" "$string" "line ${LINENO}"

    # Allow package processes to finish stopping
    #wait_status "$1" stop
    wait_status "$1" stop &
    pid=$!
    string="Waiting for ${Cyan}${2}${Off} to stop"
    echo "Waiting for $2 to stop" >> "$logfile"
    progbar "$pid" "$string"
    wait "$pid"
    progstatus "$?" "$string" "line ${LINENO}"
}

package_start(){ 
    # $1 is package name
    # $2 is package display name
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
    timeout 5.0m /usr/syno/bin/synopkg start "$1" >/dev/null &
    pid=$!
    string="Starting ${Cyan}${2}${Off}"
    echo "Starting $2" >> "$logfile"
    progbar "$pid" "$string"
    wait "$pid"
    progstatus "$?" "$string" "line ${LINENO}"

    # Allow package processes to finish starting
    #wait_status "$1" start
    wait_status "$1" start &
    pid=$!
    string="Waiting for ${Cyan}${2}${Off} to start"
    echo "Waiting for $2 to start" >> "$logfile"
    progbar "$pid" "$string"
    wait "$pid"
    progstatus "$?" "$string" "line ${LINENO}"
}

# shellcheck disable=SC2317  # Don't warn about unreachable commands in this function
package_uninstall(){ 
    # $1 is package name
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
    /usr/syno/bin/synopkg uninstall "$1" >/dev/null &
    pid=$!
    string="Uninstalling ${Cyan}${1}${Off}"
    echo "Ininstalling $1" >> "$logfile"
    progbar "$pid" "$string"
    wait "$pid"
    progstatus "$?" "$string" "line ${LINENO}"
}

# shellcheck disable=SC2317  # Don't warn about unreachable commands in this function
package_install(){ 
    # $1 is package name
    # $2 is /volume2 etc
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
    /usr/syno/bin/synopkg install_from_server "$1" "$2" >/dev/null &
    pid=$!
    string="Installing ${Cyan}${1}${Off} on ${Cyan}$2${Off}"
    echo "Installing $1 on $2" >> "$logfile"
    progbar "$pid" "$string"
    wait "$pid"
    progstatus "$?" "$string" "line ${LINENO}"
}

is_empty(){ 
    # $1 is /path/folder
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
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
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
    local perms
    if [[ -d "$2/$1" ]]; then

        # Make backup folder on $2
        if [[ ! -d "${2}/${1}_backup" ]]; then
            # Set same permissions as original folder
            perms=$(stat -c %a "${2:?}/${1:?}")
            if ! mkdir -m "$perms" "${2:?}/${1:?}_backup"; then
                ding
                echo -e "Line ${LINENO}: ${Error}ERROR${Off} Failed to create directory!"
                echo -e "Line ${LINENO}: ERROR Failed to create directory!" >> "$logfile"
                process_error="yes"
                if [[ $all != "yes" ]] || [[ $fix != "yes" ]]; then
                    exit 1  # Skip exit if mode != all and fix != yes
                fi
                return 1
            fi
        fi

        # Backup $1
        if ! is_empty "${2:?}/${1:?}_backup"; then
            # @docker_backup folder exists and is not empty
            echo -e "There is already a backup of $1" |& tee -a "$logfile"
            echo -e "Do you want to overwrite it? [y/n]" |& tee -a "$logfile"
            read -r answer
            echo "$answer" >> "$logfile"
            echo "" |& tee -a "$logfile"
            if [[ ${answer,,} != "y" ]]; then
                return
            fi
        fi

        cp -prf "${2:?}/${1:?}/." "${2:?}/${1:?}_backup" |& tee -a "$logfile" &
        pid=$!
        # If string is too long progbar repeats string for each dot
        string="Backing up $1 to ${Cyan}${1}_backup${Off}"
        echo "Backing up $1 to ${1}_backup" >> "$logfile"
        progbar "$pid" "$string"
        wait "$pid"
        progstatus "$?" "$string" "line ${LINENO}"
    fi
}

cdir(){ 
    # $1 is path to cd to
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
    if ! cd "$1"; then
        ding
        echo -e "Line ${LINENO}: ${Error}ERROR${Off} cd to $1 failed!"
        echo -e "Line ${LINENO}: ERROR cd to $1 failed!" >> "$logfile"
        process_error="yes"
        if [[ $all != "yes" ]] || [[ $fix != "yes" ]]; then
            exit 1  # Skip exit if mode != all and fix != yes
        fi
        return 1
    fi
}

create_dir(){ 
    # $1 is source /path/folder
    # $2 is target /path/folder
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"

    # Create target folder with source folder's permissions
    if [[ ! -d "$2" ]]; then
        # Set same permissions as original folder
        perms=$(stat -c %a "${1:?}")
        if ! mkdir -m "$perms" "${2:?}"; then
            ding
            echo -e "Line ${LINENO}: ${Error}ERROR${Off} Failed to create directory!"
            echo -e "Line ${LINENO}: ERROR Failed to create directory!" >> "$logfile"
            process_error="yes"
            if [[ $all != "yes" ]] || [[ $fix != "yes" ]]; then
                exit 1  # Skip exit if mode != all and fix != yes
            fi
            return 1
        fi
    fi
}

move_pkg_do(){ 
    # $1 is package name
    # $2 is destination volume or path
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"

    # Move package's @app directories
    if [[ ${mode,,} == "move" ]]; then
        #mv -f "${source:?}" "${2:?}/${appdir:?}" |& tee -a "$logfile" &
        #pid=$!
        #string="${action} $source to ${Cyan}$2${Off}"
        #echo "${action} $source to $2" >> "$logfile"
        #progbar "$pid" "$string"
        #wait "$pid"
        #progstatus "$?" "$string"

        if [[ ! -d "${2:?}/${appdir:?}/${1:?}" ]] ||\
            is_empty "${2:?}/${appdir:?}/${1:?}"; then

            # Move source folder to target folder
            if [[ -w "/$sourcevol" ]]; then
                mv -f "${source:?}" "${2:?}/${appdir:?}" |& tee -a "$logfile" &
            else
                # Source volume if read only
                cp -prf "${source:?}" "${2:?}/${appdir:?}" |& tee -a "$logfile" &
            fi
            pid=$!
            string="${action} $source to ${Cyan}$2${Off}"
            echo "${action} $source to $2" >> "$logfile"
            progbar "$pid" "$string"
            wait "$pid"
            progstatus "$?" "$string" "line ${LINENO}"
        else

            # Copy source contents if target folder exists
            cp -prf "${source:?}" "${2:?}/${appdir:?}" |& tee -a "$logfile" &
            pid=$!
            string="Copying $source to ${Cyan}$2${Off}"
            echo "Copying $source to $2" >> "$logfile"
            progbar "$pid" "$string"
            wait "$pid"
            progstatus "$?" "$string" "line ${LINENO}"

            #rm -rf "${source:?}" |& tee -a "$logfile" &
            rm -r --preserve-root "${source:?}" |& tee -a "$logfile" &
            pid=$!
            exitonerror="no"
            string="Removing $source"
            echo "$string" >> "$logfile"
            progbar "$pid" "$string"
            wait "$pid"
            progstatus "$?" "$string" "line ${LINENO}"
        fi
    else
#        if ! is_empty "${destination:?}/${appdir:?}/${1:?}"; then
#            echo "Skipping ${action,,} ${appdir}/$1 as target is not empty:" |& tee -a "$logfile"
#            echo "  ${destination}/${appdir}/$1" |& tee -a "$logfile"
#        else
            #mv -f "${source:?}" "${2:?}/${appdir:?}" |& tee -a "$logfile" &
            #pid=$!
            #string="${action} $source to ${Cyan}$2${Off}"
            #echo "${action} $source to $2" >> "$logfile"
            #progbar "$pid" "$string"
            #wait "$pid"
            #progstatus "$?" "$string"
            exitonerror="no" && move_dir "$appdir"
#        fi
    fi
}

edit_symlinks(){ 
    # $1 is package name
    # $2 is destination volume
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"

    # Edit /var/packages symlinks
    case "$appdir" in
        @appconf)  # etc --> @appconf
            rm "/var/packages/${1:?}/etc" |& tee -a "$logfile"
            ln -s "${2:?}/@appconf/${1:?}" "/var/packages/${1:?}/etc" |& tee -a "$logfile"

            # /usr/syno/etc/packages/$1
            # /volume1/@appconf/$1
            if [[ -L "/usr/syno/etc/packages/${1:?}" ]]; then
                rm "/usr/syno/etc/packages/${1:?}" |& tee -a "$logfile"
                ln -s "${2:?}/@appconf/${1:?}" "/usr/syno/etc/packages/${1:?}" |& tee -a "$logfile"
            fi
            ;;
        @apphome)  # home --> @apphome
            rm "/var/packages/${1:?}/home" |& tee -a "$logfile"
            ln -s "${2:?}/@apphome/${1:?}" "/var/packages/${1:?}/home" |& tee -a "$logfile"
            ;;
        @appshare)  # share --> @appshare
            rm "/var/packages/${1:?}/share" |& tee -a "$logfile"
            ln -s "${2:?}/@appshare/${1:?}" "/var/packages/${1:?}/share" |& tee -a "$logfile"
            ;;
        @appstore)  # target --> @appstore
            rm "/var/packages/${1:?}/target" |& tee -a "$logfile"
            ln -s "${2:?}/@appstore/${1:?}" "/var/packages/${1:?}/target" |& tee -a "$logfile"

            # DSM 6 - Some packages have var symlink
            if [[ $majorversion -lt 7 ]]; then
                if [[ -L "/var/packages/${1:?}/var" ]]; then
                    rm "/var/packages/${1:?}/var" |& tee -a "$logfile"
                    ln -s "${2:?}/@appstore/${1:?}/var" "/var/packages/${1:?}/var" |& tee -a "$logfile"
                fi
            fi
            ;;
        @apptemp)  # tmp --> @apptemp
            rm "/var/packages/${1:?}/tmp" |& tee -a "$logfile"
            ln -s "${2:?}/@apptemp/${1:?}" "/var/packages/${1:?}/tmp" |& tee -a "$logfile"
            ;;
        @appdata)  # var --> @appdata
            rm "/var/packages/${1:?}/var" |& tee -a "$logfile"
            ln -s "${2:?}/@appdata/${1:?}" "/var/packages/${1:?}/var" |& tee -a "$logfile"
            ;;
        *)
            echo -e "${Red}Oops!${Off} appdir: ${appdir}\n"
            echo -e "Oops! appdir: ${appdir}\n" >> "$logfile"
            return
            ;;
    esac
}

move_pkg(){ 
    # $1 is package name
    # $2 is destination volume
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
    local appdir
    local perms
    local destination
    local appdirs_tmp
    local app_paths_tmp
    if [[ ${mode,,} == "backup" ]]; then
        destination="$bkpath"
    elif [[ ${mode,,} == "restore" ]]; then
        destination="$2"
    else
        destination="$2"
    fi    
    if [[ $majorversion -gt 6 ]]; then
        applist=( "@appconf" "@appdata" "@apphome" "@appshare" "@appstore" "@apptemp" )
    else
        applist=( "@appstore" )
    fi
    if [[ ${mode,,} == "restore" ]]; then
        if ! cdir "$bkpath"; then
            process_error="yes"
            return 1
        fi
        sourcevol=$(echo "$bkpath" | cut -d "/" -f2)  # var is used later in script
        # shellcheck disable=SC1083
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
        if ! cdir /var/packages; then
            process_error="yes"
            return 1
        fi
        # shellcheck disable=SC2162  # `read` without `-r` will mangle backslashes
        while read -r link source; do
            app_paths_tmp+=("$source")
        done < <(find . -maxdepth 2 -type l -ls | grep '/'"${1// /\\\\ }"'$' | cut -d'.' -f2- | sed 's/ ->//')

        # Sort array
        IFS=$'\n' app_paths=($(sort <<<"${app_paths_tmp[*]}")); unset IFS

        if [[ ${#app_paths[@]} -gt 0 ]]; then
            for source in "${app_paths[@]}"; do
                appdir=$(echo "$source" | cut -d "/" -f3)
                sourcevol=$(echo "$source" | cut -d "/" -f2)  # var is used later in script
                if [[ "${applist[*]}" =~ "$appdir" ]]; then
                    create_dir "/${sourcevol:?}/${appdir:?}" "${destination:?}/${appdir:?}"
                    move_pkg_do "$1" "$2"
                    if [[ ${mode,,} == "move" ]]; then
                        edit_symlinks "$pkg" "$destination"
                    fi
                fi
            done
        fi
    fi

    # Backup or restore DSM 6 /usr/syno/etc/packages/$pkg/
    if [[ $majorversion -lt "7" ]]; then
        copy_dir_dsm6 "$1" "$2"
    fi
}

set_buffer(){ 
    # Set buffer GBs so we don't fill volume
    bufferGB=$(/usr/syno/bin/synogetkeyvalue "$conffile" buffer)
    if [[ $bufferGB -gt "0" ]]; then
        buffer=$((bufferGB *1048576))
    else
        buffer=0
    fi
}

folder_size(){ 
    # $1 is folder to check size of
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
    need=""    # var is used later in script
    needed=""  # var is used later in script
    if [[ -d "$1" ]]; then
        # Get size of $1 folder
        need=$(/usr/bin/du -s "$1" | awk '{print $1}')
        if [[ ! $need =~ ^[0-9]+$ ]]; then
            echo -e "${Yellow}WARNING${Off} Failed to get size of $1"
            echo -e "WARNING Failed to get size of $1" >> "$logfile"
            need=0
        fi
        # Add buffer GBs so we don't fill volume
        set_buffer
        needed=$((need +buffer))
    fi
}

vol_free_space(){ 
    # $1 is volume to check free space
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
    free=""  # var is used later in script
    if [[ -d "$1" ]]; then
        # Get amount of free space on $1 volume
        #free=$(df --output=avail "$1" | grep -A1 Avail | grep -v Avail)  # dfs / for USB drives. # Issue #63
        free=$(df | grep "$1"$ | awk '{print $4}')                # dfs correctly for USB drives. # Issue #63
    fi
}

need_show(){ 
    if [[ $need -gt "999999" ]]; then
        size_show="$((need /1048576)) GB"
    elif [[ $need -gt "999" ]]; then
        size_show="$((need /1048)) MB"
    else
        size_show="$need KB"
    fi
}

check_space(){ 
    # $1 is /path/folder
    # $2 is source volume or target volume
    # $3 is 'extra' or null
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"

    # Skip USBCopy and @database
    if [[ $pkg == USBCopy ]] || [[ $pkg == "@database" ]]; then
        return 0
    fi

    if [[ $3 == "extra" ]]; then
        # Get size of extra @ folder
        folder_size "$1"
    else
        # Total size of pkg or all pkgs
        need="$all_pkg_size"
        # Add buffer GBs so we don't fill volume
        set_buffer
        needed=$((need +buffer))
    fi

    # Get amount of free space on target volume
    vol_free_space "$2"

    # Check we have enough space
    if [[ ! $free -gt $needed ]]; then
        if [[ $all == "yes" ]] && [[ $3 != "extra" ]]; then
            echo -e "${Yellow}WARNING${Off} Not enough space to ${mode,,}"\
                "${Cyan}All apps${Off} to $targetvol"
            echo -e "WARNING Not enough space to ${mode,,}"\
                "All apps to $targetvol" >> "$logfile"
        else
            echo -e "${Yellow}WARNING${Off} Not enough space to ${mode,,}"\
                "/${sourcevol}/${Cyan}$(basename -- "$1")${Off} to $targetvol"
            echo -e "WARNING Not enough space to ${mode,,}"\
                "/${sourcevol}/$(basename -- "$1") to $targetvol" >> "$logfile"
        fi
        need_show
        echo -en "Free: $((free /1048576)) GB  Needed: $size_show" |& tee -a "$logfile"
        if [[ $buffer -gt "0" ]]; then
            echo -e " (plus $bufferGB GB buffer)\n" |& tee -a "$logfile"
        else
            echo -e "\n" |& tee -a "$logfile"
        fi
        return 1
    else
        return 0
    fi
}

show_move_share(){ 
    # $1 is package name
    # $2 is share name
    # $3 is stopped or running
    # $4 is more or null
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
    echo -e "\nIf you want to move your $2 shared folder to $targetvol" |& tee -a "$logfile"
    echo -e "  While ${Cyan}$1${Off} is ${Cyan}$3${Off}:"
    echo -e "  While $1 is $3:" >> "$logfile"
    echo "  1. Go to 'Control Panel > Shared Folders'." |& tee -a "$logfile"
    echo "  2. Select your $2 shared folder and click Edit." |& tee -a "$logfile"
    echo "  3. Change Location to $targetvol" |& tee -a "$logfile"
    echo "  4. Click on Advanced and check that 'Enable data checksums' is selected." |& tee -a "$logfile"
    echo "    - 'Enable data checksums' is only available if moving to a Btrfs volume." |& tee -a "$logfile"
    echo "  5. Click Save." |& tee -a "$logfile"
    if [[ $4 == "more" ]]; then
        echo "    - If $1 has more shared folders repeat steps 2 to 5." |& tee -a "$logfile"
    fi
    if [[ $3 == "stopped" ]]; then
        echo -e "  6. After step 5 has finished start $1 \n" |& tee -a "$logfile"
    fi
}

copy_dir_dsm6(){ 
    # Backup or restore DSM 6 /usr/syno/etc/packages/$pkg/
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
    # $1 is package name
    # $2 is destination volume
    local pack
    local packshow
    local extras
    pack="/${pkg:?}"
    packshow="${pkg:?}"
    if [[ ${mode,,} == "backup" ]]; then
        if [[ ! -d "${bkpath:?}/etc" ]]; then
            mkdir -m 700 "${bkpath:?}/etc"
        fi

        #if ! is_empty "/usr/syno/etc/packages/${1:?}"; then
            # If string is too long progbar gets messed up
            cp -prf "/usr/syno/etc/packages/${1:?}" "${bkpath:?}/etc" |& tee -a "$logfile" &
            pid=$!
            string="${action} /usr/syno/etc/packages/${Cyan}${1}${Off}"
            echo "${action} /usr/syno/etc/packages/${1}" >> "$logfile"
            progbar "$pid" "$string"
            wait "$pid"
            progstatus "$?" "$string" "line ${LINENO}"
        #fi
    elif [[ ${mode,,} == "restore" ]]; then
        #if [[ -d "${bkpath}/$1" ]]; then
            # If string is too long progbar gets messed up
            cp -prf "${bkpath:?}/etc/${1:?}" "/usr/syno/etc/packages" |& tee -a "$logfile" &
            pid=$!
            string="${action} $1 to /usr/syno/etc/packages"
            echo "$string" >> "$logfile"
            progbar "$pid" "$string"
            wait "$pid"
            progstatus "$?" "$string" "line ${LINENO}"
        #fi
    fi
}

copy_dir(){ 
    # Used by package backup and restore
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
    # $1 is folder (@surveillance etc)
    # $2 is "extras" or null
    local pack
    local packshow
    local extras
    if [[ $2 == "extras" ]]; then
        #pack=""
        extras="/extras"
    else
        pack="/${pkg:?}"
        packshow="${pkg:?}"
        #extras=""
    fi

    if [[ ${mode,,} == "backup" ]]; then
        if [[ $2 == "extras" ]] && [[ ! -d "${bkpath:?}/extras" ]]; then
            mkdir -m 700 "${bkpath:?}/extras"
        fi
        create_dir "/${sourcevol:?}/${1:?}$pack" "${bkpath:?}${extras}/${1:?}"
        #if ! is_empty "/${sourcevol:?}/${1:?}$pack"; then
            if [[ $2 == "extras" ]]; then
                # If string is too long progbar gets messed up
                #cp -prf "/${sourcevol:?}/${1:?}$pack" "${bkpath:?}${extras}" |& tee -a "$logfile" &
                if [[ $1 == "@docker" ]]; then
                    excludeargs=(
                        "--exclude=subvolumes/*/tmp/"  # btfs        Issue #120
                        "--exclude=subvolumes/*/run/"  # btfs        Issue #120
                        "--exclude=aufs/diff/*/run/"   # aufs (ext4) Issue #117
                    )
                    rsync -q -aHX --delete --compress-level=0 "${excludeargs[@]}" "/${sourcevol:?}/${1:?}$pack"/ "${bkpath:?}${extras}/${1:?}" |& tee -a "$logfile" &
                else
                    rsync -q -aHX --delete --compress-level=0 "/${sourcevol:?}/${1:?}$pack"/ "${bkpath:?}${extras}/${1:?}" |& tee -a "$logfile" &
                fi
                pid=$!
                string="${action} /${sourcevol}/${1}"
                echo "$string" >> "$logfile"
                progbar "$pid" "$string"
                wait "$pid"
                progstatus "$?" "$string" "line ${LINENO}"
            else
                # If string is too long progbar gets messed up
                #cp -prf "/${sourcevol:?}/${1:?}$pack" "${bkpath:?}${extras}/${1:?}" |& tee -a "$logfile" &
                rsync -q -aHX --delete --compress-level=0 "/${sourcevol:?}/${1:?}$pack"/ "${bkpath:?}${extras}/${1:?}" |& tee -a "$logfile" &
                pid=$!
                string="${action} /${sourcevol}/${1}/${Cyan}$pkg${Off}"
                echo "${action} /${sourcevol}/${1}/$pkg" >> "$logfile"
                progbar "$pid" "$string"
                wait "$pid"
                progstatus "$?" "$string" "line ${LINENO}"
            fi
        #fi
    elif [[ ${mode,,} == "restore" ]]; then
        #if [[ -d "${bkpath}/$1" ]]; then
            # If string is too long progbar gets messed up
            cp -prf "${bkpath:?}${extras}/${1:?}" "${targetvol:?}" |& tee -a "$logfile" &
            pid=$!
            if [[ -n "$extras" ]]; then
                string="${action} $1 to $targetvol"
                echo "$string" >> "$logfile"
            else
                string="${action} ${1}/${Cyan}$packshow${Off} to $targetvol"
                echo "${action} ${1}/$packshow to $targetvol" >> "$logfile"
            fi
            progbar "$pid" "$string"
            wait "$pid"
            progstatus "$?" "$string" "line ${LINENO}"
        #fi
    fi
}

move_dir(){ 
    # $1 is folder (@surveillance etc)
    # $2 is "extras" or null
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"

    # Delete @eaDir to prevent errors
    # e.g. "mv: cannot remove '/volume1/@<folder>': Operation not permitted"
    if [[ -d "/${sourcevol:?}/${1:?}/@eaDir" ]]; then
        rm -rf "/${sourcevol:?}/${1:?}/@eaDir" |& tee -a "$logfile"
    fi

    # Warn if folder is larger than 1GB
    if [[ ! "${applist[*]}" =~ $1 ]]; then
        folder_size "/${sourcevol:?}/$1"
        if [[ $need -gt "1048576" ]]; then
            echo -e "${Red}WARNING $action $1 could take a long time${Off}"
            echo -e "WARNING $action $1 could take a long time" >> "$logfile"
        fi
    fi

    if [[ -d "/${sourcevol:?}/${1:?}" ]]; then
        if [[ ${mode,,} == "move" ]]; then
            if [[ ! -d "/${targetvol:?}/${1:?}" ]]; then
                if [[ $1 == "@docker" ]] || [[ $1 == "@img_bkp_cache" ]]; then
                    # Create @docker folder on target volume
                    create_dir "/${sourcevol:?}/${1:?}" "${targetvol:?}/${1:?}"
                    # Move contents of @docker to @docker on target volume
                    if [[ -w "/$sourcevol" ]]; then
                        mv -f "/${sourcevol:?}/${1:?}"/* "${targetvol:?}/${1:?}" |& tee -a "$logfile" &
                    else
                        # Source volume if read only
                        cp -prf "/${sourcevol:?}/${1:?}"/* "${targetvol:?}/${1:?}" |& tee -a "$logfile" &
                    fi
                else
                    if [[ -w "/$sourcevol" ]]; then
                        mv -f "/${sourcevol:?}/${1:?}" "${targetvol:?}/${1:?}" |& tee -a "$logfile" &
                    else
                        # Source volume if read only
                        cp -prf "/${sourcevol:?}/${1:?}" "${targetvol:?}/${1:?}" |& tee -a "$logfile" &
                    fi
                fi
                pid=$!
                string="${action} /${sourcevol}/$1 to ${Cyan}$targetvol${Off}"
                echo "$string" >> "$logfile"
                progbar "$pid" "$string"
                wait "$pid"
                progstatus "$?" "$string" "line ${LINENO}"
            elif ! is_empty "/${sourcevol:?}/${1:?}"; then

                # Copy source contents if target folder exists
                cp -prf "/${sourcevol:?}/${1:?}" "${targetvol:?}" |& tee -a "$logfile" &
                pid=$!
                string="Copying /${sourcevol}/$1 to ${Cyan}$targetvol${Off}"
                echo "$string" >> "$logfile"
                progbar "$pid" "$string"
                wait "$pid"
                progstatus "$?" "$string" "line ${LINENO}"

                # Delete source folder if empty
#                if [[ $1 != "@docker" ]]; then
                    if is_empty "/${sourcevol:?}/${1:?}"; then
                        rm -rf --preserve-root "/${sourcevol:?}/${1:?}" |& tee -a "$logfile" &
                        pid=$!
                        exitonerror="no"
                        string="Removing /${sourcevol}/$1"
                        echo "$string" >> "$logfile"
                        progbar "$pid" "$string"
                        wait "$pid"
                        progstatus "$?" "$string" "line ${LINENO}"
                    fi
                fi
#            fi
        else
            copy_dir "$1" "$2"
        fi
    else
        echo -e "No /${sourcevol}/$1 to ${mode,,}" |& tee -a "$logfile"
    fi
}

move_extras(){ 
    # $1 is package name
    # $2 is destination /volume
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
    local file
    local value
    # Change /volume1 to /volume2 etc
    case "$1" in
        ActiveBackup)
            exitonerror="no" && move_dir "@ActiveBackup" extras
            # /var/packages/ActiveBackup/target/log/
            if [[ ${mode,,} != "backup" ]]; then
                if ! readlink /var/packages/ActiveBackup/target/log | grep "${2:?}" >/dev/null; then
                    rm /var/packages/ActiveBackup/target/log |& tee -a "$logfile"
                    ln -s "${2:?}/@ActiveBackup/log" /var/packages/ActiveBackup/target/log |& tee -a "$logfile"
                fi
                file=/var/packages/ActiveBackup/target/etc/setting.conf
                if [[ -f "$file" ]]; then
                    echo "{\"conf_repo_volume_path\":\"$2\"}" > "$file"
                fi
            fi
            ;;
        ActiveBackup-GSuite)
            exitonerror="no" && move_dir "@ActiveBackup-GSuite" extras
            ;;
        ActiveBackup-Office365)
            exitonerror="no" && move_dir "@ActiveBackup-Office365" extras
            ;;
        Chat)
            if [[ ${mode,,} == "move" ]]; then
                echo -e "Are you going to move the ${Cyan}chat${Off} shared folder to ${Cyan}${targetvol}${Off}? [y/n]"
                echo -e "Are you going to move the chat shared folder to ${targetvol}? [y/n]" >> "$logfile"
                read -r answer
                echo "$answer" >> "$logfile"
                echo "" |& tee -a "$logfile"
                if [[ ${answer,,} == y ]]; then
                    # /var/packages/Chat/shares/chat --> /volume1/chat
                    rm "/var/packages/${1:?}/shares/chat" |& tee -a "$logfile"
                    ln -s "${2:?}/chat" "/var/packages/${1:?}shares/chat" |& tee -a "$logfile"
                    # /var/packages/Chat/target/synochat --> /volume1/chat/@ChatWorking
                    rm "/var/packages/${1:?}/target/synochat" |& tee -a "$logfile"
                    ln -s "${2:?}/chat/@ChatWorking" "/var/packages/${1:?}target/synochat" |& tee -a "$logfile"
                fi
            fi
            ;;
        Calendar)
            exitonerror="no" && move_dir "@calendar" extras
            if [[ -d "/@synocalendar" ]]; then
                exitonerror="no" && move_dir "$sourcevol/@synocalendar" extras
            fi
            file="/var/packages/Calendar/etc/share_link.json"
            if [[ -f "$file" ]]; then
                if grep "$sourcevol/@calendar/attach" "$file" >/dev/null; then
                    instring="/$sourcevol/@calendar/attach"
                    repstring="$2/@calendar/attach"
                    sed -i 's|'"$instring"'|'"$repstring"'|g' "$file" |& tee -a "$logfile"
                    chmod 600 "$file" |& tee -a "$logfile"
                fi
            fi
            ;;
        ContainerManager|Docker)

            # /var/services/web_packages/docker ???

            # Edit symlink before moving @docker
            # If edit after it does not get edited if move @docker errors
            if [[ ${mode,,} != "backup" ]]; then
                if [[ $majorversion -gt "6" ]]; then
                    # /var/packages/ContainerManager/var/docker/ --> /volume1/@docker
                    # /var/packages/Docker/var/docker/ --> /volume1/@docker
                    if [[ -L "/var/packages/${pkg:?}/var/docker" ]]; then
                        rm "/var/packages/${pkg:?}/var/docker" |& tee -a "$logfile"
                    fi
                    ln -s "${2:?}/@docker" "/var/packages/${pkg:?}/var/docker" |& tee -a "$logfile"
                else
                    # /var/packages/Docker/target/docker/ --> /volume1/@docker
                    if [[ -L "/var/packages/${pkg:?}/target/docker" ]]; then
                        rm "/var/packages/${pkg:?}/target/docker" |& tee -a "$logfile"
                    fi
                    ln -s "${2:?}/@docker" "/var/packages/${pkg:?}/target/docker" |& tee -a "$logfile"
                fi
            fi
            exitonerror="no" && move_dir "@docker" extras
            ;;
        DownloadStation)
            exitonerror="no" && move_dir "@download" extras
            ;;
        GlacierBackup)
            exitonerror="no" && move_dir "@GlacierBackup" extras
            if [[ ${mode,,} != "backup" ]]; then
                file=/var/packages/GlacierBackup/etc/common.conf
                if [[ -f "$file" ]]; then
                    echo "cache_volume=$2" > "$file"
                fi
            fi
            ;;
        HyperBackup)
            # Most of this section is not needed for moving HyperBackup.
            # I left it here in case I can use it for some other package in future.

            # Moving "@img_bkp_cache" and editing synobackup.conf
            # to point the repos to the new location causes backup tasks
            # to show as offline with no way to fix them or delete them!
            #
            # Thankfully HyperBackup recreates the data in @img_bkp_cache
            # when the backup task is run, or a resync is done.

#            file=/var/packages/HyperBackup/etc/synobackup.conf
            # [repo_1]
            # client_cache="/volume1/@img_bkp_cache/ClientCache_image_image_local.oJCDvd"
#            if [[ -f "$file" ]]; then

                # Get list of [repo_#] in $file
#                readarray -t contents < "$file"
#                for r in "${contents[@]}"; do
#                    l=$(echo "$r" | grep -E "repo_[0-9]+")
#                    if [[ -n "$l" ]]; then
#                        l="${l/]/}" && l="${l/[/}"
#                        repos+=("$l")
#                    fi
#                done

                # Edit values with sourcevol to targetvol
#                for section in "${repos[@]}"; do
#                    value="$(/usr/syno/bin/get_section_key_value "$file" "$section" client_cache)"
#                    #echo "$value"  # debug
#                    if echo "$value" | grep "$sourcevol" >/dev/null; then
#                        newvalue="${value/$sourcevol/$targetvol}"
                        #echo "$newvalue"  # debug
                        #echo ""  # debug
                #        /usr/syno/bin/set_section_key_value "$file" "$section" client_cache "$newvalue"
                        #echo "set_section_key_value $file $section client_cache $newvalue"  # debug
                        #echo ""  # debug
                        #echo ""  # debug
#                    fi
#                done
#            fi

            # Move @img_bkp folders
            #if [[ -d "/${sourcevol}/@img_bkp_cache" ]] ||\
            #    [[ -d "/${sourcevol}/@img_bkp_mount" ]]; then
            #    backup_dir "@img_bkp_cache" "$sourcevol"
            #    backup_dir "@img_bkp_mount" "$sourcevol"

            #    exitonerror="no" && move_dir "@img_bkp_cache"
            #    exitonerror="no" && move_dir "@img_bkp_mount"
            #fi
            if [[ -d "/${sourcevol}/@img_bkp_cache" ]]; then
                #backup_dir "@img_bkp_cache" "$sourcevol"
                exitonerror="no" && move_dir "@img_bkp_cache" extras
            fi
            ;;
        MailPlus-Server)
            # Moving MailPlus-Server does not update
            # /var/packages/MailPlus-Server/etc/synopkg_conf/reg_volume
            # I'm not sure if it matters?

            if [[ ${mode,,} != "backup" ]]; then
                # Edit symlink /var/spool/@MailPlus-Server -> /volume1/@MailPlus-Server
                if ! readlink /var/spool/@MailPlus-Server | grep "${2:?}" >/dev/null; then
                    rm /var/spool/@MailPlus-Server |& tee -a "$logfile"
                    ln -s "${2:?}/@MailPlus-Server" /var/spool/@MailPlus-Server |& tee -a "$logfile"
                    chown -h MailPlus-Server:MailPlus-Server /var/spool/@MailPlus-Server |& tee -a "$logfile"
                fi
                # Edit logfile /volume1/@maillog/rspamd_redis.log
                # in /volume2/@MailPlus-Server/rspamd/redis/redis.conf
                file="/$sourcevol/@MailPlus-Server/rspamd/redis/redis.conf"
                if [[ -f "$file" ]]; then
                    if grep "$sourcevol" "$file" >/dev/null; then
                        sed -i 's|'"logfile /$sourcevol"'|'"logfile ${2:?}"'|g' "$file" |& tee -a "$logfile"
                        chmod 600 "$file" |& tee -a "$logfile"
                    fi
                fi
            fi
            exitonerror="no" && move_dir "@maillog" extras
            exitonerror="no" && move_dir "@MailPlus-Server" extras
            ;;
        MailServer)
            exitonerror="no" && move_dir "@maillog" extras
            exitonerror="no" && move_dir "@MailScanner" extras
            exitonerror="no" && move_dir "@clamav" extras
            ;;
        Node.js_v*)
            if [[ ${mode,,} != "backup" ]]; then
                if readlink /usr/local/bin/node | grep "${1:?}" >/dev/null; then
                    rm /usr/local/bin/node |& tee -a "$logfile"
                    ln -s "${2:?}/@appstore/${1:?}/usr/local/bin/node" /usr/local/bin/node |& tee -a "$logfile"
                fi
                for n in /usr/local/node/nvm/versions/* ; do
                    if readlink "${n:?}/bin/node" | grep "${1:?}" >/dev/null; then
                        rm "${n:?}/bin/node" |& tee -a "$logfile"
                        ln -s "${2:?}/@appstore/${1:?}/usr/local/bin/node" "${n:?}/bin/node" |& tee -a "$logfile"
                    fi
                done
            fi
            ;;
        PrestoServer)
            exitonerror="no" && move_dir "@presto" extras
            if [[ ${mode,,} != "backup" ]]; then
                file=/var/packages/PrestoServer/etc/db-path.conf
                if [[ -f "$file" ]]; then
                    echo "db-vol=${2:?}" > "$file"
                fi
            fi
            ;;
        SurveillanceStation)
            exitonerror="no" && move_dir "@ssbackup" extras
            exitonerror="no" && move_dir "@surveillance" extras
            if [[ ${mode,,} != "backup" ]]; then
                file=/var/packages/SurveillanceStation/etc/settings.conf
                if [[ -f "$file" ]]; then
                    /usr/syno/bin/synosetkeyvalue "$file" active_volume "${2:?}" |& tee -a "$logfile"
                    file=/var/packages/SurveillanceStation/target/@surveillance
                    rm "$file" |& tee -a "$logfile"
                    ln -s "${2:?}/@surveillance" /var/packages/SurveillanceStation/target |& tee -a "$logfile"
                    chown -h SurveillanceStation:SurveillanceStation "$file" |& tee -a "$logfile"
                fi
            fi
            ;;
        synocli*)
            #exitonerror="no" && move_dir "@$1"
            ;;
        SynologyApplicationService)
            exitonerror="no" && move_dir "@SynologyApplicationService" extras
            if [[ ${mode,,} != "backup" ]]; then
                file=/var/packages/SynologyApplicationService/etc/settings.conf
                if [[ -f "$file" ]]; then
                    /usr/syno/bin/synosetkeyvalue "$file" volume "${2:?}/@SynologyApplicationService" |& tee -a "$logfile"
                fi
            fi
            ;;
        SynologyDrive)
            # Synology Drive database
            # Moving the database in Synology Drive Admin moves @synologydrive
            #exitonerror="no" && move_dir "@synologydrive" extras

            # Synology Drive ShareSync Folder
            exitonerror="no" && move_dir "@SynologyDriveShareSync" extras
            if [[ ${mode,,} != "backup" ]]; then
                file=/var/packages/SynologyDrive/etc/sharesync/daemon.conf
                if [[ -f "$file" ]]; then
                    sed -i 's|'/"$sourcevol"'|'"${2:?}"'|g' "$file" |& tee -a "$logfile"
                    chmod 644 "$file" |& tee -a "$logfile"
                fi

                file=/var/packages/SynologyDrive/etc/sharesync/monitor.conf
                if [[ -f "$file" ]]; then
                    value="$(synogetkeyvalue "$file" system_db_path)"
                    if [[ -n $value ]]; then
                        /usr/syno/bin/synosetkeyvalue "$file" system_db_path "${value/${sourcevol}/$(basename "${2:?}")}" |& tee -a "$logfile"
                    fi
                fi

                file=/var/packages/SynologyDrive/etc/sharesync/service.conf
                if [[ -f "$file" ]]; then
                    /usr/syno/bin/synosetkeyvalue "$file" volume "${2:?}" |& tee -a "$logfile"
                fi

                # Moving the database in Synology Drive Admin changes 
                # the repo symlink and the db-vol setting
                # in /var/packages/SynologyDrive/etc/db-path.conf
                #if ! readlink /var/packages/SynologyDrive/etc/repo | grep "${2:?}" >/dev/null; then
                #    rm /var/packages/SynologyDrive/etc/repo |& tee -a "$logfile"
                #    ln -s "${2:?}/@synologydrive/@sync" /var/packages/SynologyDrive/etc/repo |& tee -a "$logfile"
                #fi
            fi
            ;;
        WebDAVServer)
            exitonerror="no" && move_dir "@webdav" extras
            ;;
        Virtualization)
            exitonerror="no" && move_dir "@GuestImage" extras
            exitonerror="no" && move_dir "@Repository" extras

            # Move Virtual Machines - target must be btrfs
            #exitonerror="no" && move_dir "@iSCSI" extras

            # VMM creates /volume#/vdsm_repo.conf so no need to move it
            ;;
        *)
            return
            ;;
    esac
}

web_packages(){ 
    # $1 is pkg in lower case
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
    if [[ $buildnumber -gt "64570" ]]; then
        # DSM 7.2.1 and later
        # synoshare --get-real-path is case insensitive
        web_pkg_path=$(/usr/syno/sbin/synoshare --get-real-path web_packages)
    else
        # DSM 7.2 and earlier
        # synoshare --getmap is case insensitive
        web_pkg_path=$(/usr/syno/sbin/synoshare --getmap web_packages | grep volume | cut -d"[" -f2 | cut -d"]" -f1)
    fi
    if [[ -d "$web_pkg_path" ]]; then
        if [[ -n "${pkg:?}" ]] && [[ -d "$web_pkg_path/${pkg,,}" ]]; then
            if [[ ${mode,,} == "backup" ]]; then
                if [[ ! -d "${bkpath}/web_packages" ]]; then
                    mkdir -m 755 "${bkpath:?}/web_packages"
                fi
                if [[ -d "${bkpath}/web_packages" ]]; then
                    # If string is too long progbar gets messed up
                    cp -prf "${web_pkg_path:?}/${1:?}" "${bkpath:?}/web_packages" |& tee -a "$logfile" &
                    pid=$!
                    string="${action} $web_pkg_path/${pkg,,}"
                    echo "$string" >> "$logfile"
                    progbar "$pid" "$string"
                    wait "$pid"
                    progstatus "$?" "$string" "line ${LINENO}"
                else
                    ding
                    echo -e "Line ${LINENO}: ${Error}ERROR${Off} Failed to create directory!"
                    echo -e "Line ${LINENO}: ERROR Failed to create directory!" >> "$logfile"
                    echo -e "  ${bkpath:?}/web_packages\n" |& tee -a "$logfile"
                fi
            elif [[ ${mode,,} == "restore" ]]; then
                if [[ -d "${bkpath}/web_packages/${1}" ]]; then
                    # If string is too long progbar gets messed up
                    cp -prf "${bkpath:?}/web_packages/${1:?}" "${web_pkg_path:?}" |& tee -a "$logfile" &
                    pid=$!
                    string="${action} $web_pkg_path/${pkg,,}"
                    echo "$string" >> "$logfile"
                    progbar "$pid" "$string"
                    wait "$pid"
                    progstatus "$?" "$string" "line ${LINENO}"
                fi
            fi
        fi
    fi
}

check_pkg_installed(){ 
    # Check if package is installed
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"

    # $1 is package
    # $2 is package name
    /usr/syno/bin/synopkg status "${1:?}" >/dev/null
    code="$?"
    if [[ $code == "255" ]] || [[ $code == "4" ]]; then
        ding
        echo -e "${Error}ERROR${Off} ${Cyan}${2}${Off} is not installed!"
        echo -e "ERROR ${2} is not installed!" >> "$logfile"
        echo -e "Install ${Cyan}${2}${Off} then try Restore again"
        echo -e "Install ${2} then try Restore again" >> "$logfile"
        process_error="yes"
        if [[ $all != "yes" ]]; then
            exit 1  # Skip exit if mode is All
        fi
        return 1
    else
        return 0
    fi
}

check_pkg_versions_match(){ 
    # $1 is installed package version
    # $2 is backed up package version
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
    if [[ $1 != "$2" ]]; then
        ding
        echo -e "${Yellow}Backup and installed package versions don't match!${Off}"
        echo -e "Backup and installed package versions don't match!" >> "$logfile"
        echo "  Backed up version: $2" |& tee -a "$logfile"
        echo "  Installed version: $1" |& tee -a "$logfile"
        echo "Do you want to continue restoring ${pkg_name}? [y/n]" |& tee -a "$logfile"
        read -r reply
        if [[ ${reply,,} != "y" ]]; then
            exit  # Answered no
        else
            echo "" |& tee -a "$logfile"
        fi
    fi
}

skip_dev_tools(){ 
    # $1 is $pkg
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
    local skip1
    local skip2
    if [[ ${mode,,} == "backup" ]]; then
        skip1="$(/usr/syno/bin/synogetkeyvalue "/var/packages/${package}/INFO" startable)"
        skip2="$(/usr/syno/bin/synogetkeyvalue "/var/packages/${package}/INFO" ctl_stop)"
    elif [[ ${mode,,} == "restore" ]]; then
        skip1="$(/usr/syno/bin/synogetkeyvalue "${backuppath}/syno_app_mover/${package}/INFO" startable)"
        skip2="$(/usr/syno/bin/synogetkeyvalue "${backuppath}/syno_app_mover/${package}/INFO" ctl_stop)"
    fi
    if [[ $skip1 == "no" ]] || [[ $skip2 == "no" ]]; then
        return 0
    else
        return 1
    fi
}

check_pkg_size(){ 
    # $1 is package name
    # $2 is package source volume
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
    if [[ $pkg == "@database" ]]; then
        size=$(/usr/bin/du -s /var/services/pgsql/ | awk '{print $1}')
    else
        #size=$(/usr/bin/du -sL /var/packages/"$1"/target | awk '{print $1}')
        size=$(/usr/bin/du -s /var/packages/"$1"/target/ | awk '{print $1}')
        case "$1" in
            ActiveBackup)
                if [[ -d "/$sourcevol/@ActiveBackup" ]]; then
                    size2=$(/usr/bin/du -s /"$sourcevol"/@ActiveBackup | awk '{print $1}')
                    size=$((size +"$size2"))
                fi
                ;;
            ActiveBackup-GSuite)
                if [[ -d "/$sourcevol/@ActiveBackup-GSuite" ]]; then
                    size2=$(/usr/bin/du -s /"$sourcevol"/@ActiveBackup-GSuite | awk '{print $1}')
                    size=$((size +"$size2"))
                fi
                ;;
            ActiveBackup-Office365)
                if [[ -d "/$sourcevol/@ActiveBackup-Office365" ]]; then
                    size2=$(/usr/bin/du -s /"$sourcevol"/@ActiveBackup-Office365 | awk '{print $1}')
                    size=$((size +"$size2"))
                fi
                ;;
            Calendar)
                if [[ -d "/$sourcevol/@calendar" ]]; then
                    size2=$(/usr/bin/du -s /"$sourcevol"/@calendar | awk '{print $1}')
                    size=$((size +"$size2"))
                fi
                ;;
            ContainerManager|Docker)
                if [[ -d "/$sourcevol/@docker" ]]; then
                    size2=$(/usr/bin/du -s /"$sourcevol"/@docker | awk '{print $1}')
                    size=$((size +"$size2"))
                fi
                ;;
            DownloadStation)
                if [[ -d "/$sourcevol/@download" ]]; then
                    size2=$(/usr/bin/du -s /"$sourcevol"/@download | awk '{print $1}')
                    size=$((size +"$size2"))
                fi
                ;;
            GlacierBackup)
                if [[ -d "/$sourcevol/@GlacierBackup" ]]; then
                    size2=$(/usr/bin/du -s /"$sourcevol"/@GlacierBackup | awk '{print $1}')
                    size=$((size +"$size2"))
                fi
                ;;
            HyperBackup)
                if [[ -d "/$sourcevol/@img_bkp_cache" ]]; then
                    size2=$(/usr/bin/du -s /"$sourcevol"/@img_bkp_cache | awk '{print $1}')
                    size=$((size +"$size2"))
                fi
                ;;
            MailPlus-Server)
                if [[ -d "/$sourcevol/@maillog" ]]; then
                    size2=$(/usr/bin/du -s /"$sourcevol"/@maillog | awk '{print $1}')
                    size=$((size +"$size2"))
                fi
                if [[ -d "/$sourcevol/@MailPlus-Server" ]]; then
                    size2=$(/usr/bin/du -s /"$sourcevol"/@MailPlus-Server | awk '{print $1}')
                    size=$((size +"$size2"))
                fi
                ;;
            MailServer)
                if [[ -d "/$sourcevol/@maillog" ]]; then
                    size2=$(/usr/bin/du -s /"$sourcevol"/@maillog | awk '{print $1}')
                    size=$((size +"$size2"))
                fi
                if [[ -d "/$sourcevol/@MailScanner" ]]; then
                    size2=$(/usr/bin/du -s /"$sourcevol"/@MailScanner | awk '{print $1}')
                    size=$((size +"$size2"))
                fi
                if [[ -d "/$sourcevol/@clamav" ]]; then
                    size2=$(/usr/bin/du -s /"$sourcevol"/@clamav | awk '{print $1}')
                    size=$((size +"$size2"))
                fi
                ;;
            PrestoServer)
                if [[ -d "/$sourcevol/@presto" ]]; then
                    size2=$(/usr/bin/du -s /"$sourcevol"/@presto | awk '{print $1}')
                    size=$((size +"$size2"))
                fi
                ;;
            SurveillanceStation)
                if [[ -d "/$sourcevol/@ssbackup" ]]; then
                    size2=$(/usr/bin/du -s /"$sourcevol"/@ssbackup | awk '{print $1}')
                    size=$((size +"$size2"))
                fi
                if [[ -d "/$sourcevol/@surveillance" ]]; then
                    size2=$(/usr/bin/du -s /"$sourcevol"/@surveillance | awk '{print $1}')
                    size=$((size +"$size2"))
                fi
                ;;
            SynologyApplicationService)
                if [[ -d "/$sourcevol/@SynologyApplicationService" ]]; then
                    size2=$(/usr/bin/du -s /"$sourcevol"/@SynologyApplicationService | awk '{print $1}')
                    size=$((size +"$size2"))
                fi
                ;;
            SynologyDrive)
                # Moving the database in Synology Drive Admin moves @synologydrive
                #if [[ -d "/$sourcevol/@synologydrive" ]]; then
                #    size2=$(/usr/bin/du -s /"$sourcevol"/@synologydrive | awk '{print $1}')
                #    size=$((size +"$size2"))
                #fi
                if [[ -d "/$sourcevol/@SynologyDriveShareSync" ]]; then
                    size2=$(/usr/bin/du -s /"$sourcevol"/@SynologyDriveShareSync | awk '{print $1}')
                    size=$((size +"$size2"))
                fi
                ;;
            WebDAVServer)
                if [[ -d "/$sourcevol/@webdav" ]]; then
                    size2=$(/usr/bin/du -s /"$sourcevol"/@webdav | awk '{print $1}')
                    size=$((size +"$size2"))
                fi
                ;;
            Virtualization)
                if [[ -d "/$sourcevol/@GuestImage" ]]; then
                    size2=$(/usr/bin/du -s /"$sourcevol"/@GuestImage | awk '{print $1}')
                    size=$((size +"$size2"))
                fi
                if [[ -d "/$sourcevol/@Repository" ]]; then
                    size2=$(/usr/bin/du -s /"$sourcevol"/@Repository | awk '{print $1}')
                    size=$((size +"$size2"))
                fi
                ;;
            *)
                total_size="$size"
                return
                ;;
        esac
    fi
    total_size="$size"
}

source_fs(){ 
    # $1 is $sourcevol
    sourcefs="$(df --print-type "/${1:?}" | tail -n +2 | awk '{print $2}')"
}

target_fs(){ 
    # $1 is $targetvol
    targetfs="$(df --print-type "/${1:?}" | tail -n +2 | awk '{print $2}')"
}


#------------------------------------------------------------------------------
# Select mode

echo "" |& tee -a "$logfile"
if [[ $auto == "yes" ]]; then
    echo -e "Using auto ${Cyan}${mode}${Off} mode\n"
    echo -e "Using auto $mode mode\n" >> tee -a "$logfile"
else
    modes=( "Move" "Backup" "Restore" )
    x="1"
    for m in "${modes[@]}"; do
        echo "$x) $m" >> "$logfile"
        x=$((x +1))
    done

    echo "Select the mode " >> "$logfile"
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
                echo "Invalid choice!" |& tee -a "$logfile"
                ;;
        esac
    done
    echo -e "You selected ${Cyan}${mode}${Off}\n"
    echo -e "You selected ${mode}\n" >> "$logfile"
fi


# Check backup path if mode is backup or restore
if [[ ${mode,,} != "move" ]]; then
    if [[ ! -f "$conffile" ]]; then
        ding
        echo -e "Line ${LINENO}: ${Error}ERROR${Off} $conffile not found!"
        echo -e "Line ${LINENO}: ERROR $conffile not found!" >> "$logfile"
        exit 1  # Conf file not found
    fi
    if [[ ! -r "$conffile" ]]; then
        ding
        echo -e "Line ${LINENO}: ${Error}ERROR${Off} $conffile not readable!"
        echo -e "Line ${LINENO}: ERROR $conffile not readable!" >> "$logfile"
        exit 1  # Conf file not readable
    fi

    # Get and validate backup path
    backuppath="$(/usr/syno/bin/synogetkeyvalue "$conffile" backuppath)"
    if [[ -z "$backuppath" ]]; then
        ding
        echo -e "Line ${LINENO}: ${Error}ERROR${Off} backuppath missing from ${conffile}!"
        echo -e "Line ${LINENO}: ERROR backuppath missing from ${conffile}!" >> "$logfile"
        exit 1  # Backup path missing in conf file
    elif [[ ! -d "$backuppath" ]]; then
        ding
        echo -e "Line ${LINENO}: ${Error}ERROR${Off} Backup folder ${Cyan}$backuppath${Off} not found!"
        echo -e "Line ${LINENO}: ERROR Backup folder $backuppath not found!" >> "$logfile"
        exit 1  # Backup folder not found
    fi

    # Get list of excluded packages
    exclude="$(/usr/syno/bin/synogetkeyvalue "$conffile" exclude)"
    if [[ $exclude ]]; then
        IFS=',' read -r -a excludes <<< "$exclude"; unset IFS
        # Trim leading and trailing spaces
        for i in "${excludes[@]}"; do
            excludelist+=($(echo -n "$i" | xargs))
        done
    fi

    # Get age of container settings exports to delete
    delete_older="$(/usr/syno/bin/synogetkeyvalue "$conffile" delete_older)"

    # Get list of ignored containers
    ignored_containers="$(/usr/syno/bin/synogetkeyvalue "$conffile" ignored_containers)"
    if [[ $ignored_containers ]]; then
        IFS=',' read -r -a ignoreds <<< "$ignored_containers"; unset IFS
        # Trim leading and trailing spaces
        for i in "${ignoreds[@]}"; do
            ignored_containers_list+=($(echo -n "$i" | xargs))
        done
    fi
fi
if [[ ${mode,,} == "backup" ]]; then
    echo -e "Backup path is: ${Cyan}${backuppath}${Off}\n"
    echo -e "Backup path is: ${backuppath}\n" >> "$logfile"
elif [[ ${mode,,} == "restore" ]]; then
    echo -e "Restore from path is: ${Cyan}${backuppath}${Off}\n"
    echo -e "Restore from path is: ${backuppath}\n" >> "$logfile"
fi

# Check USB backup path file system is ext3, ext4 or btrfs if mode is backup
backupvol="$(echo "$backuppath" | cut -d"/" -f2)"
if [[ $backupvol =~ volumeUSB[1-9] ]]; then
    filesys="$(mount | grep "/${backupvol:?}/usbshare " | awk '{print $5}')"
    if [[ ! $filesys =~ ^ext[3-4]$ ]] && [[ ! $filesys =~ ^btrfs$ ]]; then
        ding
        echo -e "${Yellow}WARNING${Off} Only backup to ext3, ext4 or btrfs USB partition!"
        echo -e "WARNING Only backup to ext3, ext4 or btrfs USB partition!" >> "$logfile"
        exit 1  # USB volume is not ext3, ext4 of btrfs
    fi
fi


#------------------------------------------------------------------------------
# Select package

declare -A package_names
declare -A package_names_rev
package_infos=( )
if [[ ${mode,,} != "restore" ]]; then

    if [[ $auto == "yes" ]]; then
        # Add auto packages to array
        for package in "${autolist[@]}"; do
            package_name="$(/usr/syno/bin/synogetkeyvalue "/var/packages/${package}/INFO" displayname)"
            if [[ -z "$package_name" ]]; then
                package_name="$(/usr/syno/bin/synogetkeyvalue "/var/packages/${package}/INFO" package)"
            fi

            # Skip packages that are dev tools with no data
            if ! skip_dev_tools "$package"; then
                #package_infos+=("${package_name}")
                package_names["${package_name}"]="${package}"
                package_names_rev["${package}"]="${package_name}"
            else
                echo -e "Skipping non-stoppable app: $package_name" |& tee -a "$logfile"
                skip_echo="yes"
            fi
        done

        # Show skipped system apps
        if [[ ${#skipped[*]} -gt "0" ]]; then
            echo -e "Skipping system app(s): ${skipped[*]}" |& tee -a "$logfile"
            skip_echo="yes"
        fi
        if [[ $skip_echo == "yes" ]]; then
            echo "" |& tee -a "$logfile"
        fi
    else
        # Add non-system packages to array
        cdir /var/packages || exit
        while IFS= read -r -d '' link && IFS= read -r -d '' target; do
            if [[ ${link##*/} == "target" ]] && echo "$target" | grep -q 'volume'; then
                # Check symlink target exists
                if [[ -a "/var/packages${link#.}" ]] ; then
                    package="$(printf %s "$link" | cut -d'/' -f2 )"
                    package_volume="$(printf %s "$target" | cut -d'/' -f1,2 )"
                    package_name="$(/usr/syno/bin/synogetkeyvalue "/var/packages/${package}/INFO" displayname)"
                    if [[ -z "$package_name" ]]; then
                        package_name="$(/usr/syno/bin/synogetkeyvalue "/var/packages/${package}/INFO" package)"
                    fi

                    # Skip packages that are dev tools with no data
                    if ! skip_dev_tools "$package"; then
                        package_infos+=("${package_volume}|${package_name}")
                        package_names["${package_name}"]="${package}"
                        package_names_rev["${package}"]="${package_name}"
                    fi
                fi
            fi
        done < <(find . -maxdepth 2 -type l -printf '%p\0%l\0')
    fi
elif [[ ${mode,,} == "restore" ]]; then

    # Add list of backed up packages to array
    cdir "${backuppath}/syno_app_mover" || exit
    for package in *; do
        if [[ -d "$package" ]] && [[ $package != "@eaDir" ]]; then
            if [[ ${package:0:1} != "-" ]]; then
                package_name="$(/usr/syno/bin/synogetkeyvalue "${backuppath}/syno_app_mover/${package}/INFO" displayname)"
                if [[ -z "$package_name" ]]; then
                    package_name="$(/usr/syno/bin/synogetkeyvalue "${backuppath}/syno_app_mover/${package}/INFO" package)"
                fi

                # Skip packages that are dev tools with no data
                if ! skip_dev_tools "$package"; then
                    package_infos+=("${package_name}")
                    package_names["${package_name}"]="${package}"
                    package_names_rev["${package}"]="${package_name}"
                fi
            fi
        fi
    done < <(find . -maxdepth 2 -type d)
fi

# Add USB Copy if installed (so we can show how to move USB Copy's database)
if [[ ${mode,,} == "move" ]]; then
    package_status USBCopy >/dev/null
    code="$?"
    if [[ $code -lt "2" ]]; then
        package_names["USB Copy"]="USBCopy"
        package_names_rev["USBCopy"]="USB Copy"

        file="/var/packages/USBCopy/etc/setting.conf"
        package_volume=$(synogetkeyvalue "$file" repo_vol_path)
        usbcopy_vol="$package_volume"

        if [[ ${mode,,} != "restore" ]]; then
            package_infos+=("${package_volume}|USB Copy")
        elif [[ ${mode,,} == "restore" ]]; then
            package_infos+=("USB Copy")
        fi
    fi
fi

# Add @database if Move selected
if [[ ${mode,,} == "move" ]]; then
    package_names["@database"]="@database"
    package_names_rev["@database"]="@database"

    package_volume="/$(readlink "/var/services/pgsql" | cut -d"/" -f2)"
    database_vol="$package_volume"

    if [[ ${mode,,} != "restore" ]]; then
        package_infos+=("${package_volume}|@database")
    elif [[ ${mode,,} == "restore" ]]; then
        package_infos+=("@database")
    fi
fi

# Sort array
IFS=$'\n' package_infos_sorted=($(sort <<<"${package_infos[*]}")); unset IFS

if [[ $auto != "yes" ]]; then
    # Offer to backup or restore all packages
    if [[ ${mode,,} == "backup" ]]; then
        echo -e "Do you want to backup ${Cyan}All${Off} packages? [y/n]"
        echo -e "Do you want to backup All packages? [y/n]" >> "$logfile"
        read -r answer
        echo "$answer" >> "$logfile"
        #echo "" |& tee -a "$logfile"
        if [[ ${answer,,} == "y" ]]; then
            all="yes"
            echo -e "You selected ${Cyan}All${Off}\n"
            echo -e "You selected All\n" >> "$logfile"
        fi
    elif [[ ${mode,,} == "restore" ]]; then
        echo -e "Do you want to restore ${Cyan}All${Off} backed up packages? [y/n]"
        echo -e "Do you want to restore All backed up packages? [y/n]" >> "$logfile"
        read -r answer
        #echo "" |& tee -a "$logfile"
        if [[ ${answer,,} == "y" ]]; then
            all="yes"
            echo -e "You selected ${Cyan}All${Off}\n"
            echo -e "You selected All\n" >> "$logfile"
        fi
    fi

    if [[ $all != "yes" ]]; then
        if [[ ${mode,,} != "restore" ]]; then
            # Select package to move or backup

            if [[ ${#package_infos_sorted[@]} -gt 0 ]]; then
                echo -e "[Installed package list]" |& tee -a "$logfile"
                for ((i=1; i<=${#package_infos_sorted[@]}; i++)); do
                    info="${package_infos_sorted[i-1]}"
                    before_pipe="${info%%|*}"
                    after_pipe="${info#*|}"
                    package_infos_show+=("$before_pipe  $after_pipe")
                done
            fi

            if [[ ${#package_infos_show[@]} -gt 0 ]]; then
                x="1"
                for m in "${package_infos_show[@]}"; do
                    echo "$x) $m" >> "$logfile"
                    x=$((x +1))
                done
                echo "Select the package to ${mode,,} " >> "$logfile"
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
                            echo "Invalid choice! $m" |& tee -a "$logfile"
                            ;;
                    esac
                done
            else
                echo "No movable packages found!" |& tee -a "$logfile"
                exit 1
            fi

            echo -e "You selected ${Cyan}${pkg_name}${Off} in ${Cyan}${package_volume}${Off}\n"
            echo -e "You selected ${pkg_name} in ${package_volume}\n" >> "$logfile"

            if [[ ${pkg_name} == "USB Copy" ]]; then
                linktargetvol="$usbcopy_vol"
            elif [[ ${pkg_name} == "@database" ]]; then
                linktargetvol="$database_vol"
            else
                target=$(readlink "/var/packages/${pkg}/target")
                linktargetvol="/$(printf %s "${target:?}" | cut -d'/' -f2 )"
            fi

        elif [[ ${mode,,} == "restore" ]]; then
            # Select package to backup

            # Select package to restore
            if [[ ${#package_infos_sorted[@]} -gt 0 ]]; then
                echo -e "[Restorable package list]" |& tee -a "$logfile"
                x="1"
                for p in "${package_infos_sorted[@]}"; do
                    echo "$x) $p" >> "$logfile"
                    x=$((x +1))
                done

                echo "Select the package to restore " >> "$logfile"
                PS3="Select the package to restore: "
                select pkg_name in "${package_infos_sorted[@]}"; do
                    if [[ $pkg_name ]]; then
                        pkg="${package_names[${pkg_name}]}"
                        if [[ -d $pkg ]]; then
                            echo -e "You selected ${Cyan}${pkg_name}${Off}\n"
                            echo -e "You selected ${pkg_name}\n" >> "$logfile"
                            break
                        else
                            ding
                            echo -e "Line ${LINENO}: ${Error}ERROR${Off} $pkg_name not found!"
                            echo -e "Line ${LINENO}: ERROR $pkg_name not found!" >> "$logfile"
                            exit 1  # Selected package not found
                        fi
                    else
                        echo "Invalid choice!" |& tee -a "$logfile"
                    fi
                done

                # Check if package is installed
                check_pkg_installed "$pkg" "$pkg_name"
            else
                ding
                echo -e "Line ${LINENO}: ${Error}ERROR${Off} No package backups found!"
                echo -e "Line ${LINENO}: ERROR No package backups found!" >> "$logfile"
                exit 1  # No package backups found
            fi
        fi
    fi
fi

# Assign just the selected package to array
if [[ $all != "yes" ]] && [[ $auto != "yes" ]]; then
    unset package_names
    declare -A package_names
    package_names["${pkg_name:?}"]="${pkg:?}"

    unset package_names_rev
    declare -A package_names_rev
    package_names_rev["${pkg:?}"]="${pkg_name:?}"
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
        x="1"
        for v in "${volumes[@]}"; do
            echo "$x) $v" >> "$logfile"
            x=$((x +1))
        done
        echo "Select the destination volume " >> "$logfile"
        PS3="Select the destination volume: "
        select targetvol in "${volumes[@]}"; do
            if [[ $targetvol ]]; then
                if [[ -d $targetvol ]]; then
                    echo -e "You selected ${Cyan}${targetvol}${Off}\n"
                    echo -e "You selected ${targetvol}\n" >> "$logfile"
                    break
                else
                    ding
                    echo -e "Line ${LINENO}: ${Error}ERROR${Off} $targetvol not found!"
                    echo -e "Line ${LINENO}: ERROR $targetvol not found!" >> "$logfile"
                    exit 1  # Target volume not found
                fi
            else
                echo "Invalid choice!" |& tee -a "$logfile"
            fi
        done
    elif [[ ${#volumes[@]} -eq 1 ]]; then
        targetvol="${volumes[0]}"
        echo -e "Destination volume is ${Cyan}${targetvol}${Off}\n"
        echo -e "Destination volume is ${targetvol}\n" >> "$logfile"
    else
        ding
        echo -e "Line ${LINENO}: ${Error}ERROR${Off} Only 1 volume found!"
        echo -e "Line ${LINENO}: ERROR Only 1 volume found!" >> "$logfile"
        exit 1  # Only 1 volume
    fi
elif [[ ${mode,,} == "backup" ]]; then
    targetvol="/$(echo "${backuppath:?}" | cut -d"/" -f2)"
    if [[ $all != "yes" ]]; then
        echo -e "Destination volume is ${Cyan}${targetvol}${Off}\n"
        echo -e "Destination volume is ${targetvol}\n" >> "$logfile"
    fi
elif [[ ${mode,,} == "restore" ]]; then
    if [[ $all != "yes" ]]; then
        targetvol="/$(readlink "/var/packages/${pkg:?}/target" | cut -d"/" -f2)"
        echo -e "Destination volume is ${Cyan}${targetvol}${Off}\n"
        echo -e "Destination volume is ${targetvol}\n" >> "$logfile"
    fi
fi

warn_docker(){ 
    ding
    echo -en "${Yellow}WARNING${Off} $action $pkg_name containers from "
    echo -e "${Cyan}$sourcefs${Off} volume to ${Cyan}$targetfs${Off} volume"
    echo -e "results in needing to migrate the containers. Some may fail to migrate.\n"

    echo -n "WARNING $action docker containers from " >> "$logfile"
    echo "$sourcefs volume to $targetfs volume" >> "$logfile"
    echo -e "results in needing to migrate the containers. Some may fail to migrate.\n" >> "$logfile"
    sleep 2
}

# Check source and target filesystem if Docker or Container Manager selected
if [[ ${package_names[*]} =~ "ContainerManager" ]] || [[ ${package_names[*]} =~ "Docker" ]]; then
    if [[ $mode == "restore" ]]; then
        sourcevol=$(echo "$bkpath" | cut -d "/" -f2)
    else
        if [[ ${package_names[*]} =~ "ContainerManager" ]]; then
            pkg="ContainerManager"
            pkg_name="Container Manager"
        elif [[ ${package_names[*]} =~ "Docker" ]]; then
            pkg="Docker"
            pkg_name="Docker"
        fi
        target=$(readlink "/var/packages/${pkg}/target")
        sourcevol="$(printf %s "${target:?}" | cut -d'/' -f2 )"
    fi
    source_fs "$sourcevol"
    target_fs "$targetvol"
    if [[ $targetfs != "$sourcefs" ]]; then
        # Warn about different filesystems
        warn_docker
        docker_migrate="yes"
    fi
fi

# Check selected pkgs will fit on target volume
if [[ "${#package_names[@]}" -gt "1" ]]; then
    echo -e "Checking size of selected apps" |& tee -a "$logfile"
else
    echo -e "Checking size of ${package_names_rev[*]}" |& tee -a "$logfile"
fi
for pkg in "${package_names[@]}"; do
    # Get volume package is installed on
    sourcevol="$(readlink "/var/packages/$pkg/target" | cut -d'/' -f2)"

    # Get pkg total size
    check_pkg_size "$pkg" "/$sourcevol"
    all_pkg_size=$((all_pkg_size +total_size))
done

# Abort if not enough space on target volume
if ! check_space "$pkg" "${targetvol:?}" "$all_pkg_size"; then
    ding
    exit 1  # Not enough space
fi

# Show size of selected packages
if [[ $all_pkg_size -gt "999999" ]]; then
    echo -e "Size of selected app(s) is $((all_pkg_size /1048576)) GB\n" |& tee -a "$logfile"
elif [[ $all_pkg_size -gt "999" ]]; then
    echo -e "Size of selected app(s) is $((all_pkg_size /1048)) MB\n" |& tee -a "$logfile"
else
    echo -e "Size of selected app(s) is $all_pkg_size KB\n" |& tee -a "$logfile"
fi

# Check user is ready
if [[ $auto != "yes" ]]; then
    if [[ $all == "yes" ]]; then
        if [[ ${mode,,} == "backup" ]]; then
            echo -e "Ready to ${Yellow}${mode}${Off} ${Cyan}All${Off} packages to ${Cyan}${backuppath}${Off}? [y/n]"
            echo -e "Ready to $mode All packages to ${backuppath}? [y/n]" >> "$logfile"
        else
            echo -e "Ready to ${Yellow}${mode}${Off} ${Cyan}All${Off} backed up packages? [y/n]"
            echo -e "Ready to $mode All backed up packages? [y/n]" >> "$logfile"
        fi
    elif [[ ${mode,,} == "backup" ]]; then
        echo -e "Ready to ${Yellow}${mode}${Off} ${Cyan}${pkg_name}${Off} to ${Cyan}${backuppath}${Off}? [y/n]"
        echo -e "Ready to $mode ${Cyan}${pkg_name} to ${backuppath}? [y/n]" >> "$logfile"
    else
        echo -e "Ready to ${Yellow}${mode}${Off} ${Cyan}${pkg_name}${Off} to ${Cyan}${targetvol}${Off}? [y/n]"
        echo -e "Ready to $mode ${pkg_name} to ${targetvol}? [y/n]" >> "$logfile"
    fi
    read -r answer
    echo "$answer" >> "$logfile"
    echo "" |& tee -a "$logfile"
    if [[ ${answer,,} != y ]]; then
        exit  # Answered no
    fi
fi

# Reset shell's SECONDS var to later show how long the script took
SECONDS=0


#------------------------------------------------------------------------------
# Get list of packages sorted by with dependents, with dependencies then others

# Loop through package_names associative array
for pkg_name in "${!package_names[@]}"; do
    pkg="${package_names["$pkg_name"]}"

    # Get list of packages with dependents
    has_dependtents=()
    has_dependtents+=($(/usr/syno/bin/synopkg list --name --depend-on "$pkg"))
    if [[ ${#has_dependtents[@]} -gt "0" ]]; then
        # Add to list of running packages with dependents
        pkgs_with_deps+=("$pkg")
    else

        # Get list of packages with dependencies
        has_deps=""
        info="/var/packages/${pkg}/INFO"
        has_deps=$(/usr/syno/bin/synogetkeyvalue "$info" install_dep_packages)
        if [[ -n "$has_deps" ]]; then
            # Add to list of packages with dependencies
            dep_pkgs+=("$pkg")
        else

            # Add to list of other packages
            pkgs_no_dep+=("$pkg")
        fi
    fi
done

# Sort array
IFS=$'\n' pkgs_with_deps_sorted=($(sort -u <<<"${pkgs_with_deps[*]}")); unset IFS

# Sort array
IFS=$'\n' dep_pkgs_sorted=($(sort -u <<<"${dep_pkgs[*]}")); unset IFS

# Sort array
IFS=$'\n' pkgs_no_dep_sorted=($(sort -u <<<"${pkgs_no_dep[*]}")); unset IFS


# Add packages with dependents to pkgs_sorted
for v in "${!pkgs_with_deps_sorted[@]}"; do
    pkgs_sorted+=("${pkgs_with_deps_sorted["$v"]}")
done

# Append packages with dependencies to pkgs_sorted
for v in "${!dep_pkgs_sorted[@]}"; do
    pkgs_sorted+=("${dep_pkgs_sorted["$v"]}")
done

# Append other packages to pkgs_sorted
for v in "${!pkgs_no_dep_sorted[@]}"; do
    pkgs_sorted+=("${pkgs_no_dep_sorted["$v"]}")
done

# Free some memory
unset pkgs_with_deps
unset dep_pkgs
unset pkgs_no_dep
unset pkgs_with_deps_sorted
unset dep_pkgs_sorted
unset pkgs_no_dep_sorted


# Get list of running packages from array sorted by
# with dependents, with dependencies then others
for pkg in "${pkgs_sorted[@]}"; do
    if [[ -f "/var/packages/${pkg}/enabled" ]]; then
        running_pkgs_sorted+=("$pkg")
    fi
done


# Get list of running packages dependent on pgsql service
if [[ ${pkgs_sorted[*]} =~ "@database" ]]; then
    # Add running packages that use pgsql that need starting to array
    if cd "/var/packages"; then
        for package in *; do
            if [[ -d "$package" ]]; then
                depservice="$(synogetkeyvalue "/var/packages/${package}/INFO" start_dep_services)"
                #long_name="$(synogetkeyvalue "/var/packages/${package}/INFO" displayname)"
                if echo "$depservice" | grep -q 'pgsql'; then
                    if package_is_running "$package"; then
                        running_pkgs_dep_pgsql+=("$package")
                    fi
                fi
            fi
        done < <(find . -maxdepth 2 -type d)
    fi
fi


#------------------------------------------------------------------------------
# Stop the package or packages

stop_packages(){ 
    # Check package is running
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
    if package_is_running "$pkg"; then

        # Stop package
        package_stop "$pkg" "$pkg_name"

        # Check package stopped
        if package_is_running "$pkg"; then
            stop_pkg_fail="yes"
            ding
            echo -e "Line ${LINENO}: ${Error}ERROR${Off} Failed to stop ${pkg_name}!" |& tee -a "$logfile"
#            echo "${pkg_name} status $code" |& tee -a "$logfile"
            process_error="yes"
            if [[ $all != "yes" ]] || [[ $fix != "yes" ]]; then
                exit 1  # Skip exit if mode != all and fix != yes
            fi
            return 1
        else
            stop_pkg_fail=""
        fi

        if [[ $pkg == "ContainerManager" ]] || [[ $pkg == "Docker" ]]; then
            # Stop containerd-shim
            killall containerd-shim >/dev/null 2>&1
        fi
#    else
#        skip_start="yes"
    fi
}


#------------------------------------------------------------------------------
# Backup extra @folders

backup_extras(){ 
    # $1 is @folder (@docker or @downloads etc)
    local extrabakvol
    local answer
    # Skip if source volume is read only
    if [[ -w "/$sourcevol" ]]; then
        if [[ ${mode,,} != "backup" ]]; then
            if [[ ${mode,,} == "move" ]]; then
                extrabakvol="/$sourcevol"
            elif [[ ${mode,,} == "restore" ]]; then
                extrabakvol="$targetvol"
            fi
            echo -e "NOTE: A backup of ${Cyan}$1${Off} is required"\
                "for recovery if the move fails."
            echo -e "NOTE: A backup of $1 is required"\
                "for recovery if the move fails." >> "$logfile"
            echo -e "Do you want to ${Yellow}backup${Off} the"\
                "${Cyan}$1${Off} folder on $extrabakvol? [y/n]"
            echo -e "Do you want to backup the"\
                "$1 folder on $extrabakvol? [y/n]" >> "$logfile"
            read -r answer
            echo "$answer" >> "$logfile"
            if [[ ${answer,,} == "y" ]]; then
                # Check we have enough space
                if ! check_space "/${sourcevol}/$1" "/${sourcevol}" extra; then
                    ding
                    echo -e "${Error}ERROR${Off} Not enough space on $extrabakvol to backup ${Cyan}$1${Off}!"
                    echo -e "ERROR Not enough space on $extrabakvol to backup $1!" >> "$logfile"
                    echo "Do you want to continue ${action,,} ${1}? [y/n]" |& tee -a "$logfile"
                    read -r answer
                    echo "$answer" >> "$logfile"
                    if [[ ${answer,,} != "y" ]]; then
                        exit  # Answered no
                    fi
                else
                    echo -e "${Red}WARNING Backing up $1 could take a long time${Off}"
                    echo -e "WARNING Backing up $1 could take a long time" >> "$logfile"
                    backup_dir "$1" "$extrabakvol"
                fi
            fi
        fi
    fi
}


#------------------------------------------------------------------------------
# Move the package or packages

prepare_backup_restore(){ 
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"

    # Set bkpath variable
    if [[ ${mode,,} != "move" ]]; then
        bkpath="${backuppath}/syno_app_mover/$pkg"
    fi

    # Set targetvol variable
    if [[ ${mode,,} == "restore" ]] && [[ $all == "yes" ]]; then
        targetvol="/$(readlink "/var/packages/${pkg:?}/target" | cut -d"/" -f2)"
    fi

    # Check installed package version and backup version
    # Get package version
    if [[ ${mode,,} != "move" ]]; then
        pkgversion=$(/usr/syno/bin/synogetkeyvalue "/var/packages/$pkg/INFO" version)
    fi

    # Get backup package version
    if [[ ${mode,,} == "restore" ]]; then
        pkgbackupversion=$(/usr/syno/bin/synogetkeyvalue "$bkpath/INFO" version)
        if [[ $pkgversion ]] && [[ $pkgbackupversion ]]; then
            check_pkg_versions_match "$pkgversion" "$pkgbackupversion"
        fi
    fi

    # Create package folder if mode is backup
    if [[ ${mode,,} == "backup" ]]; then
        if [[ ! -d "$bkpath" ]]; then
            if ! mkdir -p "${bkpath:?}"; then
                ding
                echo -e "Line ${LINENO}: ${Error}ERROR${Off} Failed to create directory!"
                echo -e "Line ${LINENO}: ERROR Failed to create directory!" >> "$logfile"
                process_error="yes"
                if [[ $all != "yes" ]]; then
                    exit 1  # Skip exit if mode is All
                fi
                return 1
            fi
        fi

        # Backup package's INFO file
        cp -p "/var/packages/$pkg/INFO" "$bkpath/INFO" |& tee -a "$logfile"
    fi
}

process_packages(){
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
    target=$(readlink "/var/packages/${pkg}/target")
    #sourcevol="/$(printf %s "${target:?}" | cut -d'/' -f2 )"
    sourcevol="$(printf %s "${target:?}" | cut -d'/' -f2 )"

    # Move package
    if [[ $pkg == "ContainerManager" ]] || [[ $pkg == "Docker" ]]; then
        # Move @docker if package is ContainerManager or Docker

        # Check if @docker is on same volume as Docker package
        if [[ -d "/${sourcevol}/@docker" ]]; then
            # Check we have enough space
            if ! check_space "/${sourcevol}/@docker" "${targetvol}" extra; then
                ding
                echo -e "${Error}ERROR${Off} Not enough space on $targetvol to ${mode,,} ${Cyan}@docker${Off}!"
                echo -e "ERROR Not enough space on $targetvol to ${mode,,} @docker!" >> "$logfile"
                process_error="yes"
                if [[ $all != "yes" ]]; then
                    exit 1  # Skip exit if mode is All
                fi
                return 1
            fi
        fi

        # Backup @docker
        backup_extras "@docker"

        # Move package and edit symlinks
        move_pkg "$pkg" "$targetvol"

    elif [[ $pkg == "DownloadStation" ]]; then
        # Move @download if package is DownloadStation

        # Check if @download is on same volume as DownloadStation package
        if [[ -d "/${sourcevol}/@download" ]]; then
            # Check we have enough space
            if ! check_space "/${sourcevol}/@download" "${targetvol}" extra; then
                ding
                echo -e "${Error}ERROR${Off} Not enough space on $targetvol to ${mode,,} ${Cyan}@download${Off}!"
                echo -e "ERROR Not enough space on $targetvol to ${mode,,} @download!" >> "$logfile"
                process_error="yes"
                if [[ $all != "yes" ]]; then
                    exit 1  # Skip exit if mode is All
                fi
                return 1
            fi
        fi

        # Backup @download
        backup_extras "@download"

        # Move package and edit symlinks
        move_pkg "$pkg" "$targetvol"
    else
        # Move package and edit symlinks
        move_pkg "$pkg" "$targetvol"
    fi

    # Move package's other folders
    move_extras "$pkg" "$targetvol"

    # Backup or restore package's web_packages folder
    if [[ ${mode,,} != "move" ]]; then
        web_packages "${pkg,,}"
    fi
}

start_packages(){ 
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}" |& tee -a "$logfile"
#    if [[ $skip_start != "yes" ]]; then
        if [[ $pkg != "@database" ]]; then
            # Only start package if not already running
            if ! package_is_running "$pkg"; then

                if [[ ${mode,,} == "backup" ]]; then
                    answer="y"
                elif [[ $all == "yes" ]]; then
                    answer="y"
                else
                    echo -e "\nDo you want to start ${Cyan}$pkg_name${Off} now? [y/n]"
                    echo -e "\nDo you want to start $pkg_name now? [y/n]" >> "$logfile"
                    read -r answer
                    echo "$answer" >> "$logfile"
                fi

                if [[ ${answer,,} == "y" ]]; then
                    # Start package
                    package_start "$pkg" "$pkg_name"

                    # Check package started
                    if ! package_is_running "$pkg"; then
                        ding
                        echo -e "Line ${LINENO}: ${Error}ERROR${Off} Failed to start ${pkg_name}!"
                        echo -e "Line ${LINENO}: ERROR Failed to start ${pkg_name}!" >> "$logfile"
    #                    echo "${pkg_name} status $code" |& tee -a "$logfile"
                        process_error="yes"
                        if [[ $all != "yes" ]]; then
                            exit 1  # Skip exit if mode is All
                        fi
                    else
                        did_start_pkg="yes"
                    fi
                else
                    no_start_pkg="yes"
                fi
            fi
        fi
#    fi
}

check_last_process_time(){ 
    # $1 is pkg
    if [[ ${mode,,} != "move" ]]; then
        #now=$(date +%s)
        if [[ -f "${backuppath}/syno_app_mover/$1/last${mode,,}" ]]; then
            last_process_time=$(cat "${backuppath}/syno_app_mover/$1/last${mode,,}")
            skip_minutes=$(/usr/syno/bin/synogetkeyvalue "$conffile" skip_minutes)
            if [[ $skip_minutes -gt "0" ]]; then
                skip_secs=$((skip_minutes *60))
                #if $(($(date +%s) +skip_secs)) -gt 
                if [[ $((last_process_time +skip_secs)) -gt $(date +%s) ]]; then
                    return 1
                fi
            fi
        fi
    fi
}

docker_export(){ 
    local docker_share
    local export_dir
    local container
    local export_file
    export_date="$(date +%Y%m%d_%H%M)"

    # Get docker share location
    if [[ $buildnumber -gt "64570" ]]; then
        # DSM 7.2.1 and later
        # synoshare --get-real-path is case insensitive (docker or Docker both work)
        docker_share=$(/usr/syno/sbin/synoshare --get-real-path docker)
    else
        # DSM 7.2 and earlier
        # synoshare --getmap is case insensitive (docker or Docker both work)
        docker_share=$(/usr/syno/sbin/synoshare --getmap docker | grep volume | cut -d"[" -f2 | cut -d"]" -f1)
    fi

    if [[ ! -d "$docker_share" ]]; then
        echo "${Error}WARNING${Off} docker shared folder not found!"
        echo "WARNING docker shared folder not found!" >> "$logfile"
        return
    else
        export_dir="${docker_share}/app_mover_exports"
    fi

    if [[ ! -d "$export_dir" ]]; then
        if ! mkdir "$export_dir"; then
            echo "${Error}WARNING${Off} Failed to create docker export folder!"
            echo "WARNING Failed to create docker export folder!" >> "$logfile"
            return
        else
            chmod 755 "$export_dir" |& tee -a "$logfile"
        fi
    fi

    echo "Exporting container settings to ${export_dir}" |& tee -a "$logfile"
    # Get list of all containers (running and stopped)
    for container in $(docker ps --all --format "{{ .Names }}"); do
        if grep -q "$container" <<< "${ignored_containers_list[@]}" ; then
            echo "Skipping ${container} on ignore list." |& tee -a "$logfile"
            continue
        else
            export_file="${export_dir:?}/${container}_${export_date}.json"
            echo "Exporting $container json" |& tee -a "$logfile"
            # synowebapi -s or --silent does not work
            /usr/syno/bin/synowebapi --exec api=SYNO.Docker.Container.Profile method=export version=1 outfile="$export_file" name="$container" &>/dev/null

            # Check export was successful
            if [[ ! -f "$export_file" ]] || [[ $(stat -c %s "$export_file") -eq "0" ]]; then
                # No file or 0 bytes
                echo "${Error}WARNING${Off} Failed to export $container settings!"
                echo "WARNING Failed to export $container settings!" >> "$logfile"
                return
            else
                chmod 660 "${export_dir:?}/${container}_${export_date}.json" |& tee -a "$logfile"
            fi

            # Delete settings exports older than $delete_older days
            if [[ $delete_older =~ ^[2-9][0-9]?$ ]]; then
                find "$export_dir" -name "${container,,}_*.json" -mtime +"$delete_older" -exec rm {} \;
            fi
        fi
    done
}

move_database(){ 
    # Get volume where @database currently is
    target=$(readlink "/var/services/pgsql")
    #sourcevol="/$(printf %s "${target:?}" | cut -d'/' -f2 )"
    sourcevol="$(printf %s "${target:?}" | cut -d'/' -f2 )"

    # Stop the pgsql service - Also stops dependant apps
    systemctl stop pgsql-adapter.service &
    pid=$!
    string="Stopping pgsql service and dependent apps"
    echo "Stopping pgsql service and dependent apps" >> "$logfile"
    progbar "$pid" "$string"
    wait "$pid"
    progstatus "$?" "$string" "line ${LINENO}"

    # Check pgsql service has stopped
    # running = 0  stopped = 3
    if systemctl status pgsql-adapter.service >/dev/null; then
        ding
        echo "ERROR Failed to stop pgsql service!" |& tee -a "$logfile"
        return 1
    #else
    #    echo "Stopped pgsql service" |& tee -a "$logfile"
    fi

    # Create @database folder if needed
    if [[ ! -d "${targetvol:?}/@database" ]]; then
        mkdir -m755 "${targetvol:?}/@database"
    fi

    # Copy pgsql folder
    cp -pr "/${sourcevol:?}/@database/pgsql" "${targetvol:?}/@database/pgsql" &
    pid=$!
    string="Copying pgsql database to $targetvol/@database"
    echo "Copying pgsql database to $targetvol/@database" >> "$logfile"
    progbar "$pid" "$string"
    wait "$pid"
    progstatus "$?" "$string" "line ${LINENO}"

    # Copy other folders
    if [[ -d "/${sourcevol:?}/@database/autoupdate" ]]; then
        cp -pr "/${sourcevol:?}/@database/autoupdate" "${targetvol:?}/@database/autoupdate"
    fi
    if [[ -d "/${sourcevol:?}/@database/synolog" ]]; then
        cp -pr "/${sourcevol:?}/@database/synolog" "${targetvol:?}/@database/synolog"
    fi
    if [[ -d "/${sourcevol:?}/@database/synologan" ]]; then
        cp -pr "/${sourcevol:?}/@database/synologan" "${targetvol:?}/@database/synologan"
    fi

    # Edit pgsql symlink
    rm /var/services/pgsql
    ln -s "${targetvol:?}/@database/pgsql" /var/services/pgsql

    # Start the pgsql service
    echo "Starting pgsql service" |& tee -a "$logfile"
    systemctl start pgsql-adapter.service

    # Check pgsql service is ok
    # okay = 0  stopped = 3
    if ! systemctl status pgsql-adapter.service >/dev/null; then
        ding
        echo "ERROR Failed to start pgsql service!" |& tee -a "$logfile"
        return 1
    #else
    #    echo "Started pgsql service" |& tee -a "$logfile"
    fi
    return 0
}


# Loop through pkgs_sorted array and process package
for pkg in "${pkgs_sorted[@]}"; do
    pkg_name="${package_names_rev["$pkg"]}"
    process_error=""

    # Skip backup or restore for excluded apps
    if [[ $all == "yes" ]] && [[ "${excludelist[*]}" =~ $pkg ]] &&\
        [[ $mode != "move" ]]; then
        echo -e "Excluding $pkg\n" |& tee -a "$logfile"
        continue
    fi

    #if [[ $pkg == USBCopy ]] && [[ ${mode,,} == "move" ]]; then
    if [[ $pkg == USBCopy ]]; then
        # USBCopy only needs database location changed in USB Copy ui
        continue
    fi

    #if [[ $pkg == "@database" ]] && [[ ${mode,,} == "move" ]]; then
    if [[ $pkg == "@database" ]]; then
        move_database
        continue
    fi

    if [[ $pkg == "ContainerManager" ]] || [[ $pkg == "Docker" ]]; then
        if [[ -w "/$sourcevol" ]]; then
            # Start package if needed so we can prune images
            # and export container configurations
            if ! package_is_running "$pkg"; then
                package_start "$pkg" "$pkg_name"
            fi

            if [[ ${mode,,} != "restore" ]]; then
                # Export container settings to json files
                docker_export
            fi

            if [[ ${mode,,} == "restore" ]]; then
                # Remove dangling and unused images
                echo "Removing dangling and unused docker images" |& tee -a "$logfile"
                docker image prune --all --force >/dev/null
            else
                # Remove dangling images
                echo "Removing dangling docker images" |& tee -a "$logfile"
                docker image prune --force >/dev/null
            fi
        else
            # Skip read only source volume
            echo "/$sourcevol is read only. Skipping:" |& tee -a "$logfile"
            echo "  - Exporting container settings" |& tee -a "$logfile"
            echo "  - Removing dangling and unused docker images" |& tee -a "$logfile"
        fi
    fi


    if check_last_process_time "$pkg"; then
        if [[ ${mode,,} != "move" ]]; then
            prepare_backup_restore
        fi
        stop_packages

        if [[ ${1,,} == "--test" ]] || [[ ${1,,} == "test" ]]; then
            echo "process_packages"
        else
            if [[ $stop_pkg_fail != "yes" ]]; then
                process_packages
                if [[ ${mode,,} != "move" ]] && [[ $process_error != "yes" ]]; then
                    # Save last backup time
                    echo -n "$(date +%s)" > "${backuppath}/syno_app_mover/$pkg/last${mode,,}"
                    chmod 755 "${backuppath}/syno_app_mover/$pkg/last${mode,,}" |& tee -a "$logfile"
                fi
            fi
        fi

        # shellcheck disable=SC2143  # Use grep -q
        if [[ $(echo "${running_pkgs_sorted[@]}" | grep -w "$pkg") ]]; then
            start_packages
        fi
    else
        echo "Skipping $pkg_name as it was backed up less than $skip_minutes minutes ago" |& tee -a "$logfile"
    fi
    echo "" |& tee -a "$logfile"
done


#------------------------------------------------------------------------------
# Show how to move related shared folder(s)

docker_volume_edit(){ 
    # Remind user to edit container's volume setting
    echo "If you moved shared folders that your $pkg_name containers use" |& tee -a "$logfile"
    echo "as volumes you will need to edit your docker compose or .env files," |& tee -a "$logfile"
    echo -e "or the container's settings, to point to the changed volume number.\n" |& tee -a "$logfile"
}

suggest_move_share(){ 
    # show_move_share <package-name> <share-name>
    if [[ ${mode,,} == "move" ]]; then
        case "$pkg" in
            ActiveBackup)
                show_move_share "Active Backup for Business" ActiveBackupforBusiness stopped
                ;;
            AudioStation)
                share_link=$(readlink /var/packages/AudioStation/shares/music)
                if [[ $share_link == "/${sourcevol}/music" ]]; then
                    show_move_share "Audio Station" music stopped more
                fi
                ;;
            Chat)
                show_move_share "Chat Server" chat stopped
                ;;
            CloudSync)
                show_move_share "Cloud Sync" CloudSync stopped
                ;;
            ContainerManager)
                show_move_share "Container Manager" docker stopped
                docker_volume_edit
                ;;
            Docker)
                show_move_share "Docker" docker stopped
                docker_volume_edit
                ;;
            MailPlus-Server)
                show_move_share "MailPlus Server" MailPlus running
                ;;
            MinimServer)
                show_move_share "Minim Server" MinimServer stopped
                ;;
            Plex*Media*Server)
                if [[ $majorversion -gt "6" ]]; then
                    show_move_share "Plex Media Server" PlexMediaServer stopped
                else
                    show_move_share "Plex Media Server" Plex stopped
                fi
                ;;
            SurveillanceStation)
                show_move_share "Surveillance Station" surveillance stopped
                ;;
            SynologyPhotos)
                share_link=$(readlink /var/services/photo)
                if [[ -d "$share_link" ]]; then
                    if [[ $share_link == "/${sourcevol}/photo" ]]; then
                        show_move_share "Synology Photos" photo stopped
                    fi
                fi
                ;;
            VideoStation)
                share_link=$(readlink /var/packages/VideoStation/shares/video)
                if [[ $share_link == "/${sourcevol}/video" ]]; then
                    show_move_share "Video Station" video stopped more
                fi
                ;;
            *)  
                ;;
        esac
    fi
}

if [[ ${mode,,} == "move" ]]; then
    if [[ $all == "yes" ]]; then
        # Loop through pkgs_sorted array and process package
        for pkg in "${pkgs_sorted[@]}"; do
            pkg_name="${package_names_rev["$pkg"]}"
            suggest_move_share
        done
    else
        suggest_move_share
    fi
fi


#------------------------------------------------------------------------------
# Start package and dependent packages that aren't running

# Loop through running_pkgs_sorted array
if [[ $no_start_pkg != "yes" ]]; then
    did_start_pkg=""
    for pkg in "${running_pkgs_sorted[@]}"; do
        pkg_name="${package_names_rev["$pkg"]}"
        start_packages
    done
    if [[ $did_start_pkg == "yes" ]]; then
        echo "" |& tee -a "$logfile"
    fi
fi

# Start pqsql dependent pkgs that were running but aren't now
# Loop through running_pkgs_dep_pgsql array
if [[ $no_start_pkg != "yes" ]]; then
    did_start_pkg=""
    for pgsql_pkg in "${running_pkgs_dep_pgsql[@]}"; do
        if ! package_is_running "$pgsql_pkg"; then
            pgsql_pkg_name="$(synogetkeyvalue "/var/packages/${pgsql_pkg}/INFO" displayname)"
            package_start "$pgsql_pkg" "$pgsql_pkg_name"
        fi
    done
    if [[ $did_start_pkg == "yes" ]]; then
        echo "" |& tee -a "$logfile"
    fi
fi

if [[ $all == "yes" ]]; then
    echo -e "Finished ${action,,} all packages\n" |& tee -a "$logfile"
elif [[ $auto == "yes" ]]; then
    echo -e "Finished ${action,,} ${pkgs_sorted[*]}\n" |& tee -a "$logfile"
else
    echo -e "Finished ${action,,} $pkg_name\n" |& tee -a "$logfile"
fi

# Show how long the script took
end="$SECONDS"
if [[ $end -ge 3600 ]]; then
    printf 'Duration: %dh %dm\n\n' $((end/3600)) $((end%3600/60)) |& tee -a "$logfile"
elif [[ $end -ge 60 ]]; then
    echo -e "Duration: $((end/60))m $((end%60))s\n" |& tee -a "$logfile"
else
    echo -e "Duration: ${end} seconds\n" |& tee -a "$logfile"
fi


#------------------------------------------------------------------------------
# Show how to export and import package's database if dependent on MariaDB10

# Loop through package_names associative array
for pkg_name in "${!package_names[@]}"; do
    pkg="${package_names[$pkg_name]}"
    if [[ ${mode,,} != "move" ]]; then
        info="/var/packages/${pkg}/INFO"
        if /usr/syno/bin/synogetkeyvalue "$info" install_dep_packages | grep 'MariaDB' >/dev/null
        then
           mariadb_list+=("${pkg_name}")
           mariadb_show="yes"
        fi
    fi
done 

if [[ $mariadb_show == "yes" ]]; then
    if [[ ${mode,,} == "backup" ]]; then
        # Show how to export package's database
        echo -e "If you want to ${Yellow}backup${Off} the database of"\
            "${Cyan}${mariadb_list[*]}${Off} do the following:"
        echo -e "If you want to backup the database of"\
            "${mariadb_list[*]} do the following:" >> "$logfile"
        echo "  If you don't have phpMyAdmin installed:" |& tee -a "$logfile"
        echo "    1. Install phpMyAdmin." |& tee -a "$logfile"
        echo "    2. Open phpMyAdmin" |& tee -a "$logfile"
        echo "    3. Log in with user root and your MariaDB password." |& tee -a "$logfile"
        echo "  Once you are logged in to phpMyAdmin:" |& tee -a "$logfile"
        echo "    1. Click on the package name on the left." |& tee -a "$logfile"
        echo "    2. Click on the Export tab at the top." |& tee -a "$logfile"
        echo "    3. Click on the Export button." |& tee -a "$logfile"
        echo -e "    4. Save the export to a safe location.\n" |& tee -a "$logfile"
    elif [[ ${mode,,} == "restore" ]]; then
        # Show how to import package's exported database
        echo -e "If you want to ${Yellow}restore${Off} the database of"\
            "${Cyan}${mariadb_list[*]}${Off} do the following:"
        echo -e "If you want to restore the database of"\
            "${mariadb_list[*]} do the following:"    >> "$logfile"
        echo "  If you don't have phpMyAdmin installed:" |& tee -a "$logfile"
        echo "    1. Install phpMyAdmin." |& tee -a "$logfile"
        echo "    2. Open phpMyAdmin" |& tee -a "$logfile"
        echo "    3. Log in with user root and your MariaDB password." |& tee -a "$logfile"
        echo "  Once you are logged in to phpMyAdmin:" |& tee -a "$logfile"
        echo "    1. Click on the package name on the left." |& tee -a "$logfile"
        echo "    2. Click on the Import tab at the top." |& tee -a "$logfile"
        echo "    3. Click on the 'Choose file' button." |& tee -a "$logfile"
        echo -e "    4. Browse to your exported .sql file and import it.\n" |& tee -a "$logfile"
    fi
fi


#------------------------------------------------------------------------------
# Show how to migrate docker containers if different file system

if [[ $docker_migrate == "yes" ]]; then
    echo -e "You will need to migrate your containers" |& tee -a "$logfile"
    echo "  1. Open Container Manager." |& tee -a "$logfile"
    echo "  2. Click the Manage link." |& tee -a "$logfile"
    echo "  3. Select the container you want to migrate." |& tee -a "$logfile"
    echo "  4. Click Migrate." |& tee -a "$logfile"
    echo -e "  5. Click Continue.\n" |& tee -a "$logfile"
fi


#------------------------------------------------------------------------------
# Suggest change location of shared folder(s) if package moved

suggest_change_location(){ 
    # Suggest moving CloudSync database if package is CloudSync
    if [[ $pkg == CloudSync ]]; then
        # Show how to move CloudSync database
        echo -e "If you want to move the CloudSync database to $targetvol" |& tee -a "$logfile"
        echo "  1. Open Cloud Sync." |& tee -a "$logfile"
        echo "  2. Click Settings." |& tee -a "$logfile"
        echo "  3. Change 'Database Location Settings' to $targetvol" |& tee -a "$logfile"
        echo -e "  4. Click Save.\n" |& tee -a "$logfile"
    fi

    # Suggest moving @download if package is DownloadStation
    if [[ $pkg == DownloadStation ]]; then
        # Show how to move DownloadStation database and temp files
        #file="/var/packages/DownloadStation/etc/db-path.conf"
        #value="$(/usr/syno/bin/synogetkeyvalue "$file" db-vol)"
        #if [[ $value != "$targetvol" ]]; then
            echo -e "If you want to move the DownloadStation database & temp files to $targetvol" |& tee -a "$logfile"
            echo "  1. Open Download Station." |& tee -a "$logfile"
            echo "  2. Click Settings." |& tee -a "$logfile"
            echo "  3. Click General." |& tee -a "$logfile"
            echo "  4. Change 'Temporary location' to $targetvol" |& tee -a "$logfile"
            echo -e "  5. Click OK.\n" |& tee -a "$logfile"
        #fi
    fi

    # Suggest moving Note Station database if package is NoteStation
    if [[ $pkg == NoteStation ]]; then
        # Show how to move Note Station database
        echo -e "If you want to move the Note Station database to $targetvol" |& tee -a "$logfile"
        echo "  1. Open Note Station." |& tee -a "$logfile"
        echo "  2. Click Settings." |& tee -a "$logfile"
        echo "  3. Click Administration." |& tee -a "$logfile"
        echo "  4. Change Volume to $targetvol" |& tee -a "$logfile"
        echo -e "  5. Click OK.\n" |& tee -a "$logfile"
    fi

    # Suggest moving Synology Drive database if package is SynologyDrive
    if [[ $pkg == SynologyDrive ]]; then
        # Show how to move Drive database
        file="/var/packages/SynologyDrive/etc/db-path.conf"
        value="$(/usr/syno/bin/synogetkeyvalue "$file" db-vol)"
        if [[ $value != "$targetvol" ]]; then
            echo -e "If you want to move the Synology Drive database to $targetvol" |& tee -a "$logfile"
            echo "  1. Open Synology Drive Admin Console." |& tee -a "$logfile"
            echo "  2. Click Settings." |& tee -a "$logfile"
            echo "  3. Change Location to $targetvol" |& tee -a "$logfile"
            echo -e "  4. Click Apply.\n" |& tee -a "$logfile"
        fi
    fi

    # Suggest moving database if package is USBCopy
    if [[ $pkg == USBCopy ]]; then
        # Show how to move USB Copy database
        echo -e "To move the USB Copy database to $targetvol"
        echo "  1. Open 'USB Copy'."
        echo "  2. Click the gear icon to open settings."
        echo "  3. Change Database location to $targetvol"
        echo -e "  4. Click OK.\n"
    fi

    # Suggest moving VMs if package is Virtualization
    if [[ $pkg == Virtualization ]]; then
        # Show how to move VMs
        echo -e "If you want to move your VMs to $targetvol\n" |& tee -a "$logfile"
        echo "1. Add $targetvol as Storage in Virtual Machine Manager" |& tee -a "$logfile"
        echo "  1. Open Virtual Machine Manager." |& tee -a "$logfile"
        echo "  2. Click Storage and Click Add." |& tee -a "$logfile"
        echo "  3. Complete the steps to add $targetvol" |& tee -a "$logfile"
        echo -e "\n2. Move the VM to $targetvol" |& tee -a "$logfile"
        echo "  1. Click on Virtual Machine." |& tee -a "$logfile"
        echo "  2. Click on the VM to move." |& tee -a "$logfile"
        echo "  3. Shut Down the VM." |& tee -a "$logfile"
        echo "  4. Click Action then click Migrate." |& tee -a "$logfile"
        echo "  5. Make sure Change Storage is selected." |& tee -a "$logfile"
        echo "  6. Click Next." |& tee -a "$logfile"
        echo -e "  7. Complete the steps to migrate the VM.\n" |& tee -a "$logfile"
    fi
}

if [[ ${mode,,} == "move" ]]; then
    if [[ $all == "yes" ]]; then
        # Loop through pkgs_sorted array and process package
        for pkg in "${pkgs_sorted[@]}"; do
            pkg_name="${package_names_rev["$pkg"]}"
            suggest_change_location
        done
    else
        suggest_change_location
    fi
fi

exit

