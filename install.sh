#!/bin/bash

###################################################
# E-ink Dotfiles Installation Script (Enhanced)
# - Custom hyprland.conf with eink dots
# - Added NVIDIA, Network & Bluetooth support
# - Colemak DH layout
# - Custom transparent waybar configuration
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
REPO_URL="https://gitlab.com/dotfiles_hypr/eink.git"
NVIDIA_INSTALL="false" # Flag to track NVIDIA installation

# --- Messaging Functions ---
print_msg() { echo -e "${CYAN}[E-ink]${RC} $1"; }
print_success() { echo -e "${GREEN}[✓]${RC} $1"; }
print_error() { echo -e "${RED}[✗]${RC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${RC} $1"; }
print_hardware() { echo -e "${BLUE}[HARDWARE]${RC} $1"; }
print_nvidia() { echo -e "${BLUE}[NVIDIA]${RC} $1"; }

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
            nvidia-wayland-utils   # For Wayland support
            egl-wayland            # EGLStream backend for Wayland
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

install_packages() {
    print_msg "Installing core packages..."
    
    local packages=(
        # Core system
        base-devel git curl wget
        
        # Core Hyprland (placeholder, will be replaced if NVIDIA is selected)
        hyprland hyprpaper hyprpicker xdg-desktop-portal-hyprland
        
        # Wayland tools
        waybar wofi swaybg grim slurp wf-recorder wl-clipboard
        
        # Notification daemon
        dunst libnotify
        
        # Terminals & editor
        alacritty helix
        
        # Apps
        nautilus mpv htop
        
        # Utils
        brightnessctl pamixer playerctl polkit-gnome
        
        # Fonts (added OpenSans for waybar)
        ttf-jetbrains-mono-nerd ttf-font-awesome ttf-opensans
        
        # Wayland support
        qt5-wayland qt6-wayland
    )
    
    if [ "$NVIDIA_INSTALL" = "true" ]; then
        print_nvidia "Replacing 'hyprland' with 'hyprland-nvidia' for installation."
        packages=("${packages[@]/hyprland/hyprland-nvidia}")
    fi
    
    sudo pacman -S --needed --noconfirm "${packages[@]}"
    
    # Try to install ghostty if available
    sudo pacman -S --needed --noconfirm ghostty 2>/dev/null || print_warning "Ghostty not in official repos, will try AUR later."
    
    print_success "Core packages installed."
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

create_custom_hyprland_conf() {
    print_msg "Creating custom hyprland.conf with Colemak DH layout..."
    
    # Base config with updated input section
    cat > "$TEMP_DIR/hyprland.conf" << 'EOF'
#############################################
# E-ink Glass - Modified with HyDE keybinds
#############################################

# --- Session & Environment ---
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = GDK_BACKEND,wayland
env = QT_QPA_PLATFORM,wayland
env = XCURSOR_SIZE,24
env = HYPRCURSOR_SIZE,24

# Unscale XWayland
xwayland {
  force_zero_scaling = true
}

# --- Monitor & Execs ---
monitor = ,preferred,auto,1
exec-once = brightnessctl set 10%
exec-once = swaybg -i ~/.config/wallpapers/eink.jpg -m fill

# Session vars for portals & services
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = nm-applet --indicator
exec-once = waybar
exec-once = dunst

# --- Variables ---
$terminal = alacritty
$fileManager = nautilus
$browser = zen-browser
$mainMod = Super

# --- Input & Gestures with Colemak DH ---
input {
    kb_layout = us
    kb_variant = colemak_dh
    numlock_by_default = true
    mouse_refocus = false
    accel_profile = flat
    follow_mouse = 1
    sensitivity = 0

    touchpad {
        natural_scroll = true
    }
}

gestures {
    workspace_swipe_invert = true
    workspace_swipe_distance = 700
    workspace_swipe_use_r = true
    workspace_swipe_cancel_ratio = 0.3
}

# --- General & Decoration ---
general {
    gaps_in = 8
    gaps_out = 16
    border_size = 1
    col.active_border = rgba(333333cc)
    col.inactive_border = rgba(33333377)
    resize_on_border = true
    layout = dwindle
}

decoration {
    rounding = 22
    active_opacity = 1.0
    inactive_opacity = 0.92

    drop_shadow = true
    shadow_range = 30
    shadow_render_power = 2
    col.shadow = rgba(00000055)
    shadow_offset = 0 4

    blur {
        enabled = true
        size = 18
        passes = 3
        new_optimizations = on
        ignore_opacity = false
        vibrancy = 0.18
    }
}

# --- Animations & Layouts ---
animations {
    enabled = true
    bezier = ease, 0.15, 0.9, 0.1, 1.0
    animation = windows, 1, 6, ease
    animation = windowsOut, 1, 5, default, popin 80%
    animation = border, 1, 10, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

dwindle {
    pseudotile = yes
    preserve_split = yes
}

misc {
    force_default_wallpaper = 0
    disable_hyprland_logo = true
}

#############################################
# KEYBINDINGS (HyDE-style)
#############################################

# Window Management
bind = $mainMod, Q, killactive
bind = Alt, F4, killactive
bind = $mainMod, Delete, exit
bind = $mainMod, W, togglefloating
bind = $mainMod, G, togglegroup
bind = Alt, Space, fullscreen
bind = $mainMod, J, togglesplit

# Focus
bind = $mainMod, Left, movefocus, l
bind = $mainMod, Right, movefocus, r
bind = $mainMod, Up, movefocus, u
bind = $mainMod, Down, movefocus, d
bind = ALT, Tab, cyclenext

# Resize windows
binde = $mainMod Shift, Right, resizeactive, 30 0
binde = $mainMod Shift, Left, resizeactive, -30 0
binde = $mainMod Shift, Up, resizeactive, 0 -30
binde = $mainMod Shift, Down, resizeactive, 0 30

# Move windows
binde = $mainMod Shift Control, left, movewindow, l
binde = $mainMod Shift Control, right, movewindow, r
binde = $mainMod Shift Control, up, movewindow, u
binde = $mainMod Shift Control, down, movewindow, d

# Move/Resize with mouse
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# Group Navigation
bind = $mainMod Control, H, changegroupactive, b
bind = $mainMod Control, L, changegroupactive, f

# Applications
bind = $mainMod, T, exec, $terminal
bind = $mainMod, E, exec, $fileManager
bind = $mainMod, F, exec, $browser
bind = $mainMod, R, exec, localsend
bind = $mainMod, A, exec, wofi --show drun --prompt "" --location center --width 600
bind = Control Shift, Escape, exec, $terminal -e htop

# Screenshots & Recording
bind = $mainMod Shift, P, exec, hyprpicker -a
bind = $mainMod, P, exec, grim -g "$(slurp)" - | wl-copy
bind = , Print, exec, grim - | wl-copy
bind = $mainMod Control, P, exec, ~/.config/hypr/scripts/wf-toggle-recorder.sh

# Hardware Controls - Audio
bindl = , F10, exec, pamixer -t
bindl = , XF86AudioMute, exec, pamixer -t
bindel = , F11, exec, pamixer -d 5
bindel = , F12, exec, pamixer -i 5
bindl = , XF86AudioMicMute, exec, pamixer --default-source -t
bindel = , XF86AudioLowerVolume, exec, pamixer -d 5
bindel = , XF86AudioRaiseVolume, exec, pamixer -i 5

# Hardware Controls - Media
bindl = , XF86AudioPlay, exec, playerctl play-pause
bindl = , XF86AudioPause, exec, playerctl play-pause
bindl = , XF86AudioNext, exec, playerctl next
bindl = , XF86AudioPrev, exec, playerctl previous

# Hardware Controls - Brightness
bindel = , XF86MonBrightnessUp, exec, brightnessctl s 10%+
bindel = , XF86MonBrightnessDown, exec, brightnessctl s 10%-

# Workspaces
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Move to workspace
bind = $mainMod Shift, 1, movetoworkspace, 1
bind = $mainMod Shift, 2, movetoworkspace, 2
bind = $mainMod Shift, 3, movetoworkspace, 3
bind = $mainMod Shift, 4, movetoworkspace, 4
bind = $mainMod Shift, 5, movetoworkspace, 5
bind = $mainMod Shift, 6, movetoworkspace, 6
bind = $mainMod Shift, 7, movetoworkspace, 7
bind = $mainMod Shift, 8, movetoworkspace, 8
bind = $mainMod Shift, 9, movetoworkspace, 9
bind = $mainMod Shift, 0, movetoworkspace, 10

# Relative workspace navigation
bind = $mainMod Control, Right, workspace, r+1
bind = $mainMod Control, Left, workspace, r-1
bind = $mainMod Control, Down, workspace, empty

# Scroll workspaces
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1

# --- Window & Layer Rules ---
windowrulev2 = float, class:^(Alacritty)$
windowrulev2 = center, class:^(Alacritty)$
windowrulev2 = size 500 780, class:^(Alacritty)$
windowrulev2 = rounding 22, class:^(Alacritty)$
windowrulev2 = opacity 0.9 0.9, class:^(firefox)$
windowrulev2 = opacity 0.9 0.9, class:^(zen-alpha)$

layerrule = blur, wofi
layerrule = ignorezero, wofi
EOF

    # Append NVIDIA specific environment variables if needed
    if [ "$NVIDIA_INSTALL" = "true" ]; then
        print_nvidia "Adding NVIDIA environment variables to hyprland.conf"
        cat >> "$TEMP_DIR/hyprland.conf" << EOF

# --- NVIDIA Specific Environment Variables ---
env = LIBVA_DRIVER_NAME,nvidia
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
EOF
    fi
}

create_custom_waybar_style() {
    print_msg "Creating custom transparent waybar style..."
    
    cat > "$TEMP_DIR/waybar-style.css" << 'EOF'
/* Group Styles */

/* Pill Styles */
@import "groups/pill.css";
@import "groups/pill-up.css";
@import "groups/pill-right.css";
@import "groups/pill-down.css";
@import "groups/pill-left.css";
@import "groups/pill-in.css";
@import "groups/pill-out.css";
/* Leaf Style */
@import "groups/leaf.css";
@import "groups/leaf-inverse.css";

/* Dynamic Stuff */
@import "../../../../.config/waybar/includes/border-radius.css";
@import "../../../../.config/waybar/includes/global.css";

/* Base HyDE Styles with global font properties */

* {
    font-family: "OpenSans", "Open Sans", sans-serif;
    font-weight: 500;
    font-size: 14px;
}

window#waybar {
    background: transparent; /* fully transparent background */
    border-radius: 0px; /* seamless - no rounded corners */
    border: none; /* no border for seamless look */
    box-shadow: none; /* no shadow for seamless look */
    font-size: 1.1em; /* slightly larger for main bar */
    transition: background 0.3s ease; /* smooth transitions */
}

/* Reactive states - keep transparent but could add subtle effects */
window#waybar:hover {
    background: transparent;
}

window#waybar.focused {
    background: transparent;
}

