sudo pacman -Sy wpa_actiond
wl=`ip l                       \ 
      |grep w                  \ 
      |head -n1                \
      |awk -F ' ' '{print $2}' \
      |sed s/://               \
    `
sudo systemctl enable netctl-auto@$wl.service
sudo systemctl start netctl-auto@$wl.service
