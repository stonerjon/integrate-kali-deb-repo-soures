#!/usr/bin/env bash
#
# integrate-kali-repo.sh
#
# Safely integrate Kali Rolling repositories into a Debian system
# with proper pinning to avoid accidental package upgrades.
# Linted for ShellCheck and with robust error handling.
#

set -euo pipefail
IFS=$'\n\t'

#----------------------------#
#   Configuration Variables  #
#----------------------------#

# URL of Kali Rolling repository
KALI_REPO_DEB="deb http://http.kali.org/kali kali-rolling main non-free contrib"
KALI_REPO_SRC="deb-src http://http.kali.org/kali kali-rolling main non-free contrib"

# Paths
SOURCES_LIST="/etc/apt/sources.list.d/kali.list"
PREFERENCES_FILE="/etc/apt/preferences.d/kali.pref"
BACKUP_DIR="/etc/apt/backups/$(date +%F_%T)"
KEY_URL="https://archive.kali.org/archive-key.asc"
KEY_FILE="/tmp/kali-archive-key.asc"

#----------------------------#
#       Helper Functions     #
#----------------------------#

# Print to stderr
err() {
  printf "ERROR: %s\n" "$*" >&2
}

# Print informational messages
info() {
  printf "→ %s\n" "$*"
}

# Ensure script is run as root
require_root() {
  if [ "$EUID" -ne 0 ]; then
    err "This script must be run as root or via sudo."
    exit 1
  fi
}

# Create backup of existing apt files
backup_configs() {
  info "Backing up existing APT configs to $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"
  cp /etc/apt/sources.list* "$BACKUP_DIR" 2>/dev/null || true \
  
  cp /etc/apt/preferences.d/* "$BACKUP_DIR" 2>/dev/null || true
}

# Add Kali entries to sources list
add_kali_repos() {
  info "Writing Kali repository entries to $SOURCES_LIST"
  cat > "$SOURCES_LIST" <<EOF
# Kali Rolling repository (managed by integrate-kali-repo.sh)
$KALI_REPO_DEB
$KALI_REPO_SRC
EOF
}

# Import and trust Kali archive key
import_kali_key() {
  info "Downloading Kali archive key..."
  curl -fsSL "$KEY_URL" -o "$KEY_FILE"
  info "Adding Kali archive key to apt keyring"
  apt-key add "$KEY_FILE" >/dev/null
  rm -f "$KEY_FILE"
}

# Create apt pinning preferences
create_pinning() {
  info "Creating pinning file $PREFERENCES_FILE"
  cat > "$PREFERENCES_FILE" <<EOF
# Lower priority for all Kali Rolling packages
Package: *
Pin: release a=kali-rolling
Pin-Priority: 50
EOF
}

# Update package lists
update_packages() {
  info "Updating package lists (this may take a moment)..."
  apt-get update -qq
  info "APT update complete."
}

# Main execution flow
main() {
  require_root
  backup_configs
  add_kali_repos
  import_kali_key
  create_pinning
  update_packages

  info "Kali Rolling repositories integrated successfully."
  info "To install a package from Kali, use: apt-get install -t kali-rolling <package>"
}

# Entry point
main "$@"
