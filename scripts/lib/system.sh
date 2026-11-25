#!/usr/bin/env bash
# Shared package and login-screen operations for the installer and runtime imports.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set -euo pipefail
    readonly NAME="bloodyShell"
    readonly PACKAGE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    readonly CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
    readonly STAMP="$(date +%Y-%m-%d_%H-%M-%S)-$$"
    [[ $EUID -ne 0 ]] || { printf 'Run this command as your normal user.\n' >&2; exit 1; }
fi

# Shared system helpers
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    B=$'\e[1m' D=$'\e[2m' R=$'\e[0m'
    RED=$'\e[31m' GRN=$'\e[32m' YLW=$'\e[33m' BLU=$'\e[34m' CYN=$'\e[36m'
else
    B="" D="" R="" RED="" GRN="" YLW="" BLU="" CYN=""
fi
interactive() { [[ -t 0 && -t 1 ]]; }
use_gum() { interactive && command -v gum > /dev/null; }

gum_choose()
{
    gum choose \
        --cursor "› " \
        --cursor.foreground 0 --cursor.background 6 --cursor.bold \
        --selected.foreground 0 --selected.background 6 --selected.bold \
        --header.foreground 6 --header.bold \
        --cursor-prefix "[ ] " --selected-prefix "[✓] " --unselected-prefix "[ ] " \
        --padding "1 2" "$@"
}

pretty() { printf '%s' "${1/#$HOME/\~}"; }
hl()     { printf '%s%s%s' "$CYN" "$(pretty "$1")" "$R"; }

message() { printf '  %s%s%-5s%s  %s\n' "$1" "$B" "$2" "$R" "$3"; }
info() { message "$CYN" "INFO" "$*"; }
ok()   { message "$GRN" "DONE" "$*"; }
warn() { message "$YLW" "NOTE" "$*" >&2; }
die()  { message "$RED" "ERROR" "$*" >&2; exit 1; }

rule()
{
    local width="${COLUMNS:-80}"
    [[ "$width" =~ ^[0-9]+$ ]] || width=80
    width=$((width > 76 ? 72 : width > 8 ? width - 4 : 4))
    printf '  %s' "$D"
    printf '─%.0s' $(seq "$width")
    printf '%s\n' "$R"
}

section() { printf '\n  %s%s%s%s\n' "$CYN" "$B" "$1" "$R"; rule; }

