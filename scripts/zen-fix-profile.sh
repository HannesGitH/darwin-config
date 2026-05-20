#!/usr/bin/env bash
#
# zen-fix-profile.sh
#
# Re-point Zen at a previous profile after a Nix rebuild orphaned it.
#
# Background: Firefox/Zen derive an "install hash" from their on-disk
# path. Every Nix rebuild produces a fresh /nix/store path for Zen, so
# Zen treats each rebuild as a brand-new install and silently creates
# an empty "Default (release)-N" profile, leaving your real profile
# (logins, history, sessions, extensions) untouched but unselected.
#
# This script lists the profiles in ~/Library/Application Support/zen,
# lets you pick one, and rewrites installs.ini / profiles.ini so every
# known install hash points at the profile you picked. Originals are
# backed up first.
#
# Usage:
#   scripts/zen-fix-profile.sh            # interactive
#   scripts/zen-fix-profile.sh --list     # just list profiles
#   scripts/zen-fix-profile.sh --profile 'gzdm5hnf.Default (release)-1'
#   scripts/zen-fix-profile.sh -h         # help

set -euo pipefail

ZEN_DIR="${HOME}/Library/Application Support/zen"
INSTALLS_INI="${ZEN_DIR}/installs.ini"
PROFILES_INI="${ZEN_DIR}/profiles.ini"
PROFILES_DIR="${ZEN_DIR}/Profiles"

