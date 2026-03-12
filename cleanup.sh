#!/usr/bin/env bash
# =============================================================================
#  mac-cleanup — Free up disk space on macOS
#  https://github.com/17-jd/mac-cleanup
# =============================================================================

set -uo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
print_header() {
  echo ""
  echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${CYAN}║          🧹  Mac Cleanup Tool  🧹                ║${RESET}"
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${RESET}"
  echo ""
}

section()  { echo -e "\n${BOLD}${CYAN}▶ $1${RESET}"; }
info()     { echo -e "  ${DIM}$1${RESET}"; }
success()  { echo -e "  ${GREEN}✔ $1${RESET}"; }
skipped()  { echo -e "  ${YELLOW}⏭  Skipped${RESET}"; }
warn()     { echo -e "  ${YELLOW}⚠  $1${RESET}"; }
separator(){ echo -e "${DIM}────────────────────────────────────────────────────${RESET}"; }

# Get human-readable size of a path (returns "0B" if missing)
dir_size() {
  local path="$1"
  if [ -e "$path" ]; then
    /usr/bin/du -sh "$path" 2>/dev/null | /usr/bin/awk '{print $1}'
  else
    echo "0B"
  fi
}

# Ask yes/no; returns 0 for yes, 1 for no
ask() {
  local prompt="$1"
  if [ "${AUTO_YES}" = "1" ]; then return 0; fi
  echo -en "  ${BOLD}$prompt [y/N]: ${RESET}"
  read -r reply
  if [[ "$reply" =~ ^[Yy]$ ]]; then return 0; else return 1; fi
}

# Safe delete — skips if path doesn't exist
safe_rm() {
  local path="$1"
  if [ -e "$path" ]; then
    /bin/rm -rf "$path"
  fi
}

# Free space in GB (integer)
free_space_gb() {
  df -g / 2>/dev/null | /usr/bin/awk 'NR==2{print $4}'
}

BEFORE_FREE=$(free_space_gb)

# ── Parse flags ───────────────────────────────────────────────────────────────
DRY_RUN=0
AUTO_YES=0
SCAN_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY_RUN=1 ;;
    --yes|-y)     AUTO_YES=1 ;;
    --scan)       SCAN_ONLY=1 ;;
    --help|-h)
      echo "Usage: ./cleanup.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --scan      Just show what would be cleaned (no deletes)"
      echo "  --dry-run   Same as --scan"
      echo "  --yes, -y   Auto-confirm all deletions (no prompts)"
      echo "  --help      Show this help"
      exit 0
      ;;
  esac
done

if [ "$DRY_RUN" = "1" ]; then SCAN_ONLY=1; fi

# ── Main ──────────────────────────────────────────────────────────────────────
print_header

echo -e "  Disk: $(df -h / | /usr/bin/awk 'NR==2{print "Used "$3" / "$2"  |  Free "$4}')"
if [ "$SCAN_ONLY" = "1" ]; then
  echo -e "  Mode: ${YELLOW}Scan only (no files deleted)${RESET}"
else
  echo -e "  Mode: ${GREEN}Interactive cleanup${RESET}"
fi
separator

# ─────────────────────────────────────────────────────────────────────────────
# 1. SYSTEM / APP CACHES
# ─────────────────────────────────────────────────────────────────────────────
section "App & System Caches  ~/Library/Caches"

CACHE_DIRS=(
  "Google/Chrome"
  "com.google.Chrome"
  "Firefox"
  "com.apple.Safari"
  "com.brave.Browser"
  "Yarn"
  "pip"
  "Homebrew"
  "node-gyp"
  "typescript"
  "JetBrains"
  "com.apple.python"
  "com.spotify.client"
  "Comet"
  "ru.keepcoder.Telegram"
  "com.tinyspeck.slackmacgap.ShipIt"
  "com.todesktop.230313mzl4w4u92.ShipIt"
  "ms-playwright"
  "com.microsoft.VSCode"
  "com.apple.dt.Xcode"
)

CACHE_ROOT="$HOME/Library/Caches"
FOUND_CACHES=()

