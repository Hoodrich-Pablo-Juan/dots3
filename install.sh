#!/bin/bash

###########################################
# E-ink Dotfiles Installation Script
# Using custom hyprland.conf with eink dots
###########################################

set -e

# Colors
RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'
CYAN='\033[36m'

BACKUP_DIR="$HOME/.config/cfg_backups/$(date +%Y%m%d_%H%M%S)"
CONFIG_DIR="$HOME/.config"
TEMP_DIR="/tmp/eink-dots-$$"
REPO_URL="https://gitlab.com/dotfiles_hypr/eink.git"

print_msg() { echo -e "${CYAN}[E-ink]${RC} $1"; }
print_success() { echo -e "${GREEN}[✓]${RC} $1"; }
print_error() { echo -e "${RED}[✗]${RC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${RC} $1"; }

check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Don't run as root!"
        exit 1
    fi
}

backup_config() {
    local config_name=$1
    local config_path="$CONFIG_DIR/$config_name"
    
    if [ -e "$config_path" ]; then
        print_msg "Backing up $config_name..."
        mkdir -p "$BACKUP_DIR"
        cp -r "$config_path" "$BACKUP_DIR/"
    fi
}

install_chaotic_aur() {
    print_msg "Installing Chaotic-AUR..."
    
    if grep -q "\[chaotic-aur\]" /etc/pacman.conf 2>/dev/null; then
        print_success "Chaotic-AUR already configured"
        return
    fi
    
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    
    if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
        echo "" | sudo tee -a /etc/pacman.conf
        echo "[chaotic-aur]" | sudo tee -a /etc/pacman.conf
        echo "Include = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf
    fi
    
    sudo pacman -Sy
    print_success "Chaotic-AUR installed"
}

install_packages() {
    print_msg "Installing packages..."
    
    local packages=(
        # Core system
        base-devel git curl wget
        
        # Core Hyprland
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
        
        # Fonts
        ttf-jetbrains-mono-nerd ttf-font-awesome
        
        # Wayland support
        qt5-wayland qt6-wayland
    )
    
    sudo pacman -S --needed --noconfirm "${packages[@]}"
    
    # Try to install ghostty if available
    sudo pacman -S --needed --noconfirm ghostty 2>/dev/null || print_warning "Ghostty not in repos, will try AUR"
    
    print_success "Core packages installed"
}

install_aur_packages() {
    print_msg "Installing AUR packages..."
    
    if ! command -v yay &> /dev/null; then
        print_msg "Installing yay..."
        cd /tmp
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd -
    fi
    
    local aur_packages=(
        zen-browser-bin
        localsend-bin
    )
    
    # Try ghostty from AUR if not installed
    if ! command -v ghostty &> /dev/null; then
        aur_packages+=(ghostty)
    fi
    
    for pkg in "${aur_packages[@]}"; do
        yay -S --needed --noconfirm "$pkg" || print_warning "Failed to install $pkg"
    done
    
    print_success "AUR packages installed"
}

create_custom_hyprland_conf() {
    print_msg "Creating custom hyprland.conf..."
    
    cat > "$TEMP_DIR/hyprland.conf" << 'EOF'
#############################################
# E-ink Glass - Modified with HyDE keybinds
#############################################

env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = GDK_BACKEND,wayland

# Unscale XWayland
xwayland {
  force_zero_scaling = true
}

# Toolkit-specific scale
env = GDK_SCALE,1
env = XCURSOR_SIZE,24

# Monitor config: 3440x1440@120Hz on DP-1, scale 1
monitor = DP-1,3440x1440@120,0x0,1
monitor = DP-1, addreserved, 40, 0, 0, 0

exec-once = brightnessctl set 10%
exec-once = swaybg -i ~/.config/wallpapers/eink.jpg -m fill

# Session vars for portals
exec-once = dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
exec-once = systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE

# Portals
exec-once = bash -lc 'sleep 0.6; systemctl --user restart xdg-desktop-portal-hyprland.service xdg-desktop-portal.service'

# Waybar
exec-once = waybar

# Notification daemon
exec-once = dunst

# Polkit
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1

# Variables
$terminal = alacritty
$fileManager = nautilus
$browser = zen-browser
$mainMod = Super

gestures {
    workspace_swipe_invert = true
    workspace_swipe_distance = 700
    workspace_swipe_use_r = true
    workspace_swipe_cancel_ratio = 0.3
}

env = XCURSOR_SIZE,24
env = HYPRCURSOR_SIZE,24

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

    shadow {
        enabled = true
        range = 30
        render_power = 2
        color = rgba(00000055)
        offset = 0 4
    }

    blur {
        enabled = true
        size = 18
        passes = 3
        new_optimizations = on
        ignore_opacity = false
        vibrancy = 0.18
    }
}

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
    pseudotile = true
    preserve_split = true
}

