#!/bin/bash

if [[ "$HOSTNAME" == "archiso" ]]; then
	clear
else
	clear
	printf "You are not in an Arch ISO environment!\n"
	sleep 1.6
	exit
fi
echo "A Simpler Archinstall"
sleep 1
clear
printf "Hello! This is a script to install Arch Linux, please select the drive/partition you want to install on!\n"
sleep 2
lsblk
read -rp "Tell me your install victim (for example, /dev/sda or /dev/nvme0n1): " diskChoice
printf "$diskChoice Selected!"
sleep 2
clear

PS3="Would you like to wipe your drive first? It will be wiped regardless to install, but here, I mean a full zeroing, which is recommended.
"
options=("Yes" "No")
select opt in "${options[@]}"
do
  case $opt in
    "Yes")
      dd if=/dev/zero of="$diskChoice" BS=16M conv=fsync status=progress
      break
      ;;
    "No")
      fdisk "$diskChoice" <<EOF
g
w
EOF
      break
      ;;
    *)
      echo "Invalid Option: $REPLY"
      sleep 1.6
      ;;
  esac
done

fdisk "$diskChoice" <<EOF
g
n
1

+1G
t
1
n
2


w
EOF

clear
lsblk -f
echo "Give me the EFI partition. It should be something like /dev/sda1 or /dev/nvme0n1p1. It is the 1GB one."
read -rp "EFI PARTITION: " efiPart
clear
lsblk -f
echo "Give me the root partition that will have all of your files. It should be something like /dev/sda2 or /dev/nvme0n1p2."
read -rp "ROOT PARTITION: " rootPart

mkfs.fat -F 32 "$efiPart"
mkfs.ext4 -F "$rootPart"

mount "$rootPart" /mnt
mount --mkdir "$efiPart" /mnt/boot

echo "Checking internet capabilities . . ."
if ! ping -c 5 ping.archlinux.org >/dev/null 2>&1; then
    echo "You don't have a stable internet connection!"
    sleep 1.6
    exit
fi

pacstrap -K /mnt sudo openssh networkmanager linux base base-devel linux-firmware grub git efibootmgr os-prober fish starship fastfetch sddm plasma plasma-workspace fastfetch konsole dolphin discover wget curl nvim vim micro nano kate firefox
genfstab -U /mnt >> /mnt/etc/fstab
    arch-chroot -S /mnt <<EOF
hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "What would you like your hostname to be? (like archlinux or mycomputer) It can't have spaces or special characters!"
read -rp "HOSTNAME: " hostChoice
echo "$hostChoice" > /etc/hostname

mkinitcpio -P

echo "Choose your root password!"
read -rp "PASS: " rootPass
printf 'root:%s\n' "$rootPass" | chpasswd

if uname -a | grep -q "x86_64"; then
	grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=GRUB
elif uname -a | grep -q "aarch64"; then
	grub-install --target=aarch64-efi --efi-directory=/boot/ --bootloader-id=GRUB
fi

grub-mkconfig -o /boot/grub/grub.cfg

cat <<GRUBEOF > /etc/default/grub
# GRUB boot loader configuration

GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Arch"
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=7"
GRUB_CMDLINE_LINUX=""

# Preload both GPT and MBR modules so that they are not missed
GRUB_PRELOAD_MODULES="part_gpt part_msdos"

# Uncomment to enable booting from LUKS encrypted devices
#GRUB_ENABLE_CRYPTODISK=y

# Set to 'countdown' or 'hidden' to change timeout behavior,
# press ESC key to display menu.
GRUB_TIMEOUT_STYLE=menu

# Uncomment to use basic console
GRUB_TERMINAL_INPUT=menu

# Uncomment to disable graphical terminal
#GRUB_TERMINAL_OUTPUT=console

# The resolution used on graphical terminal
# note that you can use only modes which your graphic card supports via VBE
# you can see them in real GRUB with the command `videoinfo'
GRUB_GFXMODE=auto

# Uncomment to allow the kernel use the same resolution used by grub
GRUB_GFXPAYLOAD_LINUX=keep

# Uncomment if you want GRUB to pass to the Linux kernel the old parameter
# format "root=/dev/xxx" instead of "root=/dev/disk/by-uuid/xxx"
#GRUB_DISABLE_LINUX_UUID=true

# Uncomment to disable generation of recovery mode menu entries
GRUB_DISABLE_RECOVERY=true

# Uncomment and set to the desired menu colors.  Used by normal and wallpaper
# modes only.  Entries specified as foreground/background.
#GRUB_COLOR_NORMAL="light-blue/black"
#GRUB_COLOR_HIGHLIGHT="light-cyan/blue"

# Uncomment one of them for the gfx desired, a image background or a gfxtheme
#GRUB_BACKGROUND="/path/to/wallpaper"
#GRUB_THEME="/path/to/gfxtheme"

# Uncomment to get a beep at GRUB start
#GRUB_INIT_TUNE="480 440 1"

# Uncomment to make GRUB remember the last selection. This requires
# setting 'GRUB_DEFAULT=saved' above.
#GRUB_SAVEDEFAULT=true

# Uncomment to disable submenus in boot menu
#GRUB_DISABLE_SUBMENU=y

# Probing for other operating systems is disabled for security reasons. Read
# documentation on GRUB_DISABLE_OS_PROBER, if still want to enable this
# functionality install os-prober and uncomment to detect and include other
# operating systems.
GRUB_DISABLE_OS_PROBER=false
GRUBEOF
grub-mkconfig -o /boot/grub/grub.cfg


echo "What would you like your username to be?"
read -rp "USERNAME: " userChoice
useradd -mG wheel "$userChoice"

echo "Choose a password for your user!"
read -rp "PASSWORD: " userPass
printf '%s:%s\n' "$userChoice" "$userPass" | chpasswd

echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers
systemctl enable NetworkManager
systemctl enable sddm
EOF