/* Groups / Islands - Make them transparent */

#leaf,
#leaf-inverse,
#leaf-up,
#leaf-down,
#leaf-right,
#leaf-left,
#pill,
#pill-right,
#pill-left,
#pill-down,
#pill-up,
#pill-in,
#pill-out {
    background: transparent;
    border: none;
    border-radius: 10px;
}

/* Workspaces Buttons - Light mode with transparency */

#workspaces button {
    box-shadow: none;
    text-shadow: 0 0 2px rgba(255, 255, 255, 0.6);
    padding: 0em 0.3em;
    margin: 0.3em 0;
    color: #333333;
    animation: ws_normal 20s ease-in-out 1;
    background-color: rgba(255, 255, 255, 0.4);
    border-radius: 8px;
}

#workspaces button.active {
    background-color: rgba(255, 255, 255, 0.7);
    color: #000000;
    margin-left: 0.3em;
    padding-left: 1.2em;
    padding-right: 1.2em;
    margin-right: 0.3em;
    animation: ws_active 20s ease-in-out 1;
    transition: all 0.4s cubic-bezier(.55, -0.68, .48, 1.682);
}

#workspaces button:hover {
    background-color: rgba(255, 255, 255, 0.6);
    color: #111111;
    animation: ws_hover 20s ease-in-out 1;
    transition: all 0.3s cubic-bezier(.55, -0.68, .48, 1.682);
}