for dir in "${CACHE_DIRS[@]}"; do
  full="$CACHE_ROOT/$dir"
  if [ -e "$full" ]; then
    sz=$(dir_size "$full")
    info "$sz  $dir"
    FOUND_CACHES+=("$full")
  fi
done

# Also scan for any large unknown caches (>100MB) not already listed
while IFS= read -r p; do
  already=0
  for f in "${FOUND_CACHES[@]+"${FOUND_CACHES[@]}"}"; do
    if [ "$f" = "$p" ]; then already=1; break; fi
  done
  if [ "$already" = "0" ]; then
    sz=$(dir_size "$p")
    info "$sz  (other) $(basename "$p")"
    FOUND_CACHES+=("$p")
  fi
done < <(/usr/bin/find "$CACHE_ROOT" -maxdepth 1 -mindepth 1 -size +100000k 2>/dev/null)

if [ ${#FOUND_CACHES[@]} -gt 0 ]; then
  if [ "$SCAN_ONLY" = "1" ]; then
    info "(scan only — not deleted)"
  elif ask "Delete all listed caches?"; then
    for f in "${FOUND_CACHES[@]}"; do safe_rm "$f"; done
    success "Caches cleared"
  else
    skipped
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# 2. HOMEBREW
# ─────────────────────────────────────────────────────────────────────────────
section "Homebrew"

if command -v brew &>/dev/null; then
  sz=$(dir_size "$(brew --cache)")
  info "$sz  Homebrew download cache"
  if [ "$SCAN_ONLY" = "1" ]; then
    info "(scan only — not deleted)"
  elif ask "Run 'brew cleanup --prune=all'?"; then
    brew cleanup --prune=all -q 2>/dev/null
    success "Homebrew cleaned"
  else
    skipped
  fi
else
  info "Homebrew not installed — skipping"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 3. XCODE
# ─────────────────────────────────────────────────────────────────────────────
section "Xcode Derived Data & Archives"

XCODE_PATHS=(
  "$HOME/Library/Developer/Xcode/DerivedData"
  "$HOME/Library/Developer/Xcode/Archives"
  "$HOME/Library/Developer/Xcode/iOS DeviceSupport"
  "$HOME/Library/Developer/CoreSimulator/Caches"
)

xcode_found=0
for p in "${XCODE_PATHS[@]}"; do
  if [ -e "$p" ]; then
    info "$(dir_size "$p")  $p"
    xcode_found=1
  fi
done

if [ "$xcode_found" = "1" ]; then
  if [ "$SCAN_ONLY" = "1" ]; then
    info "(scan only — not deleted)"
  elif ask "Delete Xcode derived data, device support & sim caches?"; then
    for p in "${XCODE_PATHS[@]}"; do safe_rm "$p"; done
    success "Xcode junk removed"
  else
    skipped
  fi
else
  info "Nothing found"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 4. DOCKER
# ─────────────────────────────────────────────────────────────────────────────
section "Docker"

if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  info "Docker is running — checking reclaimable space..."
  if [ "$SCAN_ONLY" = "1" ]; then
    docker system df 2>/dev/null || true
    info "(scan only — not deleted)"
  elif ask "Run 'docker system prune -f'?"; then
    docker system prune -f
    success "Docker pruned"
  else
    skipped
  fi
else
  info "Docker not running — skipping"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 5. ORPHANED NODE_MODULES
# ─────────────────────────────────────────────────────────────────────────────
section "Orphaned node_modules (no package.json nearby)"

NODE_PATHS=()

while IFS= read -r nm; do
  parent=$(dirname "$nm")
  if [ ! -f "$parent/package.json" ]; then
    sz=$(dir_size "$nm")
    info "$sz  $nm ${RED}(no package.json — likely orphaned)${RESET}"
    NODE_PATHS+=("$nm")
  fi
done < <(/usr/bin/find "$HOME" \
  -path "$HOME/Library" -prune -o \
  -name "node_modules" -type d -prune -print 2>/dev/null | head -30)

if [ ${#NODE_PATHS[@]} -gt 0 ]; then
  if [ "$SCAN_ONLY" = "1" ]; then
    info "(scan only — not deleted)"
  elif ask "Delete orphaned node_modules?"; then
    for p in "${NODE_PATHS[@]}"; do safe_rm "$p"; done
    success "Orphaned node_modules removed"
  else
    skipped
  fi
else
  info "None found"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 6. TELEGRAM MEDIA CACHE
# ─────────────────────────────────────────────────────────────────────────────
section "Telegram Media Cache"

TELEGRAM_BASE="$HOME/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram"

if [ -d "$TELEGRAM_BASE" ]; then
  while IFS= read -r media_dir; do
    sz=$(dir_size "$media_dir")
    info "$sz  Telegram media cache"
    if [ "$SCAN_ONLY" = "1" ]; then
      info "(scan only — not deleted)"
    elif ask "Clear Telegram media cache? (re-downloads if you open them again)"; then
      /bin/rm -rf "${media_dir:?}"/*
      success "Telegram media cleared"
    else
      skipped
    fi
  done < <(/usr/bin/find "$TELEGRAM_BASE" -type d -name "media" 2>/dev/null)
else
  info "Telegram not installed — skipping"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 7. TRASH
# ─────────────────────────────────────────────────────────────────────────────
section "Trash"

TRASH="$HOME/.Trash"
sz=$(dir_size "$TRASH")

if [ "$sz" != "0B" ]; then
  info "$sz  in Trash"
  if [ "$SCAN_ONLY" = "1" ]; then
    info "(scan only — not deleted)"
  elif ask "Empty Trash?"; then
    /bin/rm -rf "${TRASH:?}"/* 2>/dev/null || true
    success "Trash emptied"
  else
    skipped
  fi
else
  info "Trash is already empty"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 8. LARGE FILES SCAN (>500 MB) — display only, never auto-deleted
# ─────────────────────────────────────────────────────────────────────────────
section "Large files >500 MB  (videos, ISOs, DMGs, archives)"

echo ""
LARGE_FILES=$(/usr/bin/find "$HOME" \
  -path "$HOME/Library/Group Containers/UBF8T346G9*" -prune -o \
  -path "$HOME/Library/CloudStorage" -prune -o \
  -size +500000k -type f \
  \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.avi" \
     -o -iname "*.iso" -o -iname "*.vmdk" -o -iname "*.vdi" -o -iname "*.ova" \
     -o -iname "*.dmg" -o -iname "*.pkg" -o -iname "*.zip" \
     -o -iname "*.tar.gz" -o -iname "*.tar" \) \
  -print 2>/dev/null)

if [ -n "$LARGE_FILES" ]; then
  echo "$LARGE_FILES" | while read -r f; do
    /usr/bin/du -sh "$f" 2>/dev/null
  done | sort -rh | head -20
  echo ""
  warn "These are NOT auto-deleted — review and remove manually."
else
  info "No large files found (>500 MB)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 9. LOGS
# ─────────────────────────────────────────────────────────────────────────────
section "User Log Files"

LOG_DIR="$HOME/Library/Logs"
if [ -e "$LOG_DIR" ]; then
  sz=$(dir_size "$LOG_DIR")
  info "$sz  $LOG_DIR"
  if [ "$SCAN_ONLY" = "1" ]; then
    info "(scan only — not deleted)"
  elif ask "Clear user logs?"; then
    /usr/bin/find "$LOG_DIR" -type f -name "*.log" -delete 2>/dev/null || true
    success "Logs cleared"
  else
    skipped
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
separator
echo ""
AFTER_FREE=$(free_space_gb)
FREED=$(( AFTER_FREE - BEFORE_FREE ))

echo -e "${BOLD}${GREEN}  ✔ Cleanup complete!${RESET}"
echo ""
if [ "$SCAN_ONLY" = "0" ]; then
  echo -e "  Free space before : ${RED}${BEFORE_FREE} GB${RESET}"
  echo -e "  Free space after  : ${GREEN}${AFTER_FREE} GB${RESET}"
  if [ "$FREED" -gt 0 ]; then
    echo -e "  ${BOLD}${GREEN}  ≈ ${FREED} GB freed 🎉${RESET}"
  fi
fi
echo ""
