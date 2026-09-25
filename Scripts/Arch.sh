#!/bin/bash

set -e

# Make sure you're running from the Arch ISO
if [[ "$HOSTNAME" != "archiso" ]]; then
    clear
    printf "You are not in an Arch ISO environment!\n"
    sleep 1.6
    exit 1
fi

clear
echo "A Simpler Archinstall"
sleep 1
clear

printf "Hello! This is a script to install Arch Linux.\n"
printf "Please select the drive/partition you want to install on.\n\n"

sleep 2
lsblk

read -rp "Tell me your install victim (for example, /dev/sda or /dev/nvme0n1): " diskChoice

printf "\n%s selected!\n" "$diskChoice"
sleep 2
clear

PS3=$'Would you like to continue? This will wipe your data to install Arch!\nChoose an option: '

options=("Yes" "No")

select opt in "${options[@]}"; do
    case "$opt" in

        "Yes")
            break
            ;;

        "No")
            exit
            ;;

        *)
            echo "Invalid option: $REPLY"
            sleep 1.6
            ;;

    esac
done

echo
echo "Creating EFI and root partitions..."

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
lsblk -f "$diskChoice"

echo "Give me the EFI partition."
echo "It should be something like /dev/sda1 or /dev/nvme0n1p1."
echo "It is the 1GB partition."

read -rp "EFI PARTITION: " efiPart

clear
lsblk -f "$diskChoice"

echo "Give me the root partition."
echo "It should be something like /dev/sda2 or /dev/nvme0n1p2."

read -rp "ROOT PARTITION: " rootPart

echo
echo "Formatting EFI partition..."
mkfs.fat -F 32 "$efiPart"

echo "Formatting root partition..."
mkfs.ext4 -F "$rootPart"

echo "Mounting partitions..."

mount "$rootPart" /mnt
mount --mkdir "$efiPart" /mnt/boot

echo "Checking internet capabilities..."

if ! ping -c 5 ping.archlinux.org >/dev/null 2>&1; then
    echo "You don't have a stable internet connection!"
    sleep 1.6
    exit 1
fi

echo "Internet connection looks good!"

echo "Installing Arch Linux..."

pacstrap -K /mnt sudo openssh networkmanager linux base base-devel linux-firmware grub git efibootmgr os-prober fish starship fastfetch sddm plasma plasma-workspace fastfetch konsole dolphin discover wget curl nvim vim micro nano kate firefox

echo "Generating fstab..."

genfstab -U /mnt >> /mnt/etc/fstab

cat > /mnt/root/chroot-install.sh <<'CHROOT_SCRIPT'
#!/bin/bash

set -e

echo
echo "Entering installed Arch Linux environment..."
echo

hwclock --systohc

sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen

locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "What would you like your hostname to be?"
echo "For example: archlinux or mycomputer"
echo "It cannot contain spaces or special characters."

read -rp "HOSTNAME: " hostChoice

echo "$hostChoice" > /etc/hostname

echo "Choose your root password."

read -rsp "PASSWORD: " rootPass

printf 'root:%s\n' "$rootPass" | chpasswd

unset rootPass


echo "Generating initramfs..."

mkinitcpio -P

echo
echo "Installing GRUB..."

if [[ "$(uname -m)" == "x86_64" ]]; then

    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

elif [[ "$(uname -m)" == "aarch64" ]]; then

    grub-install --target=aarch64-efi --efi-directory=/boot --bootloader-id=GRUB

else

    echo "Unsupported architecture: $(uname -m)"
    exit 1

fi

cat > /etc/default/grub <<'GRUBEOF'
# GRUB boot loader configuration

GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Arch"

GRUB_CMDLINE_LINUX_DEFAULT="loglevel=7"
GRUB_CMDLINE_LINUX=""

GRUB_PRELOAD_MODULES="part_gpt part_msdos"

# GRUB_ENABLE_CRYPTODISK=y

GRUB_TIMEOUT_STYLE=menu

GRUB_TERMINAL_INPUT=console

# GRUB_TERMINAL_OUTPUT=console

GRUB_GFXMODE=auto

GRUB_GFXPAYLOAD_LINUX=keep

# GRUB_DISABLE_LINUX_UUID=true

GRUB_DISABLE_RECOVERY=true

# GRUB_COLOR_NORMAL="light-blue/black"
# GRUB_COLOR_HIGHLIGHT="light-cyan/blue"

# GRUB_BACKGROUND="/path/to/wallpaper"
# GRUB_THEME="/path/to/gfxtheme"

# GRUB_INIT_TUNE="480 440 1"

# GRUB_DEFAULT=saved
# GRUB_SAVEDEFAULT=true

# GRUB_DISABLE_SUBMENU=y

GRUB_DISABLE_OS_PROBER=false
GRUBEOF

echo "Generating GRUB configuration..."

grub-mkconfig -o /boot/grub/grub.cfg

echo "What would you like your username to be?"

read -rp "USERNAME: " userChoice

useradd -m -G wheel "$userChoice"

echo "Choose a password for your user."

read -rsp "PASSWORD: " userPass

printf '%s:%s\n' "$userChoice" "$userPass" | chpasswd

unset userPass

echo "Configuring sudo..."

echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

echo "Enabling services..."

systemctl enable NetworkManager
systemctl enable sddm


echo
echo "========================================"
echo " Arch installation configuration done!"
echo "========================================"
echo

CHROOT_SCRIPT

chmod +x /mnt/root/chroot-install.sh

echo
echo "Running post-install configuration..."
echo

arch-chroot /mnt /root/chroot-install.sh

rm /mnt/root/chroot-install.sh

echo
echo "========================================"
echo " Installation complete!"
echo "========================================"
echo
echo "You can now reboot into your new Arch installation."
echo

sleep 3