pad_choices()
{
    local -n rows="$1"
    local width=0 row i
    for row in "${rows[@]}"; do (( ${#row} > width )) && width=${#row}; done
    for i in "${!rows[@]}"; do printf -v 'rows[i]' ' %-*s ' "$width" "${rows[$i]}"; done
    return 0
}

ask()
{
    interactive || return 1

    local default="${2:-y}" hint answer
    if use_gum; then
        local initial="No"
        [[ "$default" == "y" ]] && initial="Yes"
        if answer="$(gum_choose --header "$1" --selected "$initial" -- Yes No)"; then
            [[ "$answer" == "Yes" ]]
            return
        else
            local result=$?
            [[ $result -eq 130 ]] && exit 130
            return 1
        fi
    fi
    [[ "$default" == "y" ]] && hint="Y/n" || hint="y/N"
    while true; do
        printf '  %s%s?%s %s%s%s %s[%s]%s\n' "$BLU" "$B" "$R" "$B" "$1" "$R" "$D" "$hint" "$R"
        read -r -p $'\n'"  ${BLU}${B}›${R} " answer || return 1
        answer="${answer,,}"
        [[ -z "$answer" ]] && answer="$default"
        case "$answer" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *)     warn "Answer y or n" ;;
        esac
    done
}

CHOICE=0
choose()
{
    local title="$1"; shift
    local items=("$@") n="$#"

    CHOICE=0
    if use_gum; then
        local display=() item label about chosen width=0
        for item in "${items[@]}"; do
            label="${item%%|*}"
            (( ${#label} > width )) && width=${#label}
        done
        for item in "${items[@]}"; do
            label="${item%%|*}"
            about=""
            [[ "$item" == *"|"* ]] && about="${item#*|}"
            display+=("$(printf '%-*s  %s' "$width" "$label" "$about")")
        done
        display+=("Quit")
        pad_choices display
        if chosen="$(gum_choose --header "$title" -- "${display[@]}")"; then
            for i in "${!display[@]}"; do
                [[ "$chosen" == "${display[$i]}" ]] && { (( i < n )) && CHOICE=$((i + 1)); break; }
            done
        fi
        return 0
    fi

    section "$title"
    for i in $(seq "$n"); do
        local item="${items[$((i - 1))]}"
        local label="${item%%|*}" about=""
        [[ "$item" == *"|"* ]] && about="${item#*|}"
        printf '    %s%d)%s %-14s %s%s%s\n' "$CYN$B" "$i" "$R" "$label" "$D" "$about" "$R"
    done
    printf '    %s0)%s %sQuit%s\n' "$D" "$R" "$D" "$R"

    local answer
    while true; do
        read -r -p $'\n'"  ${BLU}${B}›${R} " answer || { CHOICE=0; return; }
        if [[ "$answer" =~ ^[0-9]+$ ]] && (( answer >= 0 && answer <= n )); then
            CHOICE="$answer"
            return
        fi
        warn "Enter a number from 0 to $n"
    done
}


distro_family()
{
    python3 "$PACKAGE/scripts/bloodyShell" internal dependencies family
}


dependency_packages()
{
    local family="$1" line="$2" field
    IFS='|' read -r _ _ _ arch fedora debian <<< "$line"
    case "$family" in
        arch)   field="$arch" ;;
        fedora) field="$fedora" ;;
        debian) field="$debian" ;;
        *)      field="-" ;;
    esac
    [[ "$field" == "-" ]] && echo "" || echo "$field"
}


aur_helper() { command -v paru > /dev/null && { echo paru; return; }; command -v yay > /dev/null && echo yay; }

ensure_aur_helper()
{
    [[ -n "$(aur_helper)" ]] && return 0
    if [[ "${BLOODYSHELL_SETUP_BATCH:-}" == 1 ]]; then
        CHOICE=1
    else
        choose "Some packages are in the AUR only: install an AUR helper?" "paru|recommended" "yay|"
    fi
    case "$CHOICE" in
        1) local helper=paru ;;
        2) local helper=yay ;;
        *) return 1 ;;
    esac
    local confirm=()
    [[ "${BLOODYSHELL_SETUP_BATCH:-}" != 1 ]] || confirm=(--noconfirm)
    sudo pacman -S --needed "${confirm[@]}" base-devel git || return 1
    local tmp; tmp="$(mktemp -d)"
    git clone --depth 1 "https://aur.archlinux.org/$helper-bin.git" "$tmp/$helper" && (cd "$tmp/$helper" && makepkg -si --noconfirm)
    local result=$?
    rm -rf "$tmp"
    [[ $result -eq 0 ]] && ok "$helper installed" || { warn "Could not install $helper"; return 1; }
}

apt_command()
{
    if [[ "${BLOODYSHELL_SETUP_BATCH:-}" == 1 ]]; then
        sudo env DEBIAN_FRONTEND=noninteractive apt-get \
            -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold "$@"
    else
        sudo apt-get "$@"
    fi
}

