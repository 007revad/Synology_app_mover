# Synology app mover

<a href="https://github.com/007revad/Synology_app_mover/releases"><img src="https://img.shields.io/github/release/007revad/Synology_app_mover.svg"></a>
<a href="https://hits.seeyoufarm.com"><img src="https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2F007revad%2FSynology_app_mover&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=views&edge_flat=false"/></a>
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/paypalme/007revad)
[![](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/007revad)
[![committers.top badge](https://user-badge.committers.top/australia/007revad.svg)](https://user-badge.committers.top/australia/007revad)

### Description

Easily move Synology packages from one volume to another volume

You just select the package and the destination volume and the script will stop the app, move it, update the symlinks then start the app.

Handy for moving packages to an SSD volume, or to another volume so you can delete the original volume.

**NEW** Now includes [Backup and Restore modes](/images/backup.png).

  - Supports DSM 7. Not fully tested with DSM 6.


### Packages confirmed working

**NOTE:** Just in case, you should backup your docker compose files or portainer stacks.

<details>
  <summary>Click here to see list</summary>

| Package Center Name | System Name | Result |
|---------------------|-------------|--------|
| <img src="/images/icons/ActiveBackup_business_64.png" width="16" height="16"> Active Backup for Business | ActiveBackup | OK |
| Active Backup for Google Workspace | ActiveBackup-GSuite | OK |
| Active Backup for Microsoft 365 | ActiveBackup-Office365 | OK |
| Advanced Media Extensions | CodecPack | OK |
| AntiVirus by McAfee | AntiVirus-McAfee | OK |
| <img src="/images/icons/anti_virus_64.png" width="16" height="16"> AntiVirus Essential | AntiVirus | OK |
| Apache HTTP Server 2.4 | Apache2.4 | OK |
| <img src="/images/icons/AudioStation_64.png" width="16" height="16"> Audio Station | AudioStation | OK 	
| Bitdefender for MailPlus | BitDefenderForMailPlus | OK I think |
| C2 Identity LDAP Server | C2IdentityLDAPAgent | OK |
| <img src="/images/icons/CMS_64.png" width="16" height="16"> Central Management System | CMS | OK |
| <img src="/images/icons/CloudSync_64.png" width="16" height="16"> Cloud Sync | CloudSync | OK |
| <img src="/images/icons/ContainerManager_64.png" width="16" height="16"> Container Manager | ContainerManager | OK |
| DNS Server | DNSServer | OK |
| <img src="/images/icons/docker_64.png" width="16" height="16"> Docker | Docker | OK |
| Document Viewer | DocumentViewer | OK |
| <img src="/images/icons/download_station_64.png" width="16" height="16"> Download Station | DownloadStation | OK |
| Emby Server | EmbyServer | OK |
| exFAT Access | exFAT-Free | OK |
| git | git | OK |
| <img src="/images/icons/Git_64.png" width="16" height="16"> Git | Git | OK |
| Glacier Backup | GlacierBackup | OK - need a Glacier account to fully test |
| <img src="/images/icons/HyperBackup_64.png" width="16" height="16"> Hyper Backup | HyperBackup | OK |
| <img src="/images/icons/HyperBackupVault_64.png" width="16" height="16"> Hyper Backup Vault | HyperBackupVault | OK |
| LDAP Server | DirectoryServer | OK |
| <img src="/images/icons/LogAnalysis_64.png" width="16" height="16"> LogAnalysis | LogAnalysis | OK |
| <img src="/images/icons/log_center_64.png" width="16" height="16"> Log Center | LogCenter | OK |
| Mail Station | MailStation | OK |
| MariaDB 10 | MariaDB10 | OK |
| <img src="/images/icons/MediaServer_64.png" width="16" height="16"> Media Server | MediaServer | OK |
| MediaInfo | mediainfo | OK |
| MinimServer | MinimServer | OK |
| phpMyAdmin | phpMyAdmin | OK |
| Node.js v14 | Node.js_v14 | OK |
| Node.js v16 | Node.js_v16 | OK |
| Node.js v18 | Node.js_v18 | OK |
| Node.js v20 | Node.js_v20 | OK |
| Note Station | NoteStation | OK |
| PDF Viewer | PDFViewer | OK |
| Perl | Perl | OK |
| PHP 7.3 | PHP7.3 | OK |
| PHP 7.4 | PHP7.4 | OK |
| PHP 8.0 | PHP8.0 | OK |
| PHP 8.1 | PHP8.1 | OK |
| PHP 8.2 | PHP8.2 | OK |
| <img src="/images/icons/plexmediaserver_48.png" width="16" height="16"> Plex Media Server | PlexMediaServer | OK |
| Presto File Server | PrestoServer | OK |
| Proxy Server | ProxyServer | OK |
| Python 3.9 | Python3.9 | OK |
| Radius Server | RadiusServer | OK |
| SMI-S Provider | SynoSmisProvider | OK |
| <img src="/images/icons/SnapshotReplication_64.png" width="16" height="16"> Snapshot Replication | SnapshotReplication | OK |
| SSO Server | SSOServer | OK |
| <img src="/images/icons/StorageAnalyzer_64.png" width="16" height="16"> Storage Analyzer | StorageAnalyzer | OK |
| Surveillance Station | SurveillanceStation | OK |
| SynoCli Tools | synocli-"toolname" | OK |
| <img src="/images/icons/SynologyApplicationService_64.png" width="16" height="16"> Synology Application Service | SynologyApplicationService | OK |
| <img src="/images/icons/Calendar_64.png" width="16" height="16"> Synology Calendar | Calendar | OK |
| Synology Chat Server | Chat | OK |
| Synology Contacts | Contacts | OK |
| Synology Directory Server | DirectoryServerForWindowsDomain | OK |
| <img src="/images/icons/SynologyDrive_64.png" width="16" height="16"> Synology Drive Server | SynologyDrive | OK |
| Synology Mail Server | MailServer | OK |
| Synology MailPlus | MailPlus | OK |
| Synology MailPlus Server | MailPlus-Server | OK I think |
| Synology Office | Spreadsheet | OK |
| <img src="/images/icons/photos_64.png" width="16" height="16"> Synology Photos | SynologyPhotos | OK |
| Tailscale | Tailscale | OK |
| <img src="/images/icons/TextEditor_64.png" width="16" height="16"> Text Editor | TextEditor | OK |
| Universal Viewer | UniversalViewer | OK |
| <img src="/images/icons/VideoStation_64.png" width="16" height="16"> Video Station | VideoStation | OK |
| <img src="/images/icons/VirtualManagement_64.png" width="16" height="16"> Virtual Machine Manager | Virtualization | OK |
| VPN Server | VPNCenter | OK |
| <img src="/images/icons/WebStation_64.png" width="16" height="16"> Web Station | WebStation | OK |
| WebDAV Server | WebDAVServer | OK |

</details>

#### Packages not tested

<details>
  <summary>Click here to see list</summary>

| Package | Result |
|---------|--------|
| Archiware P5 |  |
| BRAVIA Signage | Won't install in Container Manager. It checks if Docker is installed |
| Data Deposit Box |  |
| <img src="/images/icons/diagnosis_64.png" width="20" height="20"> Diagnosis Tool |  |
| Domotz Network Monitoring |  |
| ElephantDrive |  |
| <img src="/images/icons/gateone-64.png" width="16" height="16"> GateOne |  |
| GoodSync |  |
| IDrive |  |
| <img src="/images/icons/jackett-64.png" width="16" height="16"> Jackett |  |
| Joomla |  |
| KodiExplorer |  |
| <img src="/images/icons/mediainfo-64.png" width="16" height="16"> MediaInfo |  |
| MediaWiki |  |
| <img src="/images/icons/medusa-64.png" width="18" height="18"> Medusa |  |
| MEGAcmd |  |
| NAKIVO Backup and Replication |  |
| NAKIVO Transporter |  |
| PACS |  |
| Ragic Cloud DB |  |
| <img src="/images/icons/resiliosync-48.png" width="16" height="16"> Resilo Sync |  |
| <img src="/images/icons/shellinabox-48.png" width="16" height="16"> Shellinabox |  |
| <img src="/images/icons/syncthing-64.png" width="18" height="18"> Syncthing |  |
| TeamViewer |  |
| <img src="/images/icons/transmission-64.png" width="20" height="20"> Transmission |  |
| VirtualHere |  |
| vtigerCRM |  |
| <img src="/images/icons/WebTools-48.png" width="20" height="20"> WebTools |  |
| Wordpress |  |

</details>

### Download the script

1. Download the latest version _Source code (zip)_ from https://github.com/007revad/Synology_app_mover/releases
2. Save the download zip file to a folder on the Synology.
3. Unzip the zip file.

### Set backup location

If you want to use use the [backup and restore options](/images/backup.png) you need edit the included **syno_app_mover.conf** file to set the location to backup to.

The **syno_app_mover.conf** file must be in the same foller as the **syno_app_mover.sh file**.

**Other options in syno_app_mover.conf**
```YAML
# buffer is used when checking if target volume has enough space
# Add 50 GB buffer so we don't fill the target volume

buffer=50

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
```

### To run the script

[How to enable SSH and login to DSM via SSH](https://kb.synology.com/en-global/DSM/tutorial/How_to_login_to_DSM_with_root_permission_via_SSH_Telnet)

```YAML
sudo -s /volume1/scripts/syno_app_mover.sh
```

**Note:** Replace /volume1/scripts/ with the path to where the script is located.

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

<p align="center">Moving Active Backup for Bussiness</p>
<p align="center"><img src="/images/app6.png"></p>

<br>

<p align="center">Backing up Audio Station</p>
<p align="center"><img src="/images/backup.png"></p>

### Credits
- wallacebrf for extensive beta testing of syno_app_mover v3.
