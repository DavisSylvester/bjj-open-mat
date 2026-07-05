#!/usr/bin/env bash
#
# mac-bootstrap.sh — one-shot, idempotent setup of the iOS build toolchain on a Mac.
#
# Prepares a macOS machine (e.g. the Mac Studio) to build/run this Flutter app for iOS:
#   1. Accept the Xcode license
#   2. Install Xcode's additional components (first-launch)
#   3. Point xcode-select at the full Xcode (not just Command Line Tools)
#   4. Ensure Flutter is new enough (this app needs Dart >= 3.7) — upgrade if not
#   5. (Re)install a working CocoaPods via Homebrew
#   6. flutter pub get + pod install for apps/mobile
#   7. Print flutter doctor
#
# Safe to re-run. Prompts for your password on the sudo steps.
#
# Usage:
#   bash scripts/mac-bootstrap.sh
#   SKIP_FLUTTER_UPGRADE=1 bash scripts/mac-bootstrap.sh   # skip the (slow) flutter upgrade
#   SKIP_DEPS=1            bash scripts/mac-bootstrap.sh   # skip pub get / pod install
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MOBILE_DIR="$REPO_ROOT/apps/mobile"
REQUIRED_DART_MAJOR=3
REQUIRED_DART_MINOR=7

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m   ✓ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m   ! %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m   ✗ %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "This script is for macOS only."

# ── 0. Preconditions ────────────────────────────────────────────────────────
command -v flutter >/dev/null 2>&1 || die "Flutter not found on PATH. Install the Flutter SDK first."
[ -d /Applications/Xcode.app ] || die "/Applications/Xcode.app not found. Install Xcode from the App Store first."

# ── 1. Xcode license ─────────────────────────────────────────────────────────
log "Accepting the Xcode license (sudo)"
sudo xcodebuild -license accept
ok "Xcode license accepted"

# ── 2. Xcode first-launch components ──────────────────────────────────────────
log "Installing Xcode additional components (sudo)"
sudo xcodebuild -runFirstLaunch
ok "Xcode components installed"

# ── 3. xcode-select points at full Xcode ──────────────────────────────────────
log "Verifying active developer directory"
CURRENT_DEV_DIR="$(xcode-select -p 2>/dev/null || true)"
if [[ "$CURRENT_DEV_DIR" != *"/Xcode.app/"* ]]; then
  warn "xcode-select points at '$CURRENT_DEV_DIR' — switching to full Xcode (sudo)"
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
fi
ok "Developer dir: $(xcode-select -p)"

# ── 4. Flutter version (Dart >= 3.7) ───────────────────────────────────────────
log "Checking Flutter / Dart version"
dart_ver="$(dart --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
if [ -z "$dart_ver" ]; then
  warn "Could not detect the Dart version; will attempt an upgrade."
  dart_major=0; dart_minor=0
else
  dart_major="${dart_ver%%.*}"; rest="${dart_ver#*.}"; dart_minor="${rest%%.*}"
fi
needs_upgrade=0
if (( dart_major < REQUIRED_DART_MAJOR )) || \
   (( dart_major == REQUIRED_DART_MAJOR && dart_minor < REQUIRED_DART_MINOR )); then
  needs_upgrade=1
fi

if (( needs_upgrade == 1 )); then
  if [ "${SKIP_FLUTTER_UPGRADE:-0}" = "1" ]; then
    die "Dart ${dart_ver:-unknown} < ${REQUIRED_DART_MAJOR}.${REQUIRED_DART_MINOR} but SKIP_FLUTTER_UPGRADE=1. Run 'flutter upgrade' manually."
  fi
  warn "Dart ${dart_ver:-unknown} is older than required ${REQUIRED_DART_MAJOR}.${REQUIRED_DART_MINOR} — upgrading Flutter (this can take a few minutes)"
  flutter upgrade
  ok "Flutter upgraded to $(flutter --version | head -1)"
else
  ok "Dart $dart_ver satisfies >= ${REQUIRED_DART_MAJOR}.${REQUIRED_DART_MINOR}"
fi

# ── 5. CocoaPods via Homebrew ──────────────────────────────────────────────────
log "Ensuring a working CocoaPods"
if pod --version >/dev/null 2>&1; then
  ok "CocoaPods $(pod --version) is working"
else
  warn "CocoaPods missing or broken — installing via Homebrew"
  command -v brew >/dev/null 2>&1 || die "Homebrew not found. Install it from https://brew.sh then re-run this script."
  brew install cocoapods || brew reinstall cocoapods
  brew link --overwrite cocoapods 2>/dev/null || true
  pod --version >/dev/null 2>&1 || die "CocoaPods still not working after Homebrew install. See https://guides.cocoapods.org/using/getting-started.html"
  ok "CocoaPods $(pod --version) installed"
fi

# ── 6. Project dependencies ────────────────────────────────────────────────────
if [ "${SKIP_DEPS:-0}" = "1" ]; then
  warn "SKIP_DEPS=1 — skipping flutter pub get / pod install"
else
  log "Fetching Flutter packages (apps/mobile)"
  ( cd "$MOBILE_DIR" && flutter pub get )
  ok "flutter pub get done"

  log "Installing CocoaPods for the iOS runner"
  ( cd "$MOBILE_DIR/ios" && pod install )
  ok "pod install done"
fi

# ── 7. Final doctor ─────────────────────────────────────────────────────────────
log "flutter doctor"
flutter doctor

log "Bootstrap complete. Next: capture screenshots per docs/ios/RESUME-ON-MAC.md"
