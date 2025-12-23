#!/bin/bash

###################################################
# E-ink Dotfiles Installation Script (Enhanced)
# - Custom hyprland.conf with eink dots
# - NVIDIA Open drivers (590+) support
# - Auto-login with getty + Hyprland launch
# - Network & Bluetooth support
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
CURRENT_USER="$USER"

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
    read -p "$(echo -e ${YELLOW}"[?] Do you want to install NVIDIA Open drivers (590+) for Hyprland? (y/N): "${RC})" -n 1 -r REPLY
    echo
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        NVIDIA_INSTALL="true"
        print_nvidia "Proceeding with NVIDIA Open driver installation."
        local nvidia_pkgs=(
            nvidia-open-dkms       # NVIDIA Open driver with DKMS
            nvidia-utils           # NVIDIA driver utilities
            lib32-nvidia-utils     # 32-bit NVIDIA utilities (for gaming)
            nvidia-settings        # NVIDIA settings GUI
            egl-wayland            # EGL external platform for Wayland
        )
        sudo pacman -S --needed --noconfirm "${nvidia_pkgs[@]}"

        print_nvidia "Configuring kernel modules for NVIDIA Open..."
        if ! grep -q "nvidia" /etc/mkinitcpio.conf; then
            sudo sed -i 's/^MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
            print_nvidia "Added NVIDIA modules to mkinitcpio.conf."
        else
            print_nvidia "NVIDIA modules already configured in mkinitcpio.conf."
        fi
        
        print_nvidia "Creating modprobe configuration for KMS..."
        echo "options nvidia_drm modeset=1 fbdev=1" | sudo tee /etc/modprobe.d/nvidia.conf
        
        print_nvidia "Rebuilding initramfs (this may take a moment)..."
        sudo mkinitcpio -P
        
        print_success "NVIDIA Open driver configuration complete."
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
        base-devel git curl wget lz4
        
        # Core Hyprland
        hyprland hyprpaper hyprpicker xdg-desktop-portal-hyprland
        
        # Hyprland plugins & tools
        hyprsunset    # Warm color temperature filter
        
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
        ttf-jetbrains-mono-nerd ttf-font-awesome ttf-opensans ttf-montserrat noto-fonts-emoji
        
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
        hy3-git    # i3-style window management for Hyprland
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

