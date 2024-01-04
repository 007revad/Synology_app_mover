# Synology move apps

<a href="https://github.com/007revad/Synology_move_apps/releases"><img src="https://img.shields.io/github/release/007revad/Synology_move_apps.svg"></a>
<a href="https://hits.seeyoufarm.com"><img src="https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2F007revad%2FSynology_move_apps&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=views&edge_flat=false"/></a>
[![](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/007revad)
[![committers.top badge](https://user-badge.committers.top/australia/007revad.svg)](https://user-badge.committers.top/australia/007revad)

### Description

Easily move Synology packages from one volume to another volume

  - Supports DSM 7 and DSM 6.

### Download the script

See <a href=images/how_to_download_generic.png/>How to download the script</a> for the easiest way to download the script.

### To run the script

```YAML
sudo -i /volume1/scripts/syno_move_apps.sh
```

**Note:** Replace /volume1/scripts/ with the path to where the script is located.

### Troubleshooting

If the script won't run check the following:

1. If the path to the script contains any spaces you need to enclose the path/scriptname in double quotes:
   ```YAML
   sudo -i "/volume1/my scripts/syno_move_apps.sh"
   ```
2. Make sure you unpacked the zip or rar file that you downloaded and are trying to run the syno_move_apps.sh file.
3. Set the syno_create_m2_volume.sh file as executable:
   ```YAML
   sudo chmod +x "/volume1/scripts/syno_move_apps.sh"
   ```

### DSM 7 screen shot

<p align="center"><img src="/images/app.png"></p>

