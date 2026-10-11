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

pacman-key --init
pacstrap -K /mnt sudo \
                 openssh \
                 networkmanager \
                 linux \
                 base-devel \
                 linux \
                 linux-firmware \
                 grub \
                 git \
                 efibootmgr \
                 os-prober \
                 starship \
                 fish \
                 fastfetch \
                 vlc \
                 usbutils \
                 vim \
                 nano \
                 micro \
                 nvim \
                 eza \
                 btop \
                 htop \
                 wget \
                 curl \

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

mkdir -p "/home/$userChoice/.config/fish"
mkdir -p "/home/$userChoice/.config/fastfetch"
mkdir -p "/home/$userChoice/.config/starship"
cat <<'FISH' > "/home/$userChoice/.config/fish/config.fish"
function fish_greeting
    fastfetch
end

# Format man pages
set -x MANROFFOPT "-c"
set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"

# Set settings for https://github.com/franciscolourenco/done
set -U __done_min_cmd_duration 10000
set -U __done_notification_urgency_level low

## Environment setup
# Apply .profile: use this to put fish compatible .profile stuff in
if test -f ~/.fish_profile
  source ~/.fish_profile
end

# Append common directories for executable files to /home/eric/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/bin:/var/lib/flatpak/exports/bin:/usr/lib/jvm/default/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl:/usr/lib/rustup/bin
fish_add_path ~/.local/bin ~/.cargo/bin ~/Applications/depot_tools

## Functions
# Functions needed for !! and !$ https://github.com/oh-my-fish/plugin-bang-bang
function __history_previous_command
  switch (commandline -t)
  case "!"
    commandline -t [1]; commandline -f repaint
  case "*"
    commandline -i !
  end
end

function __history_previous_command_arguments
  switch (commandline -t)
  case "!"
    commandline -t ""
    commandline -f history-token-search-backward
  case "*"
    commandline -i '$'
  end
end

if [ "" = fish_vi_key_bindings ];
  bind -Minsert ! __history_previous_command
  bind -Minsert '$' __history_previous_command_arguments
else
  bind ! __history_previous_command
  bind '$' __history_previous_command_arguments
end

# Fish command history
function history
    builtin history --show-time='%F %T ' 
end

function backup --argument filename
    cp  .bak
end

# Copy DIR1 DIR2
function copy
    set count (count  | tr -d \n)
    if test "" = 2; and test -d "[1]"
        set from (echo [1] | trim-right /)
        set to (echo [2])
        command cp -r  
    else
        command cp 
    end
end

## Useful aliases
# Replace ls with eza
alias ls='eza -al --color=always --group-directories-first --icons=always' # preferred listing
alias la='eza -a --color=always --group-directories-first --icons=always'  # all files and dirs
alias ll='eza -l --color=always --group-directories-first --icons=always'  # long format
alias lt='eza -aT --color=always --group-directories-first --icons=always' # tree listing
alias l.="eza -a | grep -e '^\.'"                                     # show only dotfiles

# Common use
alias grubup="sudo grub-mkconfig -o /boot/grub/grub.cfg"
alias fixpacman="sudo rm /var/lib/pacman/db.lck"
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias wget='wget -c '
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'

alias apt='sudo apt'

alias jctl="journalctl -p 3 -xb"

alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"
alias dnf='sudo dnf'
alias nala='sudo nala'
alias pacman='sudo pacman'
alias vim='nvim'
set -Ux STARSHIP_CONFIG "/home/$USER/.config/starship/starship.toml"
alias yt-dlp='yt-dlp -x --audio-format mp3 --audio-quality 2 --embed-metadata --embed-thumbnail -o "%(title)s.%(ext)s"'
starship init fish | source
FISH

cat <<FAST > "/home/$userChoice/.config/fastfetch/config.jsonc"
{
  "": "https://github.com/fastfetch-cli/fastfetch/raw/master/doc/json_schema.json",
  "modules": [
    "title",
        "separator",
        "os",
        "uptime",
        "host",
        "disk",
        "memory",
        "packages",
        "kernel",
        "terminal",
        "cpu",
        "gpu",
        "localip",
        "battery",
        "break",
        "colors"
  ]
}
FAST

cat <<'STAR' > "/home/$userChoice/.config/starship/starship.toml"
format = """
$username$hostname$directory$git_branch$git_status$fill$python$lua$nodejs$golang$haskell$rust$package$cmd_duration
$character"""
add_newline = true
palette = 'nord'

[username]
show_always = true
style_user = 'bold white'
format = '[$user]($style)'

[hostname]
ssh_only = false
style = 'bold white'
format = '[@$hostname]($style) '


[character]
success_symbol = '[❯](bold green)'
error_symbol = '[❯](bold red)'