/* Taskbar Buttons - Make transparent */

#taskbar button {
    box-shadow: none;
    text-shadow: 0 0 2px rgba(255, 255, 255, 0.6);
    padding: 0em 0.3em;
    margin: 0.3em 0;
    color: #333333;
    animation: tb_normal 20s ease-in-out 1;
    background: transparent;
    border: none;
    border-radius: 8px;
}

#taskbar button.active {
    background: transparent;
    color: #000000;
    margin-left: 0.3em;
    padding-left: 1.2em;
    padding-right: 1.2em;
    margin-right: 0.3em;
    animation: tb_active 20s ease-in-out 1;
    transition: all 0.4s cubic-bezier(.55, -0.68, .48, 1.682);
}

#taskbar button:hover {
    background: transparent;
    color: #111111;
    animation: tb_hover 20s ease-in-out 1;
    transition: all 0.3s cubic-bezier(.55, -0.68, .48, 1.682);
}

/* All modules - light text */
#battery,
#backlight,
#clock,
#cpu,
#memory,
#temperature,
#network,
#pulseaudio,
#custom-weather,
#custom-power,
#custom-cava,
#custom-hyde-menu,
#custom-hyprsunset,
#idle_inhibitor,
#tray {
    color: #333333;
    background: transparent;
    padding: 0 0.5em;
}

