#!/usr/bin/env bash

set -euo pipefail

readonly SCHEMA="org.gnome.desktop.interface"
readonly CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly QT6CT="$CONFIG_HOME/qt6ct/qt6ct.conf"

fail() { printf '%s\n' "$*" >&2; exit 1; }

gget() { gsettings get "$SCHEMA" "$1" 2>/dev/null | sed -E "s/^uint32 //; s/^'(.*)'$/\1/"; }
gset() { gsettings set "$SCHEMA" "$1" "$2" || fail "gsettings could not set $1"; }

ini_set()
{
    local file="$1" section="$2" key="$3" value="$4"
    [[ ! -L "$file" ]] || file="$(readlink -m -- "$file")"
    mkdir -p "$(dirname "$file")"
    [[ -f "$file" ]] || : > "$file"

    local tmp; tmp="$(mktemp "$file.XXXXXX")"
    awk -v sec="[$section]" -v k="$key" -v v="$value" '
        BEGIN { inside = 0; seen = 0; done = 0; blanks = "" }
        /^[ \t]*$/ { blanks = blanks $0 "\n"; next }
        /^\[/ {
            if (inside && !done) { print k "=" v; done = 1 }
            inside = ($0 == sec); if (inside) seen = 1
        }
        inside && index($0, k "=") == 1 { printf "%s", blanks; blanks = ""; if (!done) print k "=" v; done = 1; next }
        { printf "%s", blanks; blanks = ""; print }
        END {
            if (!done) { if (!seen) print sec; print k "=" v }
            printf "%s", blanks
        }' "$file" > "$tmp"
    chmod --reference="$file" "$tmp"
    mv -f -- "$tmp" "$file"
}

cmd_list()
{
    local dir theme
    for dir in /usr/share/icons "$HOME/.icons" "$DATA_HOME/icons"; do
        for theme in "$dir"/*/; do
            local name; name="$(basename "$theme")"
            [[ "$name" == "default" ]] && continue
            [[ -d "${theme}cursors" ]] && printf 'cursor\t%s\n' "$name"
            [[ -f "${theme}index.theme" ]] && grep -q '^Directories=' "${theme}index.theme" && printf 'icon\t%s\n' "$name"
        done
    done
    if command -v fc-list > /dev/null; then
        fc-list : family 2>/dev/null | cut -d, -f1 | sed 's/^ *//; s/ *$//' | grep -v '^$' | sed 's/^/font\t/'
    fi
}

cmd_read()
{
    command -v gsettings > /dev/null || fail "gsettings is not installed"
    printf 'color-scheme=%s\n' "$(gget color-scheme)"
    printf 'icon-theme=%s\n'   "$(gget icon-theme)"
    printf 'cursor-theme=%s\n' "$(gget cursor-theme)"
    printf 'cursor-size=%s\n'  "$(gget cursor-size)"
    printf 'font=%s\n'         "$(gget font-name)"
}

write_color_scheme()
{
    local scheme="$1" dark=false
    [[ "$scheme" == "prefer-dark" ]] && dark=true
    gset color-scheme "$scheme"
    ini_set "$CONFIG_HOME/gtk-3.0/settings.ini" Settings gtk-application-prefer-dark-theme "$dark"
    ini_set "$CONFIG_HOME/gtk-4.0/settings.ini" Settings gtk-interface-color-scheme "$scheme"

    local palette=/usr/share/qt6ct/colors/darker.conf
    if $dark && [[ -f "$palette" ]]; then
        ini_set "$QT6CT" Appearance custom_palette true
        ini_set "$QT6CT" Appearance color_scheme_path "$palette"
    else
        ini_set "$QT6CT" Appearance custom_palette false
    fi
}

write_icon_theme()
{
    gset icon-theme "$1"
    ini_set "$CONFIG_HOME/gtk-3.0/settings.ini" Settings gtk-icon-theme-name "$1"
    ini_set "$CONFIG_HOME/gtk-4.0/settings.ini" Settings gtk-icon-theme-name "$1"
    ini_set "$QT6CT" Appearance icon_theme "$1"
}

write_font()
{
    local font="$1"
    local size="${font##* }" family="${font% *}"
    [[ "$size" =~ ^[0-9]+([.][0-9]+)?$ ]] || { size=10; family="$font"; }

    gset font-name "$family $size"
    ini_set "$CONFIG_HOME/gtk-3.0/settings.ini" Settings gtk-font-name "$family $size"
    ini_set "$CONFIG_HOME/gtk-4.0/settings.ini" Settings gtk-font-name "$family $size"
    ini_set "$QT6CT" Fonts general "\"$family,$size,-1,5,50,0,0,0,0,0\""
}

write_cursor()
{
    local theme="$1" size="$2"
    gset cursor-theme "$theme"
    gset cursor-size "$size"
    ini_set "$CONFIG_HOME/gtk-3.0/settings.ini" Settings gtk-cursor-theme-name "$theme"
    ini_set "$CONFIG_HOME/gtk-3.0/settings.ini" Settings gtk-cursor-theme-size "$size"
    ini_set "$CONFIG_HOME/gtk-4.0/settings.ini" Settings gtk-cursor-theme-name "$theme"
    ini_set "$CONFIG_HOME/gtk-4.0/settings.ini" Settings gtk-cursor-theme-size "$size"

    mkdir -p "$DATA_HOME/icons/default"
    printf '[Icon Theme]\nName=Default\nInherits=%s\n' "$theme" > "$DATA_HOME/icons/default/index.theme"

    write_niri_cursor "$theme" "$size"
    return 0
}

write_niri_cursor()
{
    [[ -d "$CONFIG_HOME/niri/bloodyShell" ]] || return 0
    python3 -c 'import runpy,sys; a=runpy.run_path(sys.argv.pop(1)); sys.exit(a["niri_main"]())' "$(dirname "$0")/desktop.py" cursor "$1" "$2" \
        || fail "niri did not accept the cursor settings; its config was left unchanged"
}

cmd_set()
{
    command -v gsettings > /dev/null || fail "gsettings is not installed"

    local theme="" size="" cursor=false
    for pair in "$@"; do
        local key="${pair%%=*}" value="${pair#*=}"
        case "$key" in
            color-scheme) write_color_scheme "$value" ;;
            icon-theme)   write_icon_theme "$value" ;;
            font)         write_font "$value" ;;
            cursor-theme) theme="$value"; cursor=true ;;
            cursor-size)  size="$value";  cursor=true ;;
            *) fail "Unknown setting: $key" ;;
        esac
    done

    if $cursor; then
        [[ -n "$theme" ]] || theme="$(gget cursor-theme)"
        [[ -n "$size" ]] || size="$(gget cursor-size)"
        write_cursor "$theme" "$size"
    fi
}

