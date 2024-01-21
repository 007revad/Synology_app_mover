# Synology app mover

<a href="https://github.com/007revad/Synology_app_mover/releases"><img src="https://img.shields.io/github/release/007revad/Synology_app_mover.svg"></a>
<a href="https://hits.seeyoufarm.com"><img src="https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2F007revad%2FSynology_app_mover&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=views&edge_flat=false"/></a>
[![](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/007revad)
[![committers.top badge](https://user-badge.committers.top/australia/007revad.svg)](https://user-badge.committers.top/australia/007revad)

### Description

Easily move Synology packages from one volume to another volume

You just select the package and the destination volume and the script will stop the app, move it, update the symlinks then start the app.

Handy for moving packages to an SSD volume.

  - Supports DSM 7. Not tested with DSM 6.


### Packages confirmed working (or being tested)

<details>
  <summary>Click here to see list</summary>

| Package | Result |
|---------|--------|
| Active Backup |  |
| Active Backup GSuite |  |
| Active Backup Office365 |  |
| AntiVirus Essential | OK |
| AntiVirus by McAfee | OK |
| Apache 2.4 | OK |
| Audio Station | OK |	
| C2 Identity LDAP Agent | OK but I don't have a C2 account to fully test |
| Calendar | OK |
| Cloud Sync | OK |
| CMS | OK |
| Codec Pack | OK |
| Contacts | OK |
| Container Manager | OK |
| Directory Server | OK |
| Directory Server For Windows Domain | OK |
| DNS Server | OK |
| Download Station | OK |
| Emby Server | OK |
| exFAT-Free | OK |
| git | OK |
| Git | OK |
| Hyper Backup |  |
| Hyper Backup Vault |  |
| LogAnalysis | OK |
| Log Center | OK |
| MailPlus | OK |
| MailPlus Server | OK |
| Mail Server | OK |
| Mail Station | OK |
| MariaDB 10 | OK |
| Media Server | OK |
| MediaInfo | OK |
| MinimServer | OK |
| Node.js v14 | OK |
| Node.js v16 | OK |
| Node.js v18 | OK |
| Node.js v20 | OK |
| Note Station | OK |
| PDF Viewer | OK |
| Perl | OK |
| PHP 7.3 | OK |
| PHP 7.4 | OK |
| PHP 8.0 | OK |
| PHP 8.1 | OK |
| PHP 8.2 | OK |
| Plex Media Server | OK |
| Presto File Server | OK |
| Proxy Server | OK |
| Python 3.9 | OK |
| Radius Server | OK |
| Snapshot Replication | OK |
| SSO Server | OK |
| Storage Analyzer | OK |
| Surveillance Station | OK |
| SynoCli Tools | OK |
| Synology Application Service | OK |
| Synology Chat Server | OK |
| Synology Drive | OK |
| Synology Office (aka SpreadSheet) | OK |
| Synology Photos | OK |
| Synology Virtual Machine | OK |
| Syno Smis Provider | OK |
| Tailscale | OK |
| Text Editor | OK |
| Universal Viewer | OK |
| Video Station | OK |
| VPN Center | OK |
| WebDAV Server | OK |
| Web Station | OK |

</details>

#### Packages not tested

<details>
  <summary>Click here to see list</summary>

| Package | Result |
|---------|--------|
| Archiware P5 |  |
| BRAVIA Signage |  |
| Data Deposit Box |  |
| Domotz Network Monitoring |  |
| ElephantDrive |  |
| GoodSync |  |
| IDrive |  |
| KodiExplorer |  |
| MEGAcmd |  |
| NAKIVO Backup and Replication |  |
| NAKIVO Transporter |  |
| Ragic Cloud DB |  |
| Resilo Sync |  |
| TeamViewer |  |
| VirtualHere |  |

</details>

#### Packages that won't be tested

<details>
  <summary>Click here to see list</summary>

These need MarioDB and they either fail to install or don't run properly!?!?

**Note:** I will not test any package that needs MariaDB.

| Package | Result |
|---------|--------|
| Joomla | Doesn't install |
| MediaWiki | Doesn't install |
| PACS |  Won't test |
| phpMyAdmin | Won't test |
| Wordpress | Won't test |
| vtigerCRM | Installs but doesn't run |

</details>


### Download the script

1. Download the latest version _Source code (zip)_ from https://github.com/007revad/Synology_app_mover/releases
2. Save the download zip file to a folder on the Synology.
3. Unzip the zip file.

### To run the script

[How to enable SSH and login to DSM via SSH](https://kb.synology.com/en-global/DSM/tutorial/How_to_login_to_DSM_with_root_permission_via_SSH_Telnet)

```YAML
sudo -i /volume1/scripts/syno_app_mover.sh
```

**Note:** Replace /volume1/scripts/ with the path to where the script is located.

### Troubleshooting

If the script won't run check the following:

1. Make sure you download the zip file and unzipped it to a folder on your Synology (not on your computer).
2. If the path to the script contains any spaces you need to enclose the path/scriptname in double quotes:
   ```YAML
   sudo -i "/volume1/my scripts/syno_app_mover.sh"
   ```
3. Make sure you unpacked the zip or rar file that you downloaded and are trying to run the syno_app_mover.sh file.
4. Set the script file as executable:
   ```YAML
   sudo chmod +x "/volume1/scripts/syno_app_mover.sh"
   ```

### DSM 7 screenshots

<p align="center"><img src="/images/app.png"></p>

<p align="center"><img src="/images/docker.png"></p>