/* Workspaces & Taskbar Containers */
#workspaces,
#taskbar {
    padding: 0em;
}

/* Modules Padding */
window#waybar.top .modules-left,
window#waybar.top .modules-center,
window#waybar.top .modules-right,
window#waybar.bottom .modules-left,
window#waybar.bottom .modules-center,
window#waybar.bottom .modules-right {
    padding-left: 0.3em;
    padding-right: 0.3em;
    margin-left: 0.3em;
    margin-right: 0.3em;
}

window#waybar.top label.module,
window#waybar.bottom label.module {
    padding-left: 0.2em;
    padding-right: 0.2em;
    margin-left: 0.2em;
    margin-right: 0.2em;
}


/* Leaves & Pills Padding for Side Bars */
window#waybar.right #leaf,
window#waybar.left #leaf,
window#waybar.right #leaf-inverse,
window#waybar.left #leaf-inverse,
window#waybar.right #leaf-up,
window#waybar.left #leaf-up,
window#waybar.right #leaf-down,
window#waybar.left #leaf-down,
window#waybar.right #leaf-right,
window#waybar.left #leaf-right,
window#waybar.right #leaf-left,
window#waybar.left #leaf-left,
window#waybar.right #pill,
window#waybar.left #pill,
window#waybar.right #pill-right,
window#waybar.left #pill-right,
window#waybar.right #pill-left,
window#waybar.left #pill-left,
window#waybar.right #pill-down,
window#waybar.left #pill-down,
window#waybar.right #pill-up,
window#waybar.left #pill-up,
window#waybar.right #pill-in,
window#waybar.left #pill-in,
window#waybar.right #pill-out,
window#waybar.left #pill-out {
    padding: 0em;
}

window#waybar.bottom #leaf,
window#waybar.bottom #leaf-inverse,
window#waybar.bottom #leaf-up,
window#waybar.bottom #leaf-down,
window#waybar.bottom #leaf-right,
window#waybar.bottom #leaf-left,
window#waybar.bottom #pill,
window#waybar.bottom #pill-right,
window#waybar.bottom #pill-left,
window#waybar.bottom #pill-down,
window#waybar.bottom #pill-up,
window#waybar.bottom #pill-in,
window#waybar.bottom #pill-out,
window#waybar.top #leaf,
window#waybar.top #leaf-inverse,
window#waybar.top #leaf-up,
window#waybar.top #leaf-down,
window#waybar.top #leaf-right,
window#waybar.top #leaf-left,
window#waybar.top #pill,
window#waybar.top #pill-right,
window#waybar.top #pill-left,
window#waybar.top #pill-down,
window#waybar.top #pill-up,
window#waybar.top #pill-in,
window#waybar.top #pill-out {
    padding: 0em 1em;
}