misc {
    force_default_wallpaper = 0
    disable_hyprland_logo = true
}

input {
    kb_layout = colemak_dh,ua
    kb_options = grp:alt_shift_toggle
    numlock_by_default = true
    mouse_refocus = false
    accel_profile = flat
    follow_mouse = 1
    sensitivity = 0

    touchpad {
        natural_scroll = true
    }
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

# Move to workspace silently
bind = $mainMod Alt, 1, movetoworkspacesilent, 1
bind = $mainMod Alt, 2, movetoworkspacesilent, 2
bind = $mainMod Alt, 3, movetoworkspacesilent, 3
bind = $mainMod Alt, 4, movetoworkspacesilent, 4
bind = $mainMod Alt, 5, movetoworkspacesilent, 5
bind = $mainMod Alt, 6, movetoworkspacesilent, 6
bind = $mainMod Alt, 7, movetoworkspacesilent, 7
bind = $mainMod Alt, 8, movetoworkspacesilent, 8
bind = $mainMod Alt, 9, movetoworkspacesilent, 9
bind = $mainMod Alt, 0, movetoworkspacesilent, 10

# Move window to relative workspace
bind = $mainMod Control+Alt, Right, movetoworkspace, r+1
bind = $mainMod Control+Alt, Left, movetoworkspace, r-1

# Scratchpad / Special workspace
bind = $mainMod Shift, S, movetoworkspace, special
bind = $mainMod Alt, S, movetoworkspacesilent, special
bind = $mainMod, S, togglespecialworkspace

# Scroll workspaces
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1

# Window rules
windowrulev2 = float, class:^(Alacritty)$
windowrulev2 = center, class:^(Alacritty)$
windowrulev2 = size 500 780, class:^(Alacritty)$
windowrulev2 = rounding 22, class:^(Alacritty)$
windowrulev2 = opacity 0.9 0.9, class:^(firefox)$
windowrulev2 = opacity 0.9 0.9, class:^(zen-alpha)$

# Layer rules
layerrule = blur, wofi
layerrule = ignorezero, wofi
EOF
}

clone_dotfiles() {
    print_msg "Cloning E-ink dotfiles from GitLab..."
    
    # Clean up any existing temp dir
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    git clone "$REPO_URL" "$TEMP_DIR/eink-dots"
    
    if [ ! -d "$TEMP_DIR/eink-dots" ]; then
        print_error "Failed to clone dotfiles repository"
        exit 1
    fi
    
    print_success "Dotfiles cloned successfully"
}

