#!/bin/bash

###################################################
# E-ink Dotfiles Installation Script (Enhanced)
# - Custom hyprland.conf with eink dots
# - Added NVIDIA, Network & Bluetooth support
# - PipeWire audio stack with WirePlumber
# - Custom frosted waybar with black icons
# - Increased gap between waybar and windows
# - Colemak DH layout
###################################################

set -e

# Colors
RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'
CYAN='\033[36m'
BLUE='\033[34m'

# Script Variables
BACKUP_DIR="$HOME/.config/cfg_backups/$(date +%Y%m%d_%H%M%S)"
CONFIG_DIR="$HOME/.config"
TEMP_DIR="/tmp/eink-dots-$$"
EINK_REPO_URL="https://gitlab.com/dotfiles_hypr/eink.git"
CUSTOM_REPO_URL="https://github.com/Hoodrich-Pablo-Juan/dots3.git"
NVIDIA_INSTALL="false" # Flag to track NVIDIA installation

# --- Messaging Functions ---
print_msg() { echo -e "${CYAN}[E-ink]${RC} $1"; }
print_success() { echo -e "${GREEN}[✓]${RC} $1"; }
print_error() { echo -e "${RED}[✗]${RC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${RC} $1"; }
print_hardware() { echo -e "${BLUE}[HARDWARE]${RC} $1"; }
print_nvidia() { echo -e "${BLUE}[NVIDIA]${RC} $1"; }
print_audio() { echo -e "${BLUE}[AUDIO]${RC} $1"; }

check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "This script should not be run as root. Sudo will be used where needed."
        exit 1
    fi
}

backup_config() {
    local config_name=$1
    local config_path="$CONFIG_DIR/$config_name"
    
    if [ -e "$config_path" ]; then
        print_msg "Backing up existing '$config_name' config..."
        mkdir -p "$BACKUP_DIR"
        mv "$config_path" "$BACKUP_DIR/"
        print_success "Backed up '$config_name' to $BACKUP_DIR"
    fi
}

install_chaotic_aur() {
    print_msg "Setting up Chaotic-AUR repository..."
    if grep -q "\[chaotic-aur\]" /etc/pacman.conf 2>/dev/null; then
        print_success "Chaotic-AUR is already configured."
        sudo pacman -Sy
        return
    fi
    
    print_hardware "Importing Chaotic-AUR keys..."
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    
    print_hardware "Adding Chaotic-AUR to pacman.conf..."
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf
    
    sudo pacman -Sy
    print_success "Chaotic-AUR setup complete."
}

install_hardware_support() {
    print_hardware "Installing support for networking and Bluetooth..."
    local hardware_pkgs=(
        networkmanager        # For WiFi, Ethernet, etc.
        network-manager-applet  # Systray applet for NetworkManager
        nm-connection-editor    # GUI for NetworkManager connections
        bluez                 # Bluetooth protocol stack
        bluez-utils           # Bluetooth utilities
        blueman               # GTK Bluetooth manager
    )
    sudo pacman -S --needed --noconfirm "${hardware_pkgs[@]}"
    
    print_hardware "Enabling system services..."
    sudo systemctl enable NetworkManager.service
    sudo systemctl enable bluetooth.service
    print_success "NetworkManager and Bluetooth services enabled."

    echo ""
    read -p "$(echo -e ${YELLOW}"[?] Do you want to install NVIDIA drivers for Hyprland? (y/N): "${RC})" -n 1 -r REPLY
    echo
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        NVIDIA_INSTALL="true"
        print_nvidia "Proceeding with NVIDIA driver installation."
        local nvidia_pkgs=(
            nvidia-dkms            # NVIDIA driver with DKMS for kernel compatibility
            nvidia-utils           # NVIDIA driver utilities
            lib32-nvidia-utils     # 32-bit NVIDIA utilities (for gaming)
            nvidia-settings        # NVIDIA settings GUI
        )
        sudo pacman -S --needed --noconfirm "${nvidia_pkgs[@]}"

        print_nvidia "Configuring kernel modules for NVIDIA..."
        if ! grep -q "nvidia" /etc/mkinitcpio.conf; then
            sudo sed -i 's/^MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
            print_nvidia "Added NVIDIA modules to mkinitcpio.conf."
        else
            print_nvidia "NVIDIA modules already seem to be in mkinitcpio.conf."
        fi
        
        print_nvidia "Creating modprobe configuration for KMS..."
        echo "options nvidia_drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf
        
        print_nvidia "Rebuilding initramfs (this may take a moment)..."
        sudo mkinitcpio -P
        
        print_success "NVIDIA base configuration complete."
    else
        print_msg "Skipping NVIDIA driver installation."
    fi
}