install_packages()
{
    local family="$1"; shift
    [[ $# -gt 0 ]] || return 0
    local confirm=()
    [[ "${BLOODYSHELL_SETUP_BATCH:-}" != 1 ]] || confirm=(--noconfirm)
    case "$family" in
        arch)
            local repo=() aur=()
            for p in "$@"; do if pacman -Si "$p" > /dev/null 2>&1; then repo+=("$p"); else aur+=("$p"); fi; done
            [[ ${#repo[@]} -eq 0 ]] || sudo pacman -S --needed "${confirm[@]}" "${repo[@]}" || return 1
            if [[ ${#aur[@]} -gt 0 ]]; then
                ensure_aur_helper || { warn "Not installed (AUR): ${aur[*]}"; return 1; }
                "$(aur_helper)" -S --needed "${confirm[@]}" "${aur[@]}" || return 1
            fi ;;
        fedora)
            local plain=() coprs=()
            for p in "$@"; do if [[ "$p" == copr:* ]]; then coprs+=("${p#copr:}"); else plain+=("$p"); fi; done
            for c in "${coprs[@]+"${coprs[@]}"}"; do sudo dnf copr enable -y "$c" || return 1; done
            [[ ${#plain[@]} -eq 0 ]] || sudo dnf install -y "${plain[@]}" || return 1 ;;
        debian)
            apt_command update && apt_command install -y "$@" || return 1 ;;
        *) return 1 ;;
    esac
}


install_native_support()
{
    if command -v c++ > /dev/null && command -v wayland-scanner > /dev/null && command -v pkg-config > /dev/null && pkg-config --exists Qt6Quick wayland-client xkbcommon; then return 0; fi
    local family="$1" names packages=()
    names=$(python3 "$PACKAGE/scripts/bloodyShell" internal dependencies native-packages "$family") || return 1
    mapfile -t packages <<< "$names"
    if interactive && ask "Install development tools for Alt+Tab and the on-screen keyboard? (needs sudo)" y; then
        install_packages "$family" "${packages[@]}" || warn "Native keyboard support could not be prepared"
    else
        warn "Native keyboard build support skipped: ${packages[*]}"
    fi
}

readonly SDDM_THEME="/usr/share/sddm/themes/$NAME"
readonly GREETER_STATE="/var/lib/$NAME"
readonly SDDM_CONF="/etc/sddm.conf.d/zz-$NAME.conf"
readonly SDDM_SYSTEM_CONF="/etc/sddm.conf"

restore_sddm_files()
{
    local theme_backup="$1" config_backup="$2" system_backup="${3:-}"
    sudo rm -rf "$SDDM_THEME"
    [[ -z "$theme_backup" ]] || sudo mv "$theme_backup" "$SDDM_THEME"
    if [[ -n "$config_backup" ]]; then sudo cp -a "$config_backup" "$SDDM_CONF"; else sudo rm -f "$SDDM_CONF"; fi
    [[ -z "$system_backup" ]] || sudo cp --preserve=all "$system_backup" "$SDDM_SYSTEM_CONF"
    SDDM_RESTORED=true
}

discard_sddm_backups()
{
    [[ "${BLOODYSHELL_SETUP_BATCH:-}" == 1 && "${BLOODYSHELL_SETUP_BACKUP:-true}" == false ]] || return 0
    local previous
    for previous in "$@"; do
        [[ -z "$previous" ]] || sudo rm -rf -- "$previous" || return 1
    done
}

check_greeter_theme()
{
    local file
    for file in Main.qml Widgets.qml Theme.qml metadata.desktop theme.conf niri.kdl; do
        [[ -s "$1/dots/sddm/$file" ]] || { warn "Missing login-screen file: $file"; return 1; }
    done
}

prepare_greeter_theme()
{
    local resource="$1" theme="$2"
    mkdir -p "$theme/keyboard" &&
        cp -a "$resource/dots/sddm/." "$theme/" &&
        ln -s "$GREETER_STATE/theme.conf" "$theme/theme.conf.user" &&
        cp -a "$PACKAGE/modules/common/keyboard/." "$theme/keyboard/" &&
        python3 "$PACKAGE/scripts/bloodyShell" internal build-virtual-keyboard "$theme/native" > /dev/null &&
        printf '\nkeyboardSource=keyboard/Keyboard.qml\n' >> "$theme/theme.conf"
}

refresh_greeter()
(
    [[ -d "$SDDM_THEME" && ! -L "$SDDM_THEME" ]] || return 0
    local -a elevate=(sudo)
    if ! interactive; then elevate+=(-n); fi
    "${elevate[@]}" -v || return 75
    check_greeter_theme "$PACKAGE" && niri validate -c "$PACKAGE/dots/sddm/niri.kdl" || return 1

    local stage swap="" committed=false
    stage="$(mktemp -d)" || return 1
    finish_theme_refresh()
    {
        local result=$?
        trap - EXIT INT TERM HUP
        if [[ -n "$swap" ]]; then
            if ! $committed && [[ -d "$swap/previous" ]]; then
                if ! { "${elevate[@]}" rm -rf -- "$SDDM_THEME" &&
                       "${elevate[@]}" mv -T -- "$swap/previous" "$SDDM_THEME"; }; then
                    warn "Restore the previous login screen from $swap/previous"
                    rm -rf -- "$stage"
                    exit 1
                fi
            fi
            "${elevate[@]}" rm -rf -- "$swap" || true
        fi
        rm -rf -- "$stage"
        exit "$result"
    }
    trap finish_theme_refresh EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    trap 'exit 129' HUP
    prepare_greeter_theme "$PACKAGE" "$stage/theme" || { warn "Could not prepare the login-screen theme"; return 1; }
    swap="$("${elevate[@]}" mktemp -d "$(dirname "$SDDM_THEME")/.bloodyShell-theme.XXXXXX")" || return 1
    "${elevate[@]}" chmod 0711 "$swap" || return 1
    "${elevate[@]}" cp -a -- "$stage/theme" "$swap/theme" || return 1
    if [[ -e "$SDDM_THEME/theme.conf.user" || -L "$SDDM_THEME/theme.conf.user" ]]; then
        "${elevate[@]}" rm -f -- "$swap/theme/theme.conf.user" &&
            "${elevate[@]}" cp -a -- "$SDDM_THEME/theme.conf.user" "$swap/theme/theme.conf.user" || return 1
    fi
    "${elevate[@]}" chown -R root:root "$swap/theme" &&
        "${elevate[@]}" chmod -R a+rX,go-w "$swap/theme" &&
        "${elevate[@]}" mv -T -- "$SDDM_THEME" "$swap/previous" &&
        "${elevate[@]}" mv -T -- "$swap/theme" "$SDDM_THEME" || return 1
    committed=true
    ok "SDDM login screen refreshed"
)

apply_greeter()
(
    local resource="${BLOODYSHELL_RESOURCE_DIR:-$PACKAGE}"
    if [[ ! -d "$resource/dots/sddm" ]]; then
        python3 "$PACKAGE/scripts/bloodyShell" internal resources import greeter --human
        return
    fi
    if ! interactive && ! sudo -n true 2> /dev/null; then warn "Needs sudo in a terminal: login screen skipped"; return 0; fi
    local line sddm_dependency=""
    check_greeter_theme "$resource" || return 1
    local family; family="$(distro_family)"
    local missing=() dependencies=() niri_dependency=""
    local catalog
    catalog="$(python3 "$PACKAGE/scripts/bloodyShell" internal dependencies catalog)" || return 1
    mapfile -t dependencies <<< "$catalog"
    for line in "${dependencies[@]}"; do
        [[ "$line" != "optional|sddm|"* ]] || sddm_dependency="$line"
        [[ "$line" != "required|niri|"* ]] || niri_dependency="$line"
    done
    if ! command -v sddm > /dev/null || ! command -v sddm-greeter-qt6 > /dev/null; then
        missing+=($(dependency_packages "$family" "$sddm_dependency"))
    fi
    command -v niri > /dev/null || missing+=($(dependency_packages "$family" "$niri_dependency"))
    if [[ ${#missing[@]} -gt 0 ]]; then
        if [[ -n "$family" ]] && ask "Install ${missing[*]}? (needs sudo)" y; then
            install_packages "$family" "${missing[@]}" || return 1
        else
            warn "Needs ${missing[*]}: login screen skipped"
            return 1
        fi
    fi
    command -v sddm > /dev/null && command -v sddm-greeter-qt6 > /dev/null && command -v niri > /dev/null || { warn "Install SDDM with its Qt 6 greeter and niri first"; return 1; }
    getent passwd sddm > /dev/null || { warn "The SDDM system account is missing: reinstall the sddm package"; return 1; }
    [[ ! -L "$GREETER_STATE" && ( ! -e "$GREETER_STATE" || -d "$GREETER_STATE" ) ]] || { warn "Login-screen storage must be a directory, not a symlink"; return 1; }
    niri validate -c "$resource/dots/sddm/niri.kdl" || return 1
    sudo -v || return 1

    local stage; stage="$(mktemp -d)"
    local theme_backup="" config_backup="" system_backup="" niri_bin
    local committed=false changed=false SDDM_RESTORED=false
    finish_greeter_transaction()
    {
        local result=$?
        trap - EXIT INT TERM
        if ! $committed && ! $SDDM_RESTORED && { $changed || [[ -n "$theme_backup" && -e "$theme_backup" ]]; }; then
            restore_sddm_files "$theme_backup" "$config_backup" "$system_backup" || true
        fi
        rm -rf -- "$stage"
        exit "$result"
    }
    trap finish_greeter_transaction EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    niri_bin="$(command -v niri)"
    install_native_support "$family"
    if ! prepare_greeter_theme "$resource" "$stage/theme"; then
        warn "Could not prepare the login-screen keyboard"; rm -rf "$stage"; return 1
    fi
    local config_stage="$stage/sddm.conf"
    {
        printf '[General]\nDisplayServer=wayland\n\n[Theme]\nCurrent=%s\n\n[Wayland]\n' "$NAME"
        printf 'CompositorCommand="%s" -c "%s/niri.kdl"\nEnableHiDPI=true\n' "$niri_bin" "$SDDM_THEME"
    } > "$config_stage"
    if [[ -e "$SDDM_SYSTEM_CONF" ]]; then
        if ! sudo cat "$SDDM_SYSTEM_CONF" > "$stage/system-original.conf"; then rm -rf "$stage"; return 1; fi
        awk '
            /^[[:space:]]*\[/ { section=$0; sub(/^[[:space:]]*\[/,"",section); sub(/\].*$/,"",section) }
            section == "General" && /^[[:space:]]*DisplayServer[[:space:]]*=/ { next }
            section == "Theme" && /^[[:space:]]*Current[[:space:]]*=/ { next }
            section == "Wayland" && /^[[:space:]]*(CompositorCommand|EnableHiDPI)[[:space:]]*=/ { next }
            { print }
        ' "$stage/system-original.conf" > "$stage/system.conf"
    fi
    if [[ -e "$SDDM_THEME" || -L "$SDDM_THEME" ]]; then
        theme_backup="$SDDM_THEME.bak-$STAMP-$RANDOM"
        sudo mv "$SDDM_THEME" "$theme_backup" || { rm -rf "$stage"; return 1; }
    fi
    if [[ -e "$SDDM_CONF" ]]; then
        config_backup="$SDDM_CONF.bak-$STAMP-$RANDOM"
        if ! sudo cp -a "$SDDM_CONF" "$config_backup"; then
            [[ -z "$theme_backup" ]] || sudo mv "$theme_backup" "$SDDM_THEME"
            rm -rf "$stage"; return 1
        fi
    fi
    if [[ -f "$stage/system.conf" ]] && ! cmp -s "$stage/system-original.conf" "$stage/system.conf"; then
        system_backup="$SDDM_SYSTEM_CONF.bak-$STAMP-$RANDOM"
        if ! sudo cp -L --preserve=all "$SDDM_SYSTEM_CONF" "$system_backup"; then
            restore_sddm_files "$theme_backup" "$config_backup"
            rm -rf "$stage"; return 1
        fi
    fi
    changed=true
    if ! {
        sudo mkdir -p "$SDDM_THEME" "$(dirname "$SDDM_CONF")" &&
        sudo cp -a "$stage/theme/." "$SDDM_THEME/" &&
        sudo chown -R root:root "$SDDM_THEME" &&
        sudo chmod -R a+rX,go-w "$SDDM_THEME" &&
        sudo install -d -m 2755 -o "$USER" -g sddm "$GREETER_STATE" &&
        python3 "$PACKAGE/scripts/bloodyShell" internal greeter-settings "$CONFIG_HOME/$NAME/settings.json" "$GREETER_STATE" --initialize-wallpaper &&
        sudo install -m 644 "$config_stage" "$SDDM_CONF" &&
        { [[ -z "$system_backup" ]] || sudo tee "$SDDM_SYSTEM_CONF" < "$stage/system.conf" > /dev/null; };
    }; then
        restore_sddm_files "$theme_backup" "$config_backup" "$system_backup"
        rm -rf "$stage"; return 1
    fi
    rm -rf "$stage"
    ok "SDDM theme → $(hl "$SDDM_THEME")"
    ok "Wayland login screen uses its own niri configuration"
    [[ -z "$theme_backup" ]] || info "Previous theme → $(hl "$theme_backup")"
    [[ -z "$config_backup" ]] || info "Previous configuration → $(hl "$config_backup")"
    [[ -z "$system_backup" ]] || info "Managed login options moved to $SDDM_CONF (backup: $system_backup)"

    local current previous
    current="$(systemctl show --property=Id --value display-manager.service 2>/dev/null || true)"
    if [[ "$current" == sddm.service ]] && systemctl is-enabled --quiet sddm.service 2> /dev/null; then
        ok "SDDM is already enabled; the running session is unchanged"
        committed=true
        discard_sddm_backups "$theme_backup" "$config_backup" "$system_backup"
        return
    fi
    previous="$current"
    [[ "$previous" =~ ^[A-Za-z0-9@_.-]+[.]service$ && "$previous" != sddm.service && "$previous" != display-manager.service ]] || previous=""
    if ask "Use SDDM from the next boot${previous:+ (replaces $previous)}?" y; then
        if [[ -n "$previous" ]] && ! sudo systemctl disable "$previous"; then
            restore_sddm_files "$theme_backup" "$config_backup" "$system_backup"; return 1
        fi
        if ! sudo systemctl enable sddm.service; then
            sudo systemctl disable sddm.service || true
            if [[ -n "$previous" ]] && ! sudo systemctl enable "$previous"; then
                warn "Could not re-enable $previous; restore it with sudo systemctl enable $previous"
            fi
            restore_sddm_files "$theme_backup" "$config_backup" "$system_backup"
            warn "Could not enable SDDM; theme configuration was rolled back"
            return 1
        fi
        ok "SDDM will be used after a reboot"
    else
        info "Theme installed; login manager unchanged"
    fi
    committed=true
    discard_sddm_backups "$theme_backup" "$config_backup" "$system_backup"
)


if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    apply_greeter
fi
