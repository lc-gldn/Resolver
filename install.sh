#!/bin/bash

# Sony Meta Warrior macOS Installer / Auditor
# Updated binary name: resolvermac

# --- SETTINGS ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

RESOLVE_DIR="/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility"
DEST_LUA="Sony Meta Warrior.lua"
BINARY_NAME="resolvermac"
BINARY_PATH="$RESOLVE_DIR/$BINARY_NAME"

# IMPORTANT:
# This URL must point directly to the resolvermac binary file, not to a GitHub repo page.
# If this points to a repo/page, the audit will catch it as HTML/text and fail.
RESOLVER_URL="https://github.com/lc-gldn/Resolver/releases/download/resolvermac/resolvermac"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TMP_BINARY="/tmp/${BINARY_NAME}_download_$$"

# --- UI HELPERS ---
draw_line() { echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
ok() { echo -e "  $1: ${GREEN}✔ $2${NC}"; }
warn() { echo -e "  $1: ${YELLOW}⚠ $2${NC}"; }
fail() { echo -e "  $1: ${RED}✖ $2${NC}"; }

is_yes() {
    [[ "$1" =~ ^[Yy]$ || -z "$1" ]]
}

file_size() {
    if [ -f "$1" ]; then
        stat -f%z "$1" 2>/dev/null || wc -c < "$1"
    else
        echo 0
    fi
}

file_type() {
    if [ -f "$1" ]; then
        file "$1" 2>/dev/null
    else
        echo "missing"
    fi
}

is_probably_bad_download() {
    local target="$1"

    [ ! -f "$target" ] && return 0

    local size
    size=$(file_size "$target")
    if [ "$size" -lt 1024 ]; then
        return 0
    fi

    # Catch GitHub HTML, XML error pages, JSON API errors, shell text, or cloned repo redirect text.
    if head -c 256 "$target" | LC_ALL=C grep -Eiq '<!DOCTYPE html|<html|Not Found|Bad Gateway|Moved Permanently|Repository not found|^{|^#!/bin/'; then
        return 0
    fi

    return 1
}

is_macos_binary() {
    local target="$1"
    local info
    info=$(file_type "$target")

    # Accept normal Mach-O binaries. Also accept universal binaries.
    echo "$info" | grep -Eiq 'Mach-O|universal binary'
}

check_binary() {
    local target="$1"
    local label="$2"

    if [ ! -f "$target" ]; then
        fail "$label" "Missing ($target)"
        return 1
    fi

    local size info
    size=$(file_size "$target")
    info=$(file_type "$target")

    if is_probably_bad_download "$target"; then
        fail "$label" "Invalid download or too small (${size} bytes)"
        echo -e "    ${YELLOW}File type:${NC} $info"
        return 1
    fi

    if ! is_macos_binary "$target"; then
        warn "$label" "Exists, but does not look like a macOS Mach-O binary"
        echo -e "    ${YELLOW}File type:${NC} $info"
    else
        ok "$label" "Installed (${size} bytes)"
        echo -e "    ${CYAN}File type:${NC} $info"
    fi

    if [ -x "$target" ]; then
        ok "Executable" "Yes"
    else
        fail "Executable" "No"
        return 1
    fi

    return 0
}

check_lua() {
    if [ -f "$RESOLVE_DIR/$DEST_LUA" ]; then
        ok "Lua Script" "Installed ($DEST_LUA)"
        return 0
    else
        fail "Lua Script" "Missing ($DEST_LUA)"
        return 1
    fi
}

final_audit() {
    echo ""
    draw_line
    echo -e "${BOLD}Final Audit:${NC}"

    local errors=0

    if [ -d "$RESOLVE_DIR" ]; then
        ok "Utility Folder" "Found"
    else
        fail "Utility Folder" "Missing"
        errors=$((errors + 1))
    fi

    check_binary "$BINARY_PATH" "Sony Resolver Binary ($BINARY_NAME)" || errors=$((errors + 1))
    check_lua || errors=$((errors + 1))

    # Accuracy check: old binary name should not be the expected install target anymore.
    if [ -f "$RESOLVE_DIR/resolver" ]; then
        warn "Old Binary" "Found old file: resolver. Current expected binary is: $BINARY_NAME"
    else
        ok "Old Binary Check" "No old resolver file found"
    fi

    echo ""
    if [ "$errors" -eq 0 ]; then
        echo -e "${BOLD}${GREEN}✅ ALL REQUIRED CHECKS PASSED${NC}"
    else
        echo -e "${BOLD}${RED}✖ $errors REQUIRED CHECK(S) FAILED${NC}"
    fi
    draw_line

    return "$errors"
}

# --- START ---
clear
draw_line
echo -e "${BOLD}${YELLOW}          SONY META WARRIOR: UTILITY AUDIT          ${NC}"
draw_line

echo -e "\n${BOLD}Status in Resolve Utility Folder:${NC}"

[ -d "$RESOLVE_DIR" ] && ok "Utility Folder" "Found" || fail "Utility Folder" "Missing"
check_binary "$BINARY_PATH" "Sony Resolver Binary ($BINARY_NAME)"
check_lua

if [ -f "$RESOLVE_DIR/resolver" ]; then
    warn "Old Binary" "resolver exists, but this installer now uses resolvermac"
fi

# --- STEP 1: DIRECTORY ---
echo ""
draw_line
if [ ! -d "$RESOLVE_DIR" ]; then
    read -p "Utility folder is missing. Create it? [Y/N]: " dir_choice
    if is_yes "$dir_choice"; then
        if sudo mkdir -p "$RESOLVE_DIR"; then
            ok "Utility Folder" "Created"
        else
            fail "Utility Folder" "Could not create"
            final_audit
            exit 1
        fi
    else
        fail "Utility Folder" "Required folder was not created"
        final_audit
        exit 1
    fi
fi

# --- STEP 2: BINARY DOWNLOAD / UPDATE ---
read -p "Download/Update '$BINARY_NAME' from GitHub? [Y/N]: " dl_choice
if is_yes "$dl_choice"; then
    echo -e "  Downloading to temporary file first..."
    rm -f "$TMP_BINARY"

    if curl -fL --retry 2 --connect-timeout 15 "$RESOLVER_URL" -o "$TMP_BINARY"; then
        if is_probably_bad_download "$TMP_BINARY"; then
            fail "Download Check" "Downloaded file is invalid, too small, HTML/text, or not a direct binary"
            echo -e "    ${YELLOW}Downloaded file type:${NC} $(file_type "$TMP_BINARY")"
            echo -e "    ${YELLOW}Fix RESOLVER_URL so it points directly to the resolvermac binary.${NC}"
            rm -f "$TMP_BINARY"
        else
            if ! is_macos_binary "$TMP_BINARY"; then
                warn "Binary Type" "Downloaded file does not look like a macOS Mach-O binary"
                echo -e "    ${YELLOW}Downloaded file type:${NC} $(file_type "$TMP_BINARY")"
                read -p "Install it anyway? [Y/N]: " force_choice
                if ! is_yes "$force_choice"; then
                    rm -f "$TMP_BINARY"
                    fail "Install" "Cancelled"
                    final_audit
                    exit 1
                fi
            fi

            if sudo cp "$TMP_BINARY" "$BINARY_PATH" && sudo chmod 755 "$BINARY_PATH"; then
                ok "Install" "$BINARY_NAME copied to Resolve Utility folder"
                check_binary "$BINARY_PATH" "Post-Install Binary Check"
            else
                fail "Install" "Could not copy or chmod $BINARY_NAME"
            fi
            rm -f "$TMP_BINARY"
        fi
    else
        fail "Download" "curl failed"
        rm -f "$TMP_BINARY"
    fi
fi

# --- STEP 3: FIND LOCAL LUA & DEPLOY ---
LOCAL_LUA=$(find "$SCRIPT_DIR" -maxdepth 1 -type f -name "*.lua" -print -quit)

echo ""
if [ -n "$LOCAL_LUA" ]; then
    echo -e "  Found local Lua: ${CYAN}$LOCAL_LUA${NC}"
    read -p "Copy this Lua as '$DEST_LUA' to the Utility folder? [Y/N]: " lua_choice
    if is_yes "$lua_choice"; then
        if sudo cp "$LOCAL_LUA" "$RESOLVE_DIR/$DEST_LUA"; then
            ok "Lua Deploy" "Deployed as: $DEST_LUA"
        else
            fail "Lua Deploy" "Copy failed"
        fi
    fi
else
    fail "Local Lua" "No .lua file found in this installer folder"
fi

# --- FINAL AUDIT ---
final_audit