remove_conflicting_audio() {
    print_audio "Checking for conflicting audio packages..."
    local pulseaudio_pkgs=(pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-jack)
    local installed_conflicts=()
    
    for pkg in "${pulseaudio_pkgs[@]}"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            installed_conflicts+=("$pkg")
        fi
    done
    
    if [ ${#installed_conflicts[@]} -gt 0 ]; then
        print_audio "Removing conflicting PulseAudio packages: ${installed_conflicts[*]}"
        sudo pacman -Rns --noconfirm "${installed_conflicts[@]}" 2>/dev/null || true
    fi
}

install_packages() {
    print_msg "Installing core packages..."
    
    # First remove any conflicting audio packages
    remove_conflicting_audio
    
    local packages=(
        # Core system
        base-devel git curl wget
        
        # Core Hyprland
        hyprland hyprpaper hyprpicker xdg-desktop-portal-hyprland
        
        # Wayland tools
        waybar wofi swaybg grim slurp wf-recorder wl-clipboard
        
        # PipeWire audio system (modern replacement for PulseAudio)
        pipewire
        pipewire-alsa
        pipewire-audio
        pipewire-pulse
        pipewire-jack
        wireplumber
        pavucontrol
        
        # Notification daemon
        dunst libnotify
        
        # Terminals & editor
        alacritty helix
        
        # Apps
        nautilus mpv htop neofetch
        
        # Utils
        brightnessctl pamixer playerctl polkit-gnome
        
        # Fonts
        ttf-jetbrains-mono-nerd ttf-font-awesome ttf-opensans noto-fonts-emoji
        
        # Wayland support
        qt5-wayland qt6-wayland
    )
    
    sudo pacman -S --needed --noconfirm "${packages[@]}"
    
    # Try to install ghostty if available
    sudo pacman -S --needed --noconfirm ghostty 2>/dev/null || print_warning "Ghostty not in official repos, will try AUR later."
    
    print_success "Core packages installed."
    
    # Enable and start PipeWire services for the user
    print_audio "Configuring PipeWire audio system..."
    systemctl --user enable pipewire.service
    systemctl --user enable pipewire-pulse.service
    systemctl --user enable wireplumber.service
    
    # Start services immediately if not in chroot
    if [ -z "$CHROOT" ]; then
        systemctl --user start pipewire.service
        systemctl --user start pipewire-pulse.service
        systemctl --user start wireplumber.service
    fi
    
    print_success "PipeWire and WirePlumber configured for user session."
}

install_aur_packages() {
    print_msg "Installing AUR packages with yay..."
    
    if ! command -v yay &> /dev/null; then
        print_msg "AUR helper 'yay' not found. Installing..."
        cd /tmp
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd ..
        rm -rf yay
    fi
    
    local aur_packages=(
        zen-browser-bin
        localsend-bin
    )
    
    # Try ghostty from AUR if it wasn't installed from other repos
    if ! command -v ghostty &> /dev/null; then
        aur_packages+=(ghostty)
    fi
    
    if [ ${#aur_packages[@]} -gt 0 ]; then
        for pkg in "${aur_packages[@]}"; do
            yay -S --needed --noconfirm "$pkg" || print_warning "Failed to install '$pkg' from AUR."
        done
        print_success "AUR packages installed."
    else
        print_msg "No additional AUR packages to install."
    fi
}

clone_dotfiles() {
    print_msg "Cloning dotfiles repositories..."
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    # Clone the e-ink repository
    if git clone "$EINK_REPO_URL" "$TEMP_DIR/eink-dots"; then
        print_success "E-ink dotfiles cloned successfully."
    else
        print_error "Failed to clone e-ink dotfiles repository from $EINK_REPO_URL"
        exit 1
    fi
    
    # Clone the custom repository
    if git clone "$CUSTOM_REPO_URL" "$TEMP_DIR/custom-dots"; then
        print_success "Custom dotfiles cloned successfully."
    else
        print_error "Failed to clone custom dotfiles repository from $CUSTOM_REPO_URL"
        exit 1
    fi
}

deploy_configs() {
    print_msg "Deploying configuration files..."
    
    local eink_root="$TEMP_DIR/eink-dots"
    local custom_root="$TEMP_DIR/custom-dots"
    
    # Determine if configs are in a 'config' subdirectory or at the root
    local eink_config_dir="$eink_root/config"
    if [ ! -d "$eink_config_dir" ]; then
        eink_config_dir="$eink_root"
    fi

    # List of configs to deploy from e-ink repo
    local eink_configs=(
        "wofi" "alacritty" "ghostty" "helix" "mpv" "dunst"
    )
    
    # Backup existing configs first
    for cfg in "${eink_configs[@]}" "waybar" "hypr" "wallpapers"; do
        backup_config "$cfg"
    done
    
    # Deploy configs from e-ink repo
    for cfg in "${eink_configs[@]}"; do
        if [ -d "$eink_config_dir/$cfg" ]; then
            print_msg "Deploying '$cfg' config from e-ink repo..."
            cp -r "$eink_config_dir/$cfg" "$CONFIG_DIR/"
        else
            print_warning "Config for '$cfg' not found in e-ink repository, skipping."
        fi
    done
    
    # Deploy custom waybar config from our repo
    print_msg "Deploying custom frosted waybar configuration..."
    mkdir -p "$CONFIG_DIR/waybar"
    if [ -f "$custom_root/waybar/config.jsonc" ] && [ -f "$custom_root/waybar/style.css" ]; then
        cp "$custom_root/waybar/config.jsonc" "$CONFIG_DIR/waybar/"
        cp "$custom_root/waybar/style.css" "$CONFIG_DIR/waybar/"
        print_success "Custom frosted waybar configuration deployed."
    else
        print_error "Custom waybar configuration files not found in repository!"
    fi
    
    # Deploy custom hyprland config from our repo
    print_msg "Installing custom Hyprland config with Colemak DH..."
    mkdir -p "$CONFIG_DIR/hypr"
    if [ -f "$custom_root/hypr/hyprland.conf" ]; then
        cp "$custom_root/hypr/hyprland.conf" "$CONFIG_DIR/hypr/"
        print_success "Custom Hyprland configuration deployed."
    else
        print_error "Custom Hyprland configuration not found in repository!"
    fi
    
    # Copy scripts for hyprland from e-ink repo if they exist
    if [ -d "$eink_config_dir/hypr/scripts" ]; then
        cp -r "$eink_config_dir/hypr/scripts" "$CONFIG_DIR/hypr/"
        chmod +x "$CONFIG_DIR/hypr/scripts/"*.sh 2>/dev/null || true
    fi
    
    # Copy the screen recorder script from our repo if it exists
    if [ -f "$custom_root/hypr/scripts/wf-toggle-recorder.sh" ]; then
        mkdir -p "$CONFIG_DIR/hypr/scripts"
        cp "$custom_root/hypr/scripts/wf-toggle-recorder.sh" "$CONFIG_DIR/hypr/scripts/"
        chmod +x "$CONFIG_DIR/hypr/scripts/wf-toggle-recorder.sh"
        print_success "Screen recorder script deployed."
    fi
    
    print_success "All configs deployed successfully."
}

setup_wallpapers() {
    print_msg "Setting up wallpapers..."
    mkdir -p "$CONFIG_DIR/wallpapers"
    
    local wallpaper_source
    if [ -d "$TEMP_DIR/eink-dots/wallpapers" ]; then
        wallpaper_source="$TEMP_DIR/eink-dots/wallpapers"
    elif [ -d "$TEMP_DIR/eink-dots/config/wallpapers" ]; then
        wallpaper_source="$TEMP_DIR/eink-dots/config/wallpapers"
    fi
    
    if [ -n "$wallpaper_source" ]; then
        cp -r "$wallpaper_source/"* "$CONFIG_DIR/wallpapers/" 2>/dev/null || true
    fi
    
    if [ -f "$CONFIG_DIR/wallpapers/eink.jpg" ]; then
        print_success "Default wallpaper 'eink.jpg' is ready."
    else
        print_warning "Default wallpaper 'eink.jpg' not found."
        # Fallback: symlink the first found image to eink.jpg
        local first_wallpaper=$(find "$CONFIG_DIR/wallpapers" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -print -quit)
        if [ -n "$first_wallpaper" ]; then
            ln -sf "$(basename "$first_wallpaper")" "$CONFIG_DIR/wallpapers/eink.jpg"
            print_msg "Symlinked '$(basename "$first_wallpaper")' to 'eink.jpg' as a fallback."
        else
            print_error "No wallpapers found! You must add one to ~/.config/wallpapers/eink.jpg for swaybg to work."
        fi
    fi
}

verify_audio_setup() {
    print_audio "Verifying audio setup..."
    
    # Check if PipeWire is running
    if systemctl --user is-active pipewire.service &>/dev/null; then
        print_success "PipeWire service is active."
    else
        print_warning "PipeWire service is not active. It will start after reboot."
    fi
    
    # Check if WirePlumber is running
    if systemctl --user is-active wireplumber.service &>/dev/null; then
        print_success "WirePlumber service is active."
    else
        print_warning "WirePlumber service is not active. It will start after reboot."
    fi
}

cleanup() {
    print_msg "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
}

print_post_install() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RC}"
    echo -e "${CYAN}║                   POST-INSTALLATION INFO                      ║${RC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RC}"
    echo ""
    print_success "Installation complete!"
    
    if [ -d "$BACKUP_DIR" ]; then
        print_msg "Your old configs were backed up to:"
        echo "  → $BACKUP_DIR"
    fi
    
    echo ""
    echo -e "${GREEN}Features Installed:${RC}"
    echo "  ✓ Hyprland with Colemak DH keyboard layout"
    echo "  ✓ Frosted waybar with black icons and blur effect"
    echo "  ✓ PipeWire audio system with WirePlumber"
    echo "  ✓ NetworkManager for network management"
    echo "  ✓ Bluetooth support with Blueman"
    echo "  ✓ Gap between waybar and windows: 28 pixels"
    
    if [ "$NVIDIA_INSTALL" = "true" ]; then
        echo ""
        echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${RC}"
        echo -e "${YELLOW}║                      NVIDIA SETUP                             ║${RC}"
        echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${RC}"
        print_nvidia "NVIDIA drivers installed and configured."
        print_warning "You may need to add 'nvidia_drm.modeset=1' to your bootloader."
    fi
    
    echo ""
    echo -e "${CYAN}Keybindings:${RC}"
    echo "  Super+T        → Terminal (Alacritty)"
    echo "  Super+E        → File Manager (Nautilus)"
    echo "  Super+F        → Browser (Zen)"
    echo "  Super+V        → Volume Control (PavuControl)"
    echo "  Super+A        → Application Launcher (Wofi)"
    echo "  Super+Q        → Close Window"
    echo "  Super+W        → Toggle Floating"
    echo "  Super+P        → Screenshot (selection)"
    echo "  Print          → Screenshot (full screen)"
    
    echo ""
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${RC}"
    echo -e "${YELLOW}║                    IMPORTANT NEXT STEPS                       ║${RC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${RC}"
    echo ""
    print_warning "1. REBOOT YOUR SYSTEM to apply all changes"
    print_warning "2. After reboot, log into a TTY (Ctrl+Alt+F2)"
    print_warning "3. Type 'Hyprland' and press Enter to start the session"
    echo ""
}

main() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║          E-ink Dotfiles Installer (Enhanced)                ║"
    echo "║                                                              ║"
    echo "║  • Colemak DH Layout                                        ║"
    echo "║  • Frosted Waybar with Black Icons                          ║"
    echo "║  • PipeWire Audio Stack                                     ║"
    echo "║  • NVIDIA Support (Optional)                                ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${RC}"
    echo ""
    
    check_root
    trap cleanup EXIT
    
    # Main installation flow
    install_chaotic_aur
    install_hardware_support
    install_packages
    install_aur_packages
    clone_dotfiles
    deploy_configs
    setup_wallpapers
    verify_audio_setup
    
    # Print post-installation information
    print_post_install
}

# Run the main function
main "$@"