/* Dynamic Buttons Margin */
window#waybar.top button,
window#waybar.bottom button {
    margin: 0.41em 0.11em;
    border: 0em;
}

window#waybar.left button,
window#waybar.right button {
    margin: 0.11em 0.41em;
    border: 0em;
}

/* Tooltips - light mode */
tooltip {
    background-color: rgba(255, 255, 255, 0.95);
    color: #333333;
    border: 1px solid rgba(0, 0, 0, 0.1);
    border-radius: 6px;
    transition: all 0.3s ease;
}

/* Tray Menu - clean and simple */
#tray menu * {
    min-height: 1.6em;
}

#tray menu separator {
    min-height: 0.1em;
}

/* Language Button */
#language {
    min-width: 1.11em;
}
EOF
}

create_custom_waybar_config() {
    print_msg "Creating custom waybar configuration..."
    
    cat > "$TEMP_DIR/waybar-config.json" << 'EOF'
{
    "layer": "top",
    "output": [
        "*"
    ],
    "height": 10,
    "exclusive": true,
    "passthrough": false,
    "reload_style_on_change": true,
    "include": [
        "$XDG_CONFIG_HOME/waybar/modules/*json*", 
        "$XDG_CONFIG_HOME/waybar/includes/includes.json" 
    ],
    "modules-left": [
        "group/pill#left"
    ],
    "group/pill#left": {
        "orientation": "inherit",
        "modules": [
            "hyprland/workspaces"
        ]
    },
    "modules-center": [
        "group/pill#center"
    ],
    "group/pill#center": {
        "orientation": "inherit",
        "modules": [
            "custom/cava",
            "clock",
            "custom/weather"
        ]
    },
    "modules-right": [
        "group/pill#right"
    ],
    "group/pill#right": {
        "orientation": "inherit",
        "modules": [
            "battery",
            "backlight",
            "tray",
            "custom/power",
            "idle_inhibitor",
            "custom/hyprsunset",
            "custom/hyde-menu"
        ]
    },
    "custom/weather": {
        "exec": "curl -s 'https://wttr.in/Timișoara?format=1' | sed 's/+//; s/°C/°/'",
        "interval": 600,
        "return-type": "",
        "format": " {}",
        "tooltip": false
    },
    "clock": {
        "format": "{:%H:%M}",
        "tooltip-format": "{:%A, %B %d, %Y - %H:%M:%S}",
        "interval": 1
    },
    "battery": {
        "format": "{capacity}%",
        "format-charging": "{capacity}%",
        "format-plugged": "{capacity}%",
        "format-critical": "{capacity}%",
        "states": {
            "warning": 30,
            "critical": 15
        }
    },
    "backlight": {
        "format": "{percent}%",
        "on-scroll-up": "brightnessctl s 5%+",
        "on-scroll-down": "brightnessctl s 5%-"
    }
}
EOF
}

clone_dotfiles() {
    print_msg "Cloning E-ink dotfiles from GitLab..."
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    if git clone "$REPO_URL" "$TEMP_DIR/eink-dots"; then
        print_success "Dotfiles cloned successfully."
    else
        print_error "Failed to clone dotfiles repository from $REPO_URL"
        exit 1
    fi
}