deploy_configs() {
    print_msg "Deploying configs..."
    
    # List of configs to deploy from the repo
    local configs=(
        "waybar"
        "wofi"
        "alacritty"
        "ghostty"
        "helix"
        "mpv"
    )
    
    # Backup existing configs
    for cfg in "${configs[@]}" hypr wallpapers; do
        backup_config "$cfg"
    done
    
    # Deploy configs from repo (except hyprland)
    for cfg in "${configs[@]}"; do
        if [ -d "$TEMP_DIR/eink-dots/config/$cfg" ]; then
            print_msg "Installing $cfg config..."
            cp -r "$TEMP_DIR/eink-dots/config/$cfg" "$CONFIG_DIR/"
        elif [ -d "$TEMP_DIR/eink-dots/$cfg" ]; then
            print_msg "Installing $cfg..."
            mkdir -p "$CONFIG_DIR/$cfg"
            cp -r "$TEMP_DIR/eink-dots/$cfg/"* "$CONFIG_DIR/$cfg/" 2>/dev/null || true
        fi
    done
    
    # Deploy custom hyprland config
    print_msg "Installing custom Hyprland config..."
    mkdir -p "$CONFIG_DIR/hypr"
    
    # Create the custom hyprland.conf
    create_custom_hyprland_conf
    cp "$TEMP_DIR/hyprland.conf" "$CONFIG_DIR/hypr/hyprland.conf"
    
    # Copy any hypr scripts if they exist
    if [ -d "$TEMP_DIR/eink-dots/config/hypr/scripts" ]; then
        cp -r "$TEMP_DIR/eink-dots/config/hypr/scripts" "$CONFIG_DIR/hypr/"
        chmod +x "$CONFIG_DIR/hypr/scripts/"*.sh 2>/dev/null || true
    fi
    
    # Create wf-toggle-recorder.sh if it doesn't exist
    if [ ! -f "$CONFIG_DIR/hypr/scripts/wf-toggle-recorder.sh" ]; then
        mkdir -p "$CONFIG_DIR/hypr/scripts"
        cat > "$CONFIG_DIR/hypr/scripts/wf-toggle-recorder.sh" << 'RECORDER_EOF'
#!/bin/bash
if pgrep -x "wf-recorder" > /dev/null; then
    pkill -INT wf-recorder
    notify-send "Recording" "Stopped"
else
    wf-recorder -f ~/Videos/recording_$(date +%Y%m%d_%H%M%S).mp4 &
    notify-send "Recording" "Started"
fi
RECORDER_EOF
        chmod +x "$CONFIG_DIR/hypr/scripts/wf-toggle-recorder.sh"
    fi
    
    print_success "Configs deployed"
}

setup_wallpapers() {
    print_msg "Setting up wallpapers..."
    
    mkdir -p "$CONFIG_DIR/wallpapers"
    
    # Copy wallpapers from the repo
    if [ -d "$TEMP_DIR/eink-dots/wallpapers" ]; then
        print_msg "Copying wallpapers from repo..."
        cp -r "$TEMP_DIR/eink-dots/wallpapers/"* "$CONFIG_DIR/wallpapers/" 2>/dev/null || true
        
        # Check if eink.jpg exists, if not, use the first wallpaper found
        if [ ! -f "$CONFIG_DIR/wallpapers/eink.jpg" ]; then
            print_warning "eink.jpg not found, looking for alternatives..."
            # Try to find any wallpaper and create a symlink
            for ext in jpg jpeg png; do
                for file in "$CONFIG_DIR/wallpapers/"*.$ext; do
                    if [ -f "$file" ]; then
                        print_msg "Creating symlink to $(basename "$file")"
                        ln -sf "$(basename "$file")" "$CONFIG_DIR/wallpapers/eink.jpg"
                        break 2
                    fi
                done
            done
        fi
    elif [ -d "$TEMP_DIR/eink-dots/config/wallpapers" ]; then
        print_msg "Copying wallpapers from config/wallpapers..."
        cp -r "$TEMP_DIR/eink-dots/config/wallpapers/"* "$CONFIG_DIR/wallpapers/" 2>/dev/null || true
    fi
    
    # Final check for wallpaper
    if [ -f "$CONFIG_DIR/wallpapers/eink.jpg" ]; then
        print_success "Wallpaper ready: eink.jpg"
    else
        print_warning "No wallpaper found! You may need to add one manually to ~/.config/wallpapers/eink.jpg"
    fi
}

cleanup() {
    print_msg "Cleaning up..."
    rm -rf "$TEMP_DIR"
}

main() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════╗"
    echo "║  E-ink Dotfiles Installer          ║"
    echo "║  (Custom Hyprland + GitLab dots)   ║"
    echo "╚════════════════════════════════════╝"
    echo -e "${RC}"
    echo ""
    
    check_root
    
    # Trap to ensure cleanup on exit
    trap cleanup EXIT
    
    print_msg "Starting fresh Arch installation setup..."
    echo ""
    
    install_chaotic_aur
    install_packages
    install_aur_packages
    clone_dotfiles
    deploy_configs
    setup_wallpapers
    
    echo ""
    print_success "Installation complete!"
    if [ -d "$BACKUP_DIR" ]; then
        print_msg "Backups saved to: $BACKUP_DIR"
    fi
    echo ""
    print_warning "Please reboot or restart Hyprland to apply all changes"
    print_msg "Run 'Hyprland' from TTY to start the session"
    echo ""
}

main "$@"