[directory]
style = 'bold fg:dark_blue'
format = '[$path]($style)'
truncation_length = 3
truncation_symbol = '…/'
truncate_to_repo = false

#[directory.substitutions]
#'Documents' = '󰈙'
#'Downloads' = ' '
#'Music' = ' '
#'Pictures' = ' '

[git_branch]
style = 'fg:green'
symbol = ' '
format = '[$symbol$branch]($style) '

[git_status]
style = 'fg:green'
format = '([]() )'

[fill]
symbol = ' '

[python]
style = 'teal'
symbol = ' '
format = '[( )(\(\) )]()'
pyenv_version_name = true
pyenv_prefix = ''

[lua]
symbol = ' '

[nodejs]
style = 'blue'
symbol = ' '

[golang]
style = 'blue'
symbol = ' '

[haskell]
style = 'blue'
symbol = ' '

[rust]
style = 'orange'
symbol = ' '

[ruby]
style = 'blue'
symbol = ' '

[package]
symbol = '󰏗 '

[aws]
symbol = ' '
style = 'yellow'
format = '[( )(\[\] )]()'

[docker_context]
symbol = ' '
style = 'fg:#06969A'
format = '[]() '
detect_files = ['docker-compose.yml', 'docker-compose.yaml', 'Dockerfile']
detect_extensions = ['Dockerfile']

[jobs]
symbol = ' '
style = 'red'
number_threshold = 1
format = '[]()'

[cmd_duration]
min_time = 500
style = 'fg:gray'
format = '[]()'

[palettes.nord]
dark_blue = '#5E81AC'
blue = '#81A1C1'
teal = '#88C0D0'
red = '#BF616A'
orange = '#D08770'
green = '#A3BE8C'
yellow = '#EBCB8B'
purple = '#B48EAD'
gray = '#434C5E'
black = '#2E3440'
white='#D8DEE9'

[palettes.onedark]
dark_blue='#61afef'
blue='#56b6c2'
red='#e06c75'
green='#98c379'
purple='#c678dd'
cyan='#56b6c2'
orange='#be5046'
yellow='#e5c07b'
gray='#828997'
white ='#abb2bf'
black='#2c323c'
STAR

cat <<'BASH' > "/home/$userChoice/.bashrc"
fastfetch
## Useful aliases
# Replace ls with eza
alias ls='eza -al --color=always --group-directories-first --icons=always' # preferred listing
alias la='eza -a --color=always --group-directories-first --icons=always'  # all files and dirs
alias ll='eza -l --color=always --group-directories-first --icons=always'  # long format
alias lt='eza -aT --color=always --group-directories-first --icons=always' # tree listing
alias l.="eza -a | grep -e '^\.'"                                     # show only dotfiles

# Common use
alias grubup="sudo grub-mkconfig -o /boot/grub/grub.cfg"
alias fixpacman="sudo rm /var/lib/pacman/db.lck"
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias wget='wget -c '
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'

alias apt='sudo apt'

alias cleanup='sudo pacman -Rns (pacman -Qtdq)'

alias jctl="journalctl -p 3 -xb"

alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"
alias dnf='sudo dnf'
alias nala='sudo nala'
alias pacman='sudo pacman'
alias vim='nvim'
export STARSHIP_CONFIG="/home/$USER/.config/starship/starship.toml"
eval "$(starship init bash)"
BASH

rm "/home/$userChoice/.vimrc"
rm /root/.vimrc
rm /root/.config/nvim/init.vim
rm "/home/$userChoice/.config/nvim/init.vim"
mkdir -p /root/.config/nvim/
mkdir -p "/home/$userChoice/.config/nvim/"
tee "/home/$userChoice/.vimrc" "/home/$userChoice/.config/nvim/init.vim" /root/.vimrc /root/.config/nvim/init.vim > /dev/null <<VIM
set number
syntax on

set tabstop=4
set shiftwidth=4
set expandtab
set mouse=a

" Keybinds
map <F2> :wq<CR>
map <F5> :q!<CR> 
VIM

PS3="Which would you like to install, KDE, or GNOME? GNOME is more of a macOS style, while KDE looks more like Windows.
"
options=("KDE" "GNOME" "Neither")
select opt in "${options[@]}"
do
    case $opt in
        "GNOME")
            pacman -S gnome gdm ptyxis eog --noconfirm
            systemctl enable gdm
            ;;
        "KDE")
            pacman -S plasma sddm discover kate konsole dolphin libcec plasma-bigscreen --noconfirm
            systemctl enable sddm
            ;;
        "Neither")
            break
            ;;
        *)
            echo "Invalid Option: $REPLY"
            ;;
        esac
    done


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