deploy_configs() {
    print_msg "Deploying configuration files..."
    
    local dotfiles_root="$TEMP_DIR/eink-dots"
    # Determine if configs are in a 'config' subdirectory or at the root
    local config_source_dir="$dotfiles_root/config"
    if [ ! -d "$config_source_dir" ]; then
        config_source_dir="$dotfiles_root"
    fi

    # List of configs to deploy
    local configs_to_deploy=(
        "waybar" "wofi" "alacritty" "ghostty" "helix" "mpv" "dunst"
    )
    
    # Backup existing configs first
    for cfg in "${configs_to_deploy[@]}" "hypr" "wallpapers"; do
        backup_config "$cfg"
    done
    
    # Deploy configs from repo
    for cfg in "${configs_to_deploy[@]}"; do
        if [ "$cfg" = "waybar" ]; then
            # Special handling for waybar - deploy from repo first, then overwrite
            if [ -d "$config_source_dir/$cfg" ]; then
                print_msg "Deploying base waybar config from repository..."
                cp -r "$config_source_dir/$cfg" "$CONFIG_DIR/"
            fi
            # Now overwrite with custom transparent style and config
            print_msg "Applying custom transparent waybar configuration..."
            create_custom_waybar_style
            create_custom_waybar_config
            cp "$TEMP_DIR/waybar-style.css" "$CONFIG_DIR/waybar/style.css"
            cp "$TEMP_DIR/waybar-config.json" "$CONFIG_DIR/waybar/config.json"
        elif [ -d "$config_source_dir/$cfg" ]; then
            print_msg "Deploying '$cfg' config..."
            cp -r "$config_source_dir/$cfg" "$CONFIG_DIR/"
        else
            print_warning "Config for '$cfg' not found in repository, skipping."
        fi
    done
    
    # Deploy custom hyprland config
    print_msg "Installing custom Hyprland config with Colemak DH..."
    mkdir -p "$CONFIG_DIR/hypr"
    create_custom_hyprland_conf # Generates the file in TEMP_DIR
    cp "$TEMP_DIR/hyprland.conf" "$CONFIG_DIR/hypr/hyprland.conf"
    
    # Copy scripts for hyprland
    if [ -d "$config_source_dir/hypr/scripts" ]; then
        cp -r "$config_source_dir/hypr/scripts" "$CONFIG_DIR/hypr/"
        chmod +x "$CONFIG_DIR/hypr/scripts/"*.sh 2>/dev/null || true
    fi
    
    # Create a default screen recorder script if it doesn't exist
    local recorder_script="$CONFIG_DIR/hypr/scripts/wf-toggle-recorder.sh"
    if [ ! -f "$recorder_script" ]; then
        mkdir -p "$(dirname "$recorder_script")"
        cat > "$recorder_script" << 'REC_EOF'
#!/bin/bash
if pgrep -x "wf-recorder" > /dev/null; then
    pkill -INT wf-recorder
    notify-send "Screen Recording" "Stopped."
else
    mkdir -p "$HOME/Videos/Recordings"
    wf-recorder -f "$HOME/Videos/Recordings/rec_$(date +%Y%m%d_%H%M%S).mp4" &
    notify-send "Screen Recording" "Started. Press Ctrl+P again to stop."
fi
REC_EOF
        chmod +x "$recorder_script"
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

cleanup() {
    print_msg "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
}

main() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════╗"
    echo "║        E-ink Dotfiles Installer            ║"
    echo "║  (Colemak DH + Transparent Waybar)         ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${RC}"
    
    check_root
    trap cleanup EXIT
    
    install_chaotic_aur
    install_hardware_support # Install drivers and enable services first
    install_packages         # Installs core software (with NVIDIA variant if selected)
    install_aur_packages
    clone_dotfiles
    deploy_configs
    setup_wallpapers
    
    echo ""
    print_success "Installation complete!"
    if [ -d "$BACKUP_DIR" ]; then
        print_msg "Your old configs were backed up to: $BACKUP_DIR"
    fi
    echo ""
    print_msg "Keyboard layout is set to Colemak DH"
    print_msg "Waybar has been configured with transparent theme"
    print_warning "A REBOOT is strongly recommended to apply all changes, especially kernel modules."
    if [ "$NVIDIA_INSTALL" = "true" ]; then
        echo -e "${YELLOW}############################## NVIDIA POST-INSTALL ##############################${RC}"
        print_nvidia "NVIDIA drivers have been installed and configured."
        print_warning "If you have issues booting, you may need to add 'nvidia_drm.modeset=1' to your bootloader's kernel parameters manually."
        echo -e "${YELLOW}###################################################################################${RC}"
    fi
    echo ""
    print_msg "After rebooting, start the session by typing 'Hyprland' in a TTY and pressing Enter."
    echo ""
}

main "$@"