cmd_apply()
{
    cmd_set "color-scheme=$(gget color-scheme)" "icon-theme=$(gget icon-theme)" \
            "font=$(gget font-name)" "cursor-theme=$(gget cursor-theme)" "cursor-size=$(gget cursor-size)"
}

cmd_icons()
{
    local -a bases=("$DATA_HOME/icons" "$HOME/.icons" /usr/share/icons /usr/local/share/icons)
    local -a chain=() queue=("${1:-hicolor}")
    while [[ ${#queue[@]} -gt 0 ]]; do
        local theme="${queue[0]}"; queue=("${queue[@]:1}")
        [[ " ${chain[*]} " == *" $theme "* ]] && continue
        chain+=("$theme")
        local base
        for base in "${bases[@]}"; do
            [[ -f "$base/$theme/index.theme" ]] || continue
            local inherits; inherits="$(sed -n 's/^Inherits=//p' "$base/$theme/index.theme" | head -n1)"
            IFS=',' read -ra more <<< "$inherits"
            queue+=("${more[@]}")
            break
        done
    done
    [[ " ${chain[*]} " == *" hicolor "* ]] || chain+=(hicolor)

    local i=0 theme base
    for theme in "${chain[@]}"; do
        for base in "${bases[@]}"; do
            [[ -d "$base/$theme" ]] || continue
            find -L "$base/$theme" \( -name '*.svg' -o -name '*.png' \) -type f 2>/dev/null | sed "s|^|$i\t|"
        done
        i=$((i + 1))
    done | awk -F'\t' '
        {
            path = $2; name = path; sub(/.*\//, "", name); sub(/\.(svg|png)$/, "", name)
            rank = 500
            if (path ~ /\/scalable\//) rank = 0
            else if (match(path, /\/[0-9]+(x[0-9]+)?(@[0-9]x)?\//)) { size = substr(path, RSTART + 1, RLENGTH - 2) + 0; rank = 400 - (size > 256 ? 256 : size) }
            printf "%d\t%03d\t%s\t%s\n", $1, rank, name, path
        }' | sort -t$'\t' -k1,1n -k2,2n | awk -F'\t' '!seen[$3]++ { print $3 "\t" $4 }'
}

case "${1:-}" in
    read)  cmd_read ;;
    list)  cmd_list | sort -u ;;
    icons) cmd_icons "${2:-}" ;;
    set)   shift; cmd_set "$@" ;;
    apply) cmd_apply ;;
    *) printf '%s\n' 'Usage: appearance {read|list|icons [theme]|set key=value...|apply}'; exit 1 ;;
esac
