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

<img src="/images/icons/.png" width="16" height="16"> 

| Package Center Name | System Name | Result |
|---------------------|-------------|--------|
| <img src="/images/icons/ActiveBackup_business_64.png" width="16" height="16"> Active Backup for Business | ActiveBackup | OK |
| <img src="/images/icons/ActiveBackup-GSuite_64.png" width="16" height="16"> Active Backup for Google Workspace | ActiveBackup-GSuite | OK |
| <img src="/images/icons/ActiveBackup-Office365_64.png" width="16" height="16"> Active Backup for Microsoft 365 | ActiveBackup-Office365 | OK |
| <img src="/images/icons/CodecPack_64.png" width="16" height="16"> Advanced Media Extensions | CodecPack | OK |
| <img src="/images/icons/AntiVirus-McAfee_64.png" width="16" height="16"> AntiVirus by McAfee | AntiVirus-McAfee | OK |
| <img src="/images/icons/anti_virus_64.png" width="16" height="16"> AntiVirus Essential | AntiVirus | OK |
| <img src="/images/icons/apache_64.png" width="16" height="16"> Apache HTTP Server 2.4 | Apache2.4 | OK |
| <img src="/images/icons/AudioStation_64.png" width="16" height="16"> Audio Station | AudioStation | OK 	
| <img src="/images/icons/BitDefenderForMailPlus_64.png" width="16" height="16"> Bitdefender for MailPlus | BitDefenderForMailPlus | OK I think |
| <img src="/images/icons/C2IdentityLDAPAgent_64.png" width="16" height="16"> C2 Identity LDAP Server | C2IdentityLDAPAgent | OK |
| <img src="/images/icons/CMS_64.png" width="16" height="16"> Central Management System | CMS | OK |
| <img src="/images/icons/CloudSync_64.png" width="16" height="16"> Cloud Sync | CloudSync | OK |
| <img src="/images/icons/ContainerManager_64.png" width="16" height="16"> Container Manager | ContainerManager | OK |
| <img src="/images/icons/DNSServer_64.png" width="16" height="16"> DNS Server | DNSServer | OK |
| <img src="/images/icons/docker_64.png" width="20" height="20"> Docker | Docker | OK |
| <img src="/images/icons/DocumentViewer_64.png" width="16" height="16"> Document Viewer | DocumentViewer | OK |
| <img src="/images/icons/download_station_64.png" width="20" height="20"> Download Station | DownloadStation | OK |
| <img src="/images/icons/EmbyServer_64.png" width="16" height="16"> Emby Server | EmbyServer | OK |
| <img src="/images/icons/exFAT-Free_72.png" width="16" height="16"> exFAT Access | exFAT-Free | OK |
| <img src="/images/icons/Git_64.png" width="16" height="16"> Git | git | OK - community package |
| <img src="/images/icons/Git_64.png" width="16" height="16"> Git Server | Git | OK |
| <img src="/images/icons/GlacierBackup_64.png" width="16" height="16"> Glacier Backup | GlacierBackup | OK - need a Glacier account to fully test |
| <img src="/images/icons/HyperBackup_64.png" width="16" height="16"> Hyper Backup | HyperBackup | OK |
| <img src="/images/icons/HyperBackupVault_64.png" width="16" height="16"> Hyper Backup Vault | HyperBackupVault | OK |
| <img src="/images/icons/DirectoryServer_64.png" width="16" height="16"> LDAP Server | DirectoryServer | OK |
| <img src="/images/icons/LogAnalysis_64.png" width="16" height="16"> LogAnalysis | LogAnalysis | OK - community package [link](https://github.com/toafez/LogAnalysis) |
| <img src="/images/icons/log_center_64.png" width="16" height="16"> Log Center | LogCenter | OK |
| <img src="/images/icons/MailStation_64.png" width="16" height="16"> Mail Station | MailStation | OK |
| <img src="/images/icons/MariaDB10_64.png" width="20" height="20"> MariaDB 10 | MariaDB10 | OK |
| <img src="/images/icons/MediaServer_64.png" width="16" height="16"> Media Server | MediaServer | OK |
| <img src="/images/icons/mediainfo-64.png" width="16" height="16"> MediaInfo | mediainfo | OK - community package |
| <img src="/images/icons/MinimServer_64.png" width="16" height="16"> MinimServer | MinimServer | OK |
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
| <img src="/images/icons/SynologyDrive_64.png" width="16" height="16"> Synology Drive Server | SynologyDrive | OK |
| <img src="/images/icons/MailServer_64.png" width="16" height="16"> Synology Mail Server | MailServer | OK |
| <img src="/images/icons/MailClient_64.png" width="16" height="16"> Synology MailPlus | MailPlus | OK |
| <img src="/images/icons/MailPlus-Server_64.png" width="16" height="16"> Synology MailPlus Server | MailPlus-Server | OK I think |
| <img src="/images/icons/Spreadsheet_64.png" width="16" height="16"> Synology Office | Spreadsheet | OK |
| <img src="/images/icons/photos_64.png" width="16" height="16"> Synology Photos | SynologyPhotos | OK |
| <img src="/images/icons/Tailscale_64.png" width="16" height="16"> Tailscale | Tailscale | OK |
| <img src="/images/icons/TextEditor_64.png" width="16" height="16"> Text Editor | TextEditor | OK |
| <img src="/images/icons/UniversalViewer_64.png" width="16" height="16"> Universal Viewer | UniversalViewer | OK |
| <img src="/images/icons/VideoStation_64.png" width="16" height="16"> Video Station | VideoStation | OK |
| <img src="/images/icons/VirtualManagement_64.png" width="16" height="16"> Virtual Machine Manager | Virtualization | OK |
| <img src="/images/icons/VPNCenter_64.png" width="16" height="16"> VPN Server | VPNCenter | OK |
| <img src="/images/icons/WebStation_64.png" width="16" height="16"> Web Station | WebStation | OK |
| <img src="/images/icons/WebDAVServer_64.png" width="16" height="16"> WebDAV Server | WebDAVServer | OK |

</details>

#### Packages not tested

<details>
  <summary>Click here to see list</summary>

| Package | Result / Notes |
|---------|--------|
| Archiware P5 |  |
| <img src="/images/icons/AvrCenter_64.png" width="16" height="16"> AvrCenter | community package |
| <img src="/images/icons/AvrLogger_64.png" width="16" height="16"> AvrLogger | community package |
| BRAVIA Signage | Won't install in Container Manager. It checks if Docker is installed |
| Data Deposit Box |  |
| <img src="/images/icons/diagnosis_64.png" width="20" height="20"> Diagnosis Tool |  |
| Domotz Network Monitoring |  |
| ElephantDrive |  |
| <img src="/images/icons/gateone-64.png" width="16" height="16"> GateOne |  |
| GoodSync |  |
| IDrive |  |
| <img src="/images/icons/jackett-64.png" width="16" height="16"> Jackett | community package |
| <img src="/images/icons/Joomla_64.png" width="16" height="16"> Joomla |  |
| KodiExplorer |  |
| MediaWiki |  |
| <img src="/images/icons/medusa-64.png" width="18" height="18"> Medusa | community package [link](https://github.com/BenjV/SYNO-packages) |
| MEGAcmd |  |
| NAKIVO Backup and Replication |  |
| NAKIVO Transporter |  |
| PACS |  |
| Ragic Cloud DB |  |
| <img src="/images/icons/resiliosync-48.png" width="16" height="16"> Resilo Sync |  |
| <img src="/images/icons/shellinabox-48.png" width="16" height="16"> Shellinabox | community package |
| <img src="/images/icons/syncthing-64.png" width="18" height="18"> Syncthing |  |
| TeamViewer |  |
| <img src="/images/icons/transmission-64.png" width="20" height="20"> Transmission | community package |
| VirtualHere |  |
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
