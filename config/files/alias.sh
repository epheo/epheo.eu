alias lk='swaylock --color 000000'

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias ls="ls --color -F"
alias ll="ls --color -lh"

alias dock=" \
            sudo dhclient enp0s25; \
            setdns; \
           "
alias undock="xrandr --output eDP1 \
                     --primary \
                     --auto \
                     --output DP1-2 \
                     --off \
             "

alias lsn="ls -lah --color=never"   
alias cdm="cd /mnt/data/lapierrt/Music &&\
           lsn \
          "

alias vpnhp="sudo -E openconnect --juniper \
                                 -u W60017252 \
                                 https://uk.remoteaccess.hp.com \
                                 --authgroup OATH; \
            "
alias vpnhg="sudo -E openconnect --juniper \
                                 -u W60017252 \
                                 https://global.remoteaccess.hp.com \
                                 --authgroup OATH; \
            "
alias vpnlab="sudo openvpn /etc/openvpn/lab.ovpn"

alias lumd="xbacklight -dec 10"
alias lumi="xbacklight -inc 10"

alias lum=" read &&           \
            sudo echo $REPLY  \
              | sudo tee      \
              --append  /sys/class/backlight/intel_backlight/brightness
          "


alias sd='cd ~/git/shaddock-openstack; \
          cd ~/git/shaddock/; \
         '

alias killwl='sudo ip l s wlo1 down; \
               sudo killall dhcpcd \
             '

alias setdns="sudo echo 'domain epheo.eu' \
                         | sudo tee /etc/resolv.conf \
                         > /dev/null &&\
              sudo echo 'search epheo.eu' \
                         | sudo tee --append /etc/resolv.conf \
                         > /dev/null &&\
              sudo echo 'nameserver 8.8.8.8' \
                         | sudo tee --append /etc/resolv.conf \
                         > /dev/null \
             "

alias brw="qutebrowser --backend=webengine &"