usage() {
    sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

list_only=0
chosen_basename=""

while (( $# > 0 )); do
    case "$1" in
        -h|--help) usage 0 ;;
        --list) list_only=1; shift ;;
        --profile)
            shift
            [[ $# -gt 0 ]] || { echo "error: --profile needs a value" >&2; exit 2; }
            chosen_basename="$1"; shift ;;
        *) echo "error: unknown arg: $1" >&2; usage 2 ;;
    esac
done

[[ -f "$INSTALLS_INI" ]] || { echo "error: $INSTALLS_INI not found" >&2; exit 1; }
[[ -f "$PROFILES_INI" ]] || { echo "error: $PROFILES_INI not found" >&2; exit 1; }
[[ -d "$PROFILES_DIR" ]] || { echo "error: $PROFILES_DIR not found" >&2; exit 1; }

if pgrep -xq zen 2>/dev/null || pgrep -xq Zen 2>/dev/null; then
    echo "error: Zen appears to be running. Quit it first." >&2
    exit 1
fi

# Collect profile directories, newest mtime first.
# Use NUL-delimited I/O so spaces in names (e.g. "Default (release)") survive.
profile_paths=()
while IFS= read -r -d '' line; do
    profile_paths+=("${line#* }")
done < <(
    /usr/bin/find "$PROFILES_DIR" -mindepth 1 -maxdepth 1 -type d -print0 \
    | xargs -0 stat -f '%m %N' \
    | sort -rn \
    | tr '\n' '\0'
)

if (( ${#profile_paths[@]} == 0 )); then
    echo "error: no profile directories in $PROFILES_DIR" >&2
    exit 1
fi

print_table() {
    printf '  %-4s %-46s %-17s %-8s %-7s %-9s\n' \
        '#' 'profile' 'modified' 'files' 'logins' 'sessions'
    local i=0
    for p in "${profile_paths[@]}"; do
        local bn mtime files has_logins has_sessions
        bn=$(basename "$p")
        mtime=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$p")
        files=$(/usr/bin/find "$p" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')
        has_logins=no
        [[ -f "$p/logins.json" || -f "$p/key4.db" ]] && has_logins=yes
        has_sessions=no
        [[ -d "$p/sessionstore-backups" ]] && has_sessions=yes
        printf '  [%-2d] %-46s %-17s %-8s %-7s %-9s\n' \
            "$i" "$bn" "$mtime" "$files" "$has_logins" "$has_sessions"
        i=$((i + 1))
    done
}

echo "Zen profiles in $PROFILES_DIR (newest first):"
echo
print_table
echo

if (( list_only )); then
    exit 0
fi

# Resolve the chosen profile basename to an index in profile_paths.
chosen_index=-1
if [[ -n "$chosen_basename" ]]; then
    for i in "${!profile_paths[@]}"; do
        if [[ "$(basename "${profile_paths[$i]}")" == "$chosen_basename" ]]; then
            chosen_index=$i
            break
        fi
    done
    if (( chosen_index < 0 )); then
        echo "error: no profile named '$chosen_basename'" >&2
        exit 1
    fi
else
    read -r -p "Pick profile number (q to quit): " choice
    [[ "$choice" =~ ^[qQ]$ ]] && exit 0
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 0 || choice >= ${#profile_paths[@]} )); then
        echo "error: invalid choice" >&2
        exit 1
    fi
    chosen_index=$choice
    chosen_basename=$(basename "${profile_paths[$chosen_index]}")
fi

chosen_rel="Profiles/${chosen_basename}"
echo
echo "Selected: $chosen_rel"

stamp=$(date +%Y%m%d-%H%M%S)
cp "$INSTALLS_INI" "${INSTALLS_INI}.bak.${stamp}"
cp "$PROFILES_INI" "${PROFILES_INI}.bak.${stamp}"
echo "Backups:"
echo "  ${INSTALLS_INI}.bak.${stamp}"
echo "  ${PROFILES_INI}.bak.${stamp}"

# Rewrite installs.ini: for every [<hash>] section, force
#   Default=<chosen_rel>
#   Locked=1
awk -v chosen="$chosen_rel" '
    /^\[/                  { in_section = 1; print; next }
    in_section && /^Default[[:space:]]*=/ { print "Default=" chosen; next }
    in_section && /^Locked[[:space:]]*=/  { print "Locked=1"; next }
                           { print }
' "$INSTALLS_INI" > "${INSTALLS_INI}.tmp"
mv "${INSTALLS_INI}.tmp" "$INSTALLS_INI"

# Rewrite profiles.ini:
#  - exactly the chosen [ProfileN] gets Default=1; strip it from others
#  - every [Install*] section gets Default=<chosen_rel> and Locked=1
#    (Firefox/Zen duplicates installs.ini's contents here, so we have
#    to keep them in sync or the fix won't stick.)
awk -v chosen="$chosen_rel" '
    function flush(   i, j, placed) {
        if (n == 0) return
        if (header ~ /^\[Profile[0-9]+\]$/) {
            # Drop any existing Default= line.
            j = 0
            for (i = 1; i <= n; i++) {
                if (buf[i] !~ /^Default[[:space:]]*=/) buf[++j] = buf[i]
            }
            n = j
            if (is_chosen) {
                placed = 0
                for (i = 1; i <= n; i++) {
                    print buf[i]
                    if (!placed && buf[i] ~ /^Path[[:space:]]*=/) {
                        print "Default=1"
                        placed = 1
                    }
                }
                if (!placed) print "Default=1"
            } else {
                for (i = 1; i <= n; i++) print buf[i]
            }
        } else if (header ~ /^\[Install[0-9A-Fa-f]+\]$/) {
            for (i = 1; i <= n; i++) {
                if (buf[i] ~ /^Default[[:space:]]*=/) {
                    print "Default=" chosen
                } else if (buf[i] ~ /^Locked[[:space:]]*=/) {
                    print "Locked=1"
                } else {
                    print buf[i]
                }
            }
        } else {
            for (i = 1; i <= n; i++) print buf[i]
        }
        n = 0
        is_chosen = 0
    }
    /^\[/ {
        flush()
        header = $0
        buf[++n] = $0
        next
    }
    {
        if (n == 0) { print; next }
        buf[++n] = $0
        if ($0 ~ /^Path[[:space:]]*=/) {
            val = $0
            sub(/^Path[[:space:]]*=[[:space:]]*/, "", val)
            if (val == chosen) is_chosen = 1
        }
    }
    END { flush() }
' "$PROFILES_INI" > "${PROFILES_INI}.tmp"
mv "${PROFILES_INI}.tmp" "$PROFILES_INI"

echo
echo "Done. Launch Zen and it should open: ${chosen_basename}"
echo "If anything looks wrong, restore from the .bak.${stamp} files above."
