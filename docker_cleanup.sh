#!/bin/bash

# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    echo -e "ERROR This script must be run as sudo or root!"
    exit 1
fi

# Check script is running on a Synology NAS
if ! /usr/bin/uname -a | grep -i synology >/dev/null; then
    echo "This script is NOT running on a Synology NAS!"
    echo "Copy the script to a folder on the Synology and run it from there."
    exit 1
fi

# Check Container Manager is running
if ! /usr/syno/bin/synopkg status ContainerManager >/dev/null; then
    echo -e "ERROR Container Manager is not running!"
    exit 1
fi


# Get volume @docker is on
source=$(readlink /var/packages/ContainerManager/var/docker)
volume=$(echo "$source" | cut -d"/" -f2)

#volume="volume2"  # debug


# Get list of @docker/btrfs/subvolumes
echo "@docker/btrfs/subvolumes list:"  # debug    
for subvol in /"$volume"/@docker/btrfs/subvolumes/*; do    
    echo "$subvol"  # debug
    allsubvolumes+=("$subvol")
done


#echo ${allsubvolumes[*]}  # debug
#echo -e "\n"  # debug


# Get list of current @docker/btrfs/subvolumes
echo -e "\nbtrfs subvolume list:"  # debug    
readarray -t temp < <(btrfs subvolume list -p /"$volume"/@docker/btrfs/subvolumes)
for v in "${temp[@]}"; do
    #echo "1 $v"  # debug
    sub=$(echo "$v" | grep '@docker/btrfs/subvolumes' | awk '{print $NF}')

    if [[ $sub =~ ^@docker/btrfs/subvolumes/* ]]; then
        echo "/$volume/$sub"  # debug
        currentsubvolumes+=("/$volume/$sub")
    fi
done


# Create list of orphan subvolumes
echo -e "\nOrphan subvolume list:"  # debug    
for v in "${allsubvolumes[@]}"; do
    if [[ ! "${currentsubvolumes[*]}" =~ "$v" ]]; then
        echo "$v"  # debug
        orphansubvolumes+=("/$volume/$v")
    fi
done
