# <img src="images/pkg_center_64_blurr.png" width="54"> Synology app mover

<a href="https://github.com/007revad/Synology_app_mover/releases"><img src="https://img.shields.io/github/release/007revad/Synology_app_mover.svg"></a>
<a href="https://hits.seeyoufarm.com"><img src="https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2F007revad%2FSynology_app_mover&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=views&edge_flat=false"/></a>
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/paypalme/007revad)
[![](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/007revad)
[![committers.top badge](https://user-badge.committers.top/australia/007revad.svg)](https://user-badge.committers.top/australia/007revad)

### Description

Easily move Synology packages from one volume to another volume

You just select the package and the destination volume and the script will stop the app, move it, update the symlinks then start the app.

Handy for moving packages to an SSD volume, or to another volume so you can delete the original volume.

**Now** includes [Backup and Restore modes](/images/backup.png).

  - Supports DSM 7. Not fully tested with DSM 6.
  - If backing up to a USB drive the partition's file system should be ext3, ext4 of btrfs.

### Packages confirmed working

**NOTE:** Just in case, you should backup your docker compose files or portainer stacks.

<details>
  <summary>Click here to see list</summary>

<img src="/images/icons/.png" width="16" height="16"> 

The icons in this table are [Copyright © 2004-2024 Synology Inc.](https://kb.synology.com/en-br/DSM/help/DSM/Home/about?version=7) or Copyright the 3rd party package developer.

| Package Center Name | System Name | Result |
|---------------------|-------------|--------|
| <img src="/images/icons/ActiveBackup_business_64.png" width="16" height="16"> Active Backup for Business | ActiveBackup | OK |
| <img src="/images/icons/ActiveBackup-GSuite_64.png" width="16" height="16"> Active Backup for Google Workspace | ActiveBackup-GSuite | OK |
| <img src="/images/icons/ActiveBackup-Office365_64.png" width="16" height="16"> Active Backup for Microsoft 365 | ActiveBackup-Office365 | OK |
| <img src="/images/icons/CodecPack_64.png" width="16" height="16"> Advanced Media Extensions | CodecPack | OK |
| <img src="/images/icons/AntiVirus-McAfee_64.png" width="16" height="16"> AntiVirus by McAfee | AntiVirus-McAfee | OK |
| <img src="/images/icons/anti_virus_64.png" width="16" height="16"> AntiVirus Essential | AntiVirus | OK - [Use v4.2.88 or later](https://github.com/007revad/Synology_app_mover/releases) |
| <img src="/images/icons/apache_64.png" width="16" height="16"> Apache HTTP Server 2.4 | Apache2.4 | OK |
| <img src="/images/icons/bb-qq_64.png" width="16" height="16"> AQC111 driver | aqc111 | OK - 3rd party package [link](https://github.com/bb-qq/aqc111) |
| <img src="/images/icons/AudioStation_64.png" width="16" height="16"> Audio Station | AudioStation | OK |
| <img src="/images/icons/AvrLogger_64.png" width="20" height="20"> AvrLogger | AvrLogger | OK - community package [link](https://luenepiet.de/public/Synology/AvrLogger%20(SPK)/) |
| <img src="/images/icons/BitDefenderForMailPlus_64.png" width="16" height="16"> Bitdefender for MailPlus | BitDefenderForMailPlus | OK I think |
| <img src="/images/icons/C2IdentityLDAPAgent_64.png" width="16" height="16"> C2 Identity LDAP Server | C2IdentityLDAPAgent | OK |
| <img src="/images/icons/CMS_64.png" width="16" height="16"> Central Management System | CMS | OK |
| <img src="/images/icons/ChannelsDVR_64.png" width="16" height="16"> Channels DVR | ChannelsDVR | OK - 3rd party package [link](https://getchannels.com/dvr-server/#synology) |
| <img src="/images/icons/CloudSync_64.png" width="16" height="16"> Cloud Sync | CloudSync | OK |
| <img src="/images/icons/ContainerManager_64.png" width="16" height="16"> Container Manager 24.0.2 | ContainerManager | ? |
| <img src="/images/icons/ContainerManager_64.png" width="16" height="16"> Container Manager 20.10.23 | ContainerManager | OK |
| <img src="/images/icons/DNSServer_64.png" width="16" height="16"> DNS Server | DNSServer | OK |
| <img src="/images/icons/docker_64.png" width="20" height="20"> Docker | Docker | OK |
| <img src="/images/icons/DocumentViewer_64.png" width="16" height="16"> Document Viewer | DocumentViewer | OK |
| <img src="/images/icons/download_station_64.png" width="20" height="20"> Download Station | DownloadStation | OK |
| <img src="/images/icons/EmbyServer_64.png" width="16" height="16"> Emby Server | EmbyServer | OK |
| <img src="/images/icons/exFAT-Free_72.png" width="16" height="16"> exFAT Access | exFAT-Free | OK |
| <img src="/images/icons/ffmpeg_72.png" width="18" height="18"> FFmpeg | ffmpeg# | OK - community package |
| <img src="/images/icons/Git_64.png" width="16" height="16"> Git | git | OK - community package |
| <img src="/images/icons/Git_64.png" width="16" height="16"> Git Server | Git | OK |
| <img src="/images/icons/GlacierBackup_64.png" width="16" height="16"> Glacier Backup | GlacierBackup | OK - Need to run backup task again |
| <img src="/images/icons/HyperBackup_64.png" width="16" height="16"> Hyper Backup | HyperBackup | OK |
| <img src="/images/icons/HyperBackupVault_64.png" width="16" height="16"> Hyper Backup Vault | HyperBackupVault | OK |
| <img src="/images/icons/jellyfin-64.png" width="20" height="20"> Jellyfin | jellyfin | OK |
| <img src="/images/icons/DirectoryServer_64.png" width="16" height="16"> LDAP Server | DirectoryServer | OK |
| <img src="/images/icons/LogAnalysis_64.png" width="16" height="16"> LogAnalysis | LogAnalysis | OK - community package [link](https://github.com/toafez/LogAnalysis) |
| <img src="/images/icons/log_center_64.png" width="16" height="16"> Log Center | LogCenter | OK |
| <img src="/images/icons/MailStation_64.png" width="16" height="16"> Mail Station | MailStation | OK |
| <img src="/images/icons/MariaDB10_64.png" width="20" height="20"> MariaDB 10 | MariaDB10 | OK |
| <img src="/images/icons/MediaServer_64.png" width="16" height="16"> Media Server | MediaServer | OK |
| <img src="/images/icons/mediainfo-64.png" width="16" height="16"> MediaInfo | mediainfo | OK - community package |
| <img src="/images/icons/MinimServer_64.png" width="16" height="16"> MinimServer | MinimServer | OK |
| <img src="/images/icons/Mosquitto_64.png" width="16" height="16"> Mosquitto | mosquitto | OK - community package |
| <img src="/images/icons/phpMyAdmin_72.png" width="20" height="20"> phpMyAdmin | phpMyAdmin | OK |
| <img src="/images/icons/Node.js_cropped.png" width="36" height="17"> Node.js | Node.js_v## | OK |
| <img src="/images/icons/NoteStation_64.png" width="16" height="16"> Note Station | NoteStation | OK |
| <img src="/images/icons/PDFViewer_64.png" width="16" height="16"> PDF Viewer | PDFViewer | OK |
| <img src="/images/icons/Perl_64.png" width="16" height="16"> Perl | Perl | OK |
| <img src="/images/icons/PHP_64.png" width="16" height="16"> PHP | PHP#.# | OK |
| <img src="/images/icons/plexmediaserver_48.png" width="16" height="16"> Plex Media Server | PlexMediaServer | OK |
| <img src="/images/icons/PrestoServer_64.png" width="16" height="16"> Presto File Server | PrestoServer | OK |
| <img src="/images/icons/ProxyServer_64.png" width="16" height="16"> Proxy Server | ProxyServer | OK |
| <img src="/images/icons/Python_64.png" width="16" height="16"> Python 3.9 | Python3.9 | OK |
| <img src="/images/icons/bb-qq_64.png" width="16" height="16"> RTL8152/RTL8153 driver | r8152 | OK - 3rd party package [link](https://github.com/bb-qq/r8152) |
| <img src="/images/icons/RadiusServer_64.png" width="16" height="16"> RADIUS Server | RadiusServer | OK |
| <img src="/images/icons/SynoSmisProvider_64.png" width="16" height="16"> SMI-S Provider | SynoSmisProvider | OK |
| <img src="/images/icons/SnapshotReplication_64.png" width="16" height="16"> Snapshot Replication | SnapshotReplication | OK |
| <img src="/images/icons/SSOServer_64.png" width="16" height="16"> SSO Server | SSOServer | OK |
| <img src="/images/icons/StorageAnalyzer_64.png" width="16" height="16"> Storage Analyzer | StorageAnalyzer | OK |
| <img src="/images/icons/SurveillanceStation_64.png" width="16" height="16"> Surveillance Station | SurveillanceStation | OK |
| <img src="/images/icons/synocli_72.png" width="16" height="16"> SynoCli Tools | synocli-"toolname" | OK - community package |
| <img src="/images/icons/SynologyApplicationService_64.png" width="16" height="16"> Synology Application Service | SynologyApplicationService | OK |
| <img src="/images/icons/Calendar_64.png" width="16" height="16"> Synology Calendar | Calendar | OK |
| <img src="/images/icons/Chat_64.png" width="16" height="16"> Synology Chat Server | Chat | OK |
| <img src="/images/icons/Contacts_64.png" width="16" height="16"> Synology Contacts | Contacts | OK |
| <img src="/images/icons/DirectoryServerForWindowsDomain_64.png" width="16" height="16"> Synology Directory Server | DirectoryServerForWindowsDomain | OK |
| <img src="/images/icons/SynologyDrive_64.png" width="16" height="16"> Synology Drive Server | SynologyDrive | OK - see [Synology Drive and Btrfs Snapshots](https://github.com/007revad/Synology_app_mover#synology-drive-and-btrfs-snapshots) |
| <img src="/images/icons/MailServer_64.png" width="16" height="16"> Synology Mail Server | MailServer | OK |
| <img src="/images/icons/MailClient_64.png" width="16" height="16"> Synology MailPlus | MailPlus | OK |
| <img src="/images/icons/MailPlus-Server_64.png" width="16" height="16"> Synology MailPlus Server | MailPlus-Server | OK I think |
| <img src="/images/icons/Spreadsheet_64.png" width="16" height="16"> Synology Office | Spreadsheet | OK |
| <img src="/images/icons/photos_64.png" width="16" height="16"> Synology Photos | SynologyPhotos | OK |
| <img src="/images/icons/Tailscale_64.png" width="16" height="16"> Tailscale | Tailscale | OK |
| <img src="/images/icons/TextEditor_64.png" width="16" height="16"> Text Editor | TextEditor | OK |
| <img src="/images/icons/UniversalViewer_64.png" width="16" height="16"> Universal Viewer | UniversalViewer | OK |
| <img src="/images/icons/USBCopy_64.png" width="18" height="18"> USB Copy | USBCopy | see [moving_extras](moving_extras.md)
| <img src="/images/icons/VideoStation_64.png" width="16" height="16"> Video Station | VideoStation | OK |
| <img src="/images/icons/VirtualManagement_64.png" width="16" height="16"> Virtual Machine Manager | Virtualization | OK |
| <img src="/images/icons/VPNCenter_64.png" width="16" height="16"> VPN Server | VPNCenter | OK |
| <img src="/images/icons/WebStation_64.png" width="16" height="16"> Web Station | WebStation | OK |
| <img src="/images/icons/WebDAVServer_64.png" width="16" height="16"> WebDAV Server | WebDAVServer | OK |

</details>

#### Packages not tested

<details>
  <summary>Click here to see list</summary>

<img src="/images/icons/.png" width="16" height="16"> 

The icons in this table are [Copyright © 2004-2024 Synology Inc.](https://kb.synology.com/en-br/DSM/help/DSM/Home/about?version=7) or Copyright the 3rd party package developer.

| Package | Result / Notes |
|---------|--------|
| <img src="/images/icons/ArchiwareP5_64.png" width="16" height="16"> Archiware P5 |  |
| <img src="/images/icons/Sony_BraviaSignage_64.png" width="16" height="16"> BRAVIA Signage | Won't install in Container Manager. It checks if Docker is installed |
| <img src="/images/icons/ContainerManager_64.png" width="16" height="16"> Container Manager 24.0.2 |  |
| <img src="/images/icons/DdbBackup_64.png" width="18" height="18"> Data Deposit Box |  |
| <img src="/images/icons/diagnosis_64.png" width="20" height="20"> Diagnosis Tool |  |
| <img src="/images/icons/domotz_64.png" width="16" height="16"> Domotz Network Monitoring |  |
| <img src="/images/icons/elephantdrive_64.png" width="16" height="16"> ElephantDrive |  |
| <img src="/images/icons/gateone-64.png" width="16" height="16"> GateOne |  |
| <img src="/images/icons/GoodSync_64.png" width="16" height="16"> GoodSync |  |
| <img src="/images/icons/iDrive_72.png" width="16" height="16"> IDrive |  |
| <img src="/images/icons/jackett-64.png" width="16" height="16"> Jackett | community package |
| <img src="/images/icons/Joomla_64.png" width="16" height="16"> Joomla |  |
| <img src="/images/icons/KodExplorer_64.png" width="16" height="16"> KodiExplorer |  |
| <img src="/images/icons/MediaWiki_72.png" width="18" height="18"> MediaWiki |  |
| <img src="/images/icons/medusa-64.png" width="18" height="18"> Medusa | community package [link](https://github.com/BenjV/SYNO-packages) |
| <img src="/images/icons/MEGAcmd_64.png" width="16" height="16"> MEGAcmd |  |
| <img src="/images/icons/mono_64.png" width="18" height="18"> Mono | community package |
| <img src="/images/icons/NBR_64.png" width="16" height="16"> NAKIVO Backup and Replication |  |
| <img src="/images/icons/NBR-Transporter_64.png" width="16" height="16"> NAKIVO Transporter |  |
| <img src="/images/icons/PACS_64.png" width="16" height="16"> PACS |  |
| <img src="/images/icons/PhotoStation_64.png" width="18" height="18"> Photo Station | DSM 6 |
| <img src="/images/icons/radarr-64.png" width="20" height="20"> Radarr | community package |
| <img src="/images/icons/RagicBuilder_64.png" width="20" height="20"> Ragic Cloud DB |  |
| <img src="/images/icons/resiliosync-48.png" width="16" height="16"> Resilo Sync |  |
| <img src="/images/icons/shellinabox-48.png" width="16" height="16"> Shellinabox | community package |
| <img src="/images/icons/Sonarr_64.png" width="18" height="18"> Sonarr | community package |
| <img src="/images/icons/syncthing-64.png" width="18" height="18"> Syncthing |  |
| <img src="/images/icons/TeamViewer_64.png" width="16" height="16"> TeamViewer |  |
| <img src="/images/icons/transmission-64.png" width="20" height="20"> Transmission | community package |
| <img src="/images/icons/tvheadend-64.png" width="20" height="20"> Tvheadend | community package |
| <img src="/images/icons/VirtualHere_64.png" width="18" height="18"> VirtualHere |  |
| <img src="/images/icons/vtigerCRM_64.png" width="16" height="16"> vtigerCRM |  |
| <img src="/images/icons/WebTools-48.png" width="20" height="20"> WebTools | community package |
| <img src="/images/icons/Wordpress_64.png" width="16" height="16"> Wordpress |  |

</details>

### Download the script

1. Download the latest version _Source code (zip)_ from https://github.com/007revad/Synology_app_mover/releases
2. Save the download zip file to a folder on the Synology.
3. Unzip the zip file.

### Set backup location

If you want to use use the [backup and restore options](/images/backup.png) you need edit the included **syno_app_mover.conf** file to set the location to backup to.

The **syno_app_mover.conf** file must be in the same folder as the **syno_app_mover.sh file**.

### Settings in syno_app_mover.conf
```YAML
# buffer is used when checking if target volume has enough space
# Add 50 GB buffer so we don't fill the target volume

buffer=50

# The backuppath is only used by Backup and Restore modes
# backuppath should be in the format of /volume/sharename/folder
# For example:
# backuppath="/volume1/backups"
#
# Note: The script will create a syno_app_mover folder in backuppath

backuppath="/volume1/backups"

# Skip backup if previous backup was done less than x minutes ago
# Set to "0" to always backup
# skip_minutes is in minutes

skip_minutes=360

# exclude setting for use when auto="all" option is used to skip specified apps
# For example:
# exclude="ContainerManager"
# exclude="DownloadStation,ContainerManager,HyperBackup"
#
# Note: You need to use the app's system name
# Run syno_app_mover.sh with the --list option to see your app's system names

exclude=

# For Docker or Container Manager's container settings json exports
# Set delete_older to age in days before old exports are deleted
# Set ignored_containers to a list of containers to not export settings
# For example:
# delete_older=7
# ignored_containers="libraspeed-1,netdata"
#
# Note you need use the container's docker name. To see their names via SSH use:
# sudo docker ps -a --format "{{.Names}}"

delete_older=30
ignored_containers=
```

### To run the script via SSH

[How to enable SSH and login to DSM via SSH](https://kb.synology.com/en-global/DSM/tutorial/How_to_login_to_DSM_with_root_permission_via_SSH_Telnet)

```YAML
sudo -s /volume1/scripts/syno_app_mover.sh
```

**Note:** Replace /volume1/scripts/ with the path to where the script is located.

### Options when running the script <a name="options"></a>

There are optional flags you can use when running the script:
```YAML
  -h, --help            Show this help message
  -v, --version         Show the script version
      --autoupdate=AGE  Auto update script (useful when script is scheduled)
                          AGE is how many days old a release must be before
                          auto-updating. AGE must be a number: 0 or greater

      --auto=APP        Automatically backup APP (for scheduling backups)
                          APP can be a single app or a comma separated list
                          APP can also be 'all' to backup all apps (except 
                          any you excluded in the syno_app_mover.conf)
                          Examples:
                          --auto=radarr
                          --auto=Calender,ContainerManager,radarr
                          --auto=all

                          APP names need to be the app's system name
                          View the system names with the --list option

      --list            Display installed apps' system names
```

### Troubleshooting

If the script won't run check the following:

1. Make sure you download the zip file and unzipped it to a folder on your Synology (not on your computer).
2. If the path to the script contains any spaces you need to enclose the path/scriptname in double quotes:
   ```YAML
   sudo -s "/volume1/my scripts/syno_app_mover.sh"
   ```
3. Make sure you unpacked the zip or rar file that you downloaded and are trying to run the syno_app_mover.sh file.
4. Set the script file as executable:
   ```YAML
   sudo chmod +x "/volume1/scripts/syno_app_mover.sh"
   ```

### Synology Drive and Btrfs Snapshots

It seems that Synology Drive handles versioning differently depending on the underlying file system.
For **ext4 volumes**, the versioning database is stored in the internal folder (`/volume1/@synologydrive/@sync/repo`).
However, on **Btrfs volumes**, versioning is managed using **Btrfs snapshots** (see the [Reddit thread here](https://www.reddit.com/r/synology/comments/82o4pv/comment/dvbskzh/)).

This means that if you move Synology Drive's database from **ext4** to **Btrfs**, the `@sync/repo` folder will **not be moved** to the Btrfs volume.
There is a risk of **losing file version history**, though it’s difficult to confirm without more testing.

On the plus side, you will free up space that was previously used by the versioning data on the ext4 volume.

For more details, check out this [GitHub discussion](https://github.com/007revad/Synology_app_mover/discussions/200).

### Video - moving Container Manager

<!-- https://github.com/007revad/Synology_app_mover/assets/39733752/8373dc38-2271-45bd-93f5-357669b7ec40 -->
<!-- https://github.com/user-attachments/assets/e308839a-1a3d-402b-9920-dc98901c1234 -->
https://github.com/007revad/Synology_app_mover/assets/e308839a-1a3d-402b-9920-dc98901c1234

### DSM 7 screenshots

<p align="center">Moving a package (with dependencies)</p>
<p align="center"><img src="/images/app2.png"></p>

<br>

<p align="center">Moving packages with shared folders</p>
<p align="center"><img src="/images/app3.png"></p>
<p align="center"><img src="/images/app4.png"></p>

<br>

<p align="center">Moving a package that has a volume location setting</p>
<p align="center"><img src="/images/app5.png"></p>

<br>

<p align="center">Moving Active Backup for Business</p>
<p align="center"><img src="/images/app6.png"></p>

<br>

<p align="center">Backing up Audio Station</p>
<p align="center"><img src="/images/backup.png"></p>

<br>

<p align="center">Backing up with the --auto option</p>
<p align="center"><img src="/images/auto_option.png"></p>

<br>

<p align="center">Output with --list option</p>
<p align="center"><img src="/images/list_option.png"></p>

### Credits
- wallacebrf for extensive beta testing of syno_app_mover v3.
- ctrlaltdelete for the code to export Container Manager/Docker container's settings.
