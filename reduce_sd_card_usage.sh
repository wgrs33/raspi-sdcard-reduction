#!/bin/bash

remove_swapfile() {
    if dpkg -s dphys-swapfile &> /dev/null; then
        echo "Remove dphys-swapfile..."
        sudo dphys-swapfile swapoff
        sudo dphys-swapfile uninstall
        sudo update-rc.d dphys-swapfile remove
        sudo apt purge dphys-swapfile -y
        echo "Remove dphys-swapfile DONE."
    fi
}

disable_man_db_update() {
    if [ -f /var/lib/man-db/auto-update ]; then
        echo "Remove man-db auto-update..."
        sudo rm /var/lib/man-db/auto-update
        echo "Remove dphys-swapfile DONE."
    fi
}

disable_daily_update() {
    sudo systemctl mask apt-daily-upgrade
    sudo systemctl mask apt-daily
    sudo systemctl disable apt-daily-upgrade.timer
    sudo systemctl disable apt-daily.timer
}

remove_bt_and_modem() {
    echo "Remove modemmanager and bluez..."
    sudo apt remove --purge modemmanager bluez -y
    sudo apt autoremove --purge -y
    echo "Disable BT in /boot/firmware/config.txt"
    echo "dtoverlay=disable-bt" | sudo tee -a /boot/firmware/config.txt
    echo "Remove modemmanager and bluez DONE."
}

remove_others() {
    echo "Remove other programs..."
    sudo apt remove --purge wolfram-engine triggerhappy xserver-common lightdm -y
    sudo apt autoremove --purge -y
    echo "Remove other programs DONE."
}

modify_logging() {
    echo "Move /tmp and /var/spool/rsyslog to tmpfs..."
    echo "tmpfs  /tmp  tmpfs  defaults,noatime,nosuid,nodev  0  0" | sudo tee -a /etc/fstab
    echo "tmpfs  /var/spool/rsyslog  tmpfs  defaults,noatime,nosuid,nodev,noexec,size=50M  0  0" | sudo tee -a /etc/fstab
    echo "Remove all old log files"
    sudo rm /var/log/*.1 /var/log/*.gz /var/log/apt/*.gz || true
    echo "Move /tmp and /var/spool/rsyslog to tmpfs DONE."
}

set_journal_size() {
    echo "Set journald size to 20M..."
    sudo sed -i "s/#SystemMaxUse=/SystemMaxUse=20M/" /etc/systemd/journald.conf
    echo "Set journald size to 20M DONE."
}

install_log2ram() {
    echo "Install log2ram..."
    echo "deb [signed-by=/usr/share/keyrings/azlux-archive-keyring.gpg] http://packages.azlux.fr/debian/ bookworm main" | sudo tee /etc/apt/sources.list.d/azlux.list
    sudo wget -O /usr/share/keyrings/azlux-archive-keyring.gpg  https://azlux.fr/repo.gpg
    sudo apt update
    sudo apt install log2ram
    echo "Install log2ram DONE."
    sudo sed -i "s/SIZE=40M/SIZE=50M/" /etc/log2ram.conf
    sudo sed -i "s/MAIL=true/MAIL=false/" /etc/log2ram.conf
    touch ~/.reduce1
    read -p "Do you want to reboot the system to apply changes? (Y/n): " answer
    case "$answer" in
        Y) 
            echo "Rebooting the system to apply changes..."
            sudo reboot
            ;;
        n)
            echo "No reboot required. Exiting script."
            exit 0
            ;;
        *)
            echo "Invalid response. Exiting script."
            exit 1
            ;;
    esac
}

set_log2ram() {
    echo "Set log2ram for /var/log..."
    sudo systemctl status log2ram
    sudo journalctl -u log2ram -e
    sudo sed -i 's/ext4    defaults/ext4    defaults,commit=900/' /etc/fstab
    device=$(mount | grep "on / " | grep -oP '(?<=/dev/)\S+')
    sudo tune2fs -c 1 /dev/$device
    echo "Set log2ram for /var/log DONE."
}

set -e

if [ -f ~/.reduce1 ]; then
    rm ~/.reduce1
    set_log2ram
else
    remove_swapfile
    disable_man_db_update
    disable_daily_update
    remove_bt_and_modem
    remove_others
    modify_logging
    set_journal_size
    install_log2ram
fi
