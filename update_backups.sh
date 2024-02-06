#!/usr/bin/env bash
# Update existing backups to be compatible with v3.0.16
# i.e. Copy package's INFO file to backup

backuppath="/volume1/backups3"

cd "${backuppath}/syno_app_mover" || exit

backed_up_pkgs=( )
for d in *; do
    if [[ -d "$d" ]] && [[ $d != "@eaDir" ]]; then
        cp "/var/packages/${d}/INFO" "${backuppath}/syno_app_mover/${d}/INFO"
    fi
done < <(find . -maxdepth 2 -type d)