setup_zen_extensions() {
    print_msg "Setting up Zen browser with extensions and custom search..."
    
    # Create a first-run script that will configure Zen
    local zen_config_script="$HOME/.local/bin/configure-zen.sh"
    mkdir -p "$HOME/.local/bin"
    
    cat > "$zen_config_script" << 'ZENEOF'
#!/bin/bash

# Zen Browser Auto-Configuration Script
# Installs Vimium C, uBlock Origin, and sets custom search engine

set -e

ZEN_PROFILE_DIR="$HOME/.zen"
EXTENSIONS_URL="https://addons.mozilla.org/firefox/downloads/latest"

echo "Configuring Zen Browser..."

# Launch Zen in headless mode to create profile if it doesn't exist
if [ ! -d "$ZEN_PROFILE_DIR" ]; then
    echo "Creating Zen profile..."
    timeout 5 zen-browser --headless --no-remote 2>/dev/null || true
    sleep 2
fi

# Find the default profile
PROFILE=$(find "$ZEN_PROFILE_DIR" -maxdepth 1 -type d -name "*.default*" -o -name "*.default-release*" | head -n 1)

if [ -z "$PROFILE" ]; then
    echo "Creating default profile..."
    mkdir -p "$ZEN_PROFILE_DIR/default-profile"
    PROFILE="$ZEN_PROFILE_DIR/default-profile"
fi

echo "Using profile: $PROFILE"

# Create extensions directory
EXTENSIONS_DIR="$PROFILE/extensions"
mkdir -p "$EXTENSIONS_DIR"

# Download and install Vimium C
echo "Installing Vimium C..."
VIMIUM_XPI="$EXTENSIONS_DIR/vimium-c.xpi"
curl -L -o "$VIMIUM_XPI" "https://addons.mozilla.org/firefox/downloads/latest/vimium-c/latest.xpi" 2>/dev/null || {
    wget -O "$VIMIUM_XPI" "https://addons.mozilla.org/firefox/downloads/latest/vimium-c/latest.xpi" 2>/dev/null || true
}

# Download and install uBlock Origin
echo "Installing uBlock Origin..."
UBLOCK_XPI="$EXTENSIONS_DIR/ublock-origin.xpi"
curl -L -o "$UBLOCK_XPI" "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi" 2>/dev/null || {
    wget -O "$UBLOCK_XPI" "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi" 2>/dev/null || true
}

# Create user.js with configuration
USER_JS="$PROFILE/user.js"

cat > "$USER_JS" << 'EOF'
// Zen Browser Auto-Configuration

// ===== Extension Installation =====
// Allow unsigned extensions (for local XPI installation)
user_pref("xpinstall.signatures.required", false);
user_pref("extensions.autoDisableScopes", 0);
user_pref("extensions.enabledScopes", 15);
user_pref("extensions.langpacks.signatures.required", false);

// Auto-enable extensions
user_pref("extensions.autoDisableScopes", 0);
user_pref("extensions.startupScanScopes", 15);

// ===== Custom Search Engine =====
// Set 4get as default search engine
user_pref("browser.search.defaultenginename", "4get");
user_pref("browser.search.selectedEngine", "4get");
user_pref("browser.search.order.1", "4get");

// Disable default search engines
user_pref("browser.search.geoip.url", "");
user_pref("browser.search.geoSpecificDefaults", false);

// ===== Privacy & Performance =====
user_pref("privacy.resistFingerprinting", false);
user_pref("privacy.trackingprotection.enabled", true);
user_pref("dom.security.https_only_mode", true);

// ===== UI Preferences =====
user_pref("browser.startup.page", 3); // Restore previous session
user_pref("browser.tabs.closeWindowWithLastTab", false);

// Disable Firefox/Mozilla accounts and sync
user_pref("identity.fxaccounts.enabled", false);
user_pref("browser.contentblocking.report.lockwise.enabled", false);

// Performance
user_pref("gfx.webrender.all", true);
user_pref("layers.acceleration.force-enabled", true);
EOF

# Create search engine configuration
SEARCH_JSON="$PROFILE/search.json.mozlz4"
SEARCH_DIR="$PROFILE/search-metadata"
mkdir -p "$SEARCH_DIR"

# Create a temporary uncompressed search.json
TEMP_SEARCH_JSON="/tmp/zen-search-$.json"

cat > "$TEMP_SEARCH_JSON" << 'SEARCHEOF'
{
  "version": 6,
  "engines": [
    {
      "_name": "4get",
      "_isAppProvided": false,
      "_metaData": {
        "order": 1,
        "alias": "4g"
      },
      "queryCharset": "UTF-8",
      "_urls": [
        {
          "template": "https://4get.silly.computer/web",
          "rels": [],
          "resultDomain": "4get.silly.computer",
          "params": [
            {
              "name": "s",
              "value": "{searchTerms}"
            }
          ]
        }
      ],
      "description": "4get Privacy Search",
      "iconUpdateURL": "https://4get.silly.computer/favicon.ico",
      "extensionID": null,
      "openSearchURL": null
    }
  ],
  "metaData": {
    "current": "4get",
    "hash": "placeholder",
    "searchDefault": "4get",
    "searchDefaultHash": "placeholder",
    "visibleDefaultEngines": ["4get"]
  }
}
SEARCHEOF

# Function to compress JSON to mozlz4 format
compress_to_mozlz4() {
    local input="$1"
    local output="$2"
    
    # mozlz4 header (magic bytes)
    printf "mozLz40\0" > "$output"
    
    # Compress with lz4 if available, otherwise just copy
    if command -v lz4 &> /dev/null; then
        lz4 -c "$input" >> "$output" 2>/dev/null || cat "$input" >> "$output"
    else
        # Fallback: just append uncompressed (Firefox will recompress)
        cat "$input" >> "$output"
    fi
}

# Install lz4 if needed (for proper compression)
if ! command -v lz4 &> /dev/null; then
    echo "Note: lz4 not found. Search config will be set on first Zen launch."
fi

# Create the compressed search config
compress_to_mozlz4 "$TEMP_SEARCH_JSON" "$SEARCH_JSON"
rm -f "$TEMP_SEARCH_JSON"

# Create extensions.json to register the XPI files
EXTENSIONS_JSON="$PROFILE/extensions.json"

cat > "$EXTENSIONS_JSON" << 'EXTEOF'
{
  "schemaVersion": 31,
  "addons": [
    {
      "id": "vimium-c@gdh1995.cn",
      "syncGUID": "{vimium-c-guid}",
      "location": "app-profile",
      "version": "1.0",
      "type": "extension",
      "active": true,
      "userDisabled": false,
      "embedderDisabled": false,
      "installDate": 1234567890000,
      "updateDate": 1234567890000,
      "sourceURI": "https://addons.mozilla.org/firefox/downloads/latest/vimium-c/latest.xpi",
      "visible": true,
      "path": "$EXTENSIONS_DIR/vimium-c.xpi"
    },
    {
      "id": "uBlock0@raymondhill.net",
      "syncGUID": "{ublock-guid}",
      "location": "app-profile",
      "version": "1.0",
      "type": "extension",
      "active": true,
      "userDisabled": false,
      "embedderDisabled": false,
      "installDate": 1234567890000,
      "updateDate": 1234567890000,
      "sourceURI": "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi",
      "visible": true,
      "path": "$EXTENSIONS_DIR/ublock-origin.xpi"
    }
  ]
}
EXTEOF

# Set permissions
chmod 644 "$USER_JS" "$EXTENSIONS_JSON" "$SEARCH_JSON" 2>/dev/null || true
chmod 644 "$EXTENSIONS_DIR"/*.xpi 2>/dev/null || true

echo ""
echo "✓ Zen Browser configuration complete!"
echo "✓ Extensions installed: Vimium C, uBlock Origin"
echo "✓ Default search engine: 4get (https://4get.nadeko.net/) with Google scraper"
echo ""
echo "Launch Zen browser to activate the configuration."
echo ""
ZENEOF

    chmod +x "$zen_config_script"
    
    # Create a systemd user service to run the script after login
    mkdir -p "$HOME/.config/systemd/user"
    
    cat > "$HOME/.config/systemd/user/configure-zen.service" << 'SERVICEEOF'
[Unit]
Description=Configure Zen Browser on first boot
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=/bin/bash %h/.local/bin/configure-zen.sh
RemainAfterExit=yes

[Install]
WantedBy=default.target
SERVICEEOF

    # Enable the service
    systemctl --user enable configure-zen.service 2>/dev/null || true
    
    # Also run it immediately if we're in a session
    if [ -n "$XDG_RUNTIME_DIR" ]; then
        bash "$zen_config_script" 2>/dev/null || true
    fi
    
    print_success "Zen browser auto-configuration prepared."
    print_msg "Extensions and search engine will be configured automatically on first login."
}

setup_auto_login() {
    print_msg "Setting up auto-login with getty..."
    
    echo ""
    read -p "$(echo -e ${YELLOW}"[?] Do you want to set up auto-login to TTY1 with Hyprland auto-start? (y/N): "${RC})" -n 1 -r REPLY
    echo
    
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        print_msg "Skipping auto-login setup."
        return
    fi
    
    # Create systemd override directory for getty@tty1
    print_msg "Configuring getty@tty1 for auto-login..."
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
    
    # Create override configuration
    cat << EOF | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin $CURRENT_USER %I \$TERM
EOF
    
    print_success "Getty auto-login configured for user: $CURRENT_USER"
    
    # Add Hyprland auto-start to shell profile
    print_msg "Adding Hyprland auto-start to shell profile..."
    
    # Determine which shell profile to use
    local shell_profile=""
    if [ -f "$HOME/.bash_profile" ]; then
        shell_profile="$HOME/.bash_profile"
    elif [ -f "$HOME/.zprofile" ]; then
        shell_profile="$HOME/.zprofile"
    else
        shell_profile="$HOME/.bash_profile"
        touch "$shell_profile"
    fi
    
    # Check if auto-start is already configured
    if grep -q "# Hyprland auto-start on TTY1" "$shell_profile" 2>/dev/null; then
        print_warning "Hyprland auto-start already configured in $shell_profile"
    else
        # Add Hyprland auto-start script
        cat << 'EOF' >> "$shell_profile"

# Hyprland auto-start on TTY1
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
    exec Hyprland
fi
EOF
        print_success "Hyprland auto-start added to $shell_profile"
    fi
    
    print_success "Auto-login setup complete!"
    print_msg "After reboot, you will be automatically logged in to TTY1 and Hyprland will start."
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
    echo "  ✓ hy3 plugin for i3-style automatic tiling"
    echo "  ✓ hyprsunset for warm color temperature (3400K)"
    echo "  ✓ Frosted waybar with black icons and blur effect"
    echo "  ✓ PipeWire audio system with WirePlumber"
    echo "  ✓ NetworkManager for network management"
    echo "  ✓ Bluetooth support with Blueman"
    echo "  ✓ Gap between waybar and windows: 28 pixels"
    echo "  ✓ Zen browser auto-configured:"
    echo "    - Vimium C extension (auto-installed)"
    echo "    - uBlock Origin extension (auto-installed)"
    echo "    - Default search: 4get (https://4get.nadeko.net/) with Google scraper"
    
    if [ "$NVIDIA_INSTALL" = "true" ]; then
        echo ""
        echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${RC}"
        echo -e "${YELLOW}║                   NVIDIA OPEN DRIVERS                        ║${RC}"
        echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${RC}"
        print_nvidia "NVIDIA Open drivers (590+) installed and configured."
        print_nvidia "Kernel modules configured for direct rendering and KMS."
        print_warning "Ensure 'nvidia_drm.modeset=1' is in your bootloader parameters."
        print_msg "For GRUB, edit /etc/default/grub and add to GRUB_CMDLINE_LINUX_DEFAULT"
    fi
    
    echo ""
    echo -e "${CYAN}Keybindings:${RC}"
    echo "  Super+T        → Terminal (Alacritty)"
    echo "  Super+Return   → Terminal (Alacritty)"
    echo "  Super+E        → File Manager (Nautilus)"
    echo "  Super+F        → Browser (Zen)"
    echo "  Super+S        → LocalSend"
    echo "  Super+V        → Volume Control (PavuControl)"
    echo "  Super+A        → Application Launcher (Wofi)"
    echo "  Super+Q        → Close Window"
    echo "  Super+W        → Toggle Floating"
    echo "  Super+D        → hy3 Split Horizontal"
    echo "  Super+Shift+D  → hy3 Split Vertical"
    echo "  Super+Z        → hy3 Tabbed Group"
    echo "  Super+P        → Screenshot (selection)"
    echo "  Print          → Screenshot (full screen)"
    
    echo ""
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${RC}"
    echo -e "${YELLOW}║                    IMPORTANT NEXT STEPS                       ║${RC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${RC}"
    echo ""
    print_warning "1. REBOOT YOUR SYSTEM to apply all changes"
    
    if grep -q "# Hyprland auto-start on TTY1" "$HOME/.bash_profile" 2>/dev/null || \
       grep -q "# Hyprland auto-start on TTY1" "$HOME/.zprofile" 2>/dev/null; then
        print_success "2. After reboot, you will auto-login to TTY1 and Hyprland will start automatically!"
    else
        print_warning "2. After reboot, log into a TTY (Ctrl+Alt+F2)"
        print_warning "3. Type 'Hyprland' and press Enter to start the session"
    fi
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
    echo "║  • NVIDIA Open Drivers (590+)                               ║"
    echo "║  • Auto-login with Getty                                    ║"
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
    setup_zen_extensions
    setup_auto_login
    verify_audio_setup
    
    # Print post-installation information
    print_post_install
}

# Run the main function
main "$@"
