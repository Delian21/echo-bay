#!/usr/bin/env bash
# Echo Bay — Netlify build entry point.
#
# Netlify's build image does NOT ship a Flutter SDK, so `flutter build web`
# there fails immediately with exit code 2 ("flutter: command not found").
# This script installs one pinned, checksum-verified Flutter release — the
# exact version used locally, so a Netlify build and a local build are the
# same compiler — and then runs the same build the toml used to run directly.
#
# Keep these two values in step with the local SDK
# (`cat <flutter>/bin/cache/flutter.version.json`):
#   Flutter 3.47.0 / Dart 3.13.0 / framework revision 4cf2416426
# Pinning the sha256 as well as the version means a swapped or corrupted
# upstream file fails the build instead of shipping.
#
# The SDK is kept in Netlify's persistent build cache, so only the first
# deploy after "Clear cache and deploy site" pays for the download.

set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.0}"
FLUTTER_SHA256="${FLUTTER_SHA256:-26cd99d3d94b1367e6b50535a18aeef0282c10a535bbe3ec493534dcdab75296}"
FLUTTER_ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_ARCHIVE}"

# Netlify persists this directory between builds. Overridable for local runs.
CACHE_DIR="${NETLIFY_CACHE_DIR:-/opt/build/cache}"
SDK_ROOT="${CACHE_DIR}/flutter-sdk"
# FLUTTER_SDK_DIR points the script at an SDK already on this machine, which
# is how the build path is tested without going through the download branch.
SDK_DIR="${FLUTTER_SDK_DIR:-${SDK_ROOT}/flutter}"
SDK_BIN="${SDK_DIR}/bin/flutter"
VERSION_FILE="${SDK_DIR}/bin/cache/flutter.version.json"

log() { printf '\n[netlify_build] %s\n' "$*"; }

# Cheap check that never spawns `flutter` (which is slow on a cold SDK):
# the SDK writes its own version to bin/cache/flutter.version.json.
sdk_matches() {
  [ -x "${SDK_BIN}" ] && [ -f "${VERSION_FILE}" ] &&
    grep -q "\"frameworkVersion\": \"${FLUTTER_VERSION}\"" "${VERSION_FILE}"
}

install_flutter() {
  mkdir -p "${SDK_ROOT}"
  local archive="${SDK_ROOT}/${FLUTTER_ARCHIVE}"

  if [ -f "${archive}" ] &&
    printf '%s  %s\n' "${FLUTTER_SHA256}" "${archive}" | sha256sum -c --status -; then
    log "Reusing the cached Flutter archive"
  else
    # A partial previous download must not be mistaken for a good one.
    rm -f "${archive}"
    log "Downloading Flutter ${FLUTTER_VERSION}"
    log "${FLUTTER_URL}"
    curl -fL --retry 3 --retry-delay 5 -o "${archive}" "${FLUTTER_URL}"
  fi

  log "Verifying sha256"
  printf '%s  %s\n' "${FLUTTER_SHA256}" "${archive}" | sha256sum -c -

  log "Extracting"
  local staging="${SDK_ROOT}/extract.$$"
  rm -rf "${staging}"
  mkdir -p "${staging}"
  # The archive contains a single top-level `flutter/` directory. Extract to a
  # staging dir and move into place, so a killed build can never leave a
  # half-unpacked SDK behind for the next one to trust.
  tar -xJf "${archive}" -C "${staging}"
  rm -rf "${SDK_DIR}"
  mv "${staging}/flutter" "${SDK_DIR}"
  rmdir "${staging}" 2>/dev/null || true

  # The extracted SDK is what future builds reuse; the tarball would double the
  # cache footprint to no purpose.
  rm -f "${archive}"

  [ -x "${SDK_BIN}" ] || {
    log "Extraction finished but ${SDK_BIN} is missing"
    return 1
  }
}

if sdk_matches; then
  log "Using cached Flutter ${FLUTTER_VERSION} at ${SDK_DIR}"
else
  log "Flutter ${FLUTTER_VERSION} is not cached (or is a different version)"
  install_flutter
  sdk_matches || {
    log "The installed SDK does not report ${FLUTTER_VERSION}; refusing to build"
    exit 1
  }
fi

export PATH="${SDK_DIR}/bin:${PATH}"

# Keep the pub cache beside the SDK so it is cached between Netlify builds too.
# Skipped when the SDK root is read-only (a local run pointed at an installed
# SDK), where the normal pub cache is the right place.
if [ -w "${SDK_ROOT}" ]; then
  export PUB_CACHE="${SDK_ROOT}/pub-cache"
fi

# Flutter ships as a git checkout. Inside CI containers git can refuse it with
# "detected dubious ownership", which makes every flutter command fail with an
# opaque error — cheap to prevent.
git config --global --add safe.directory "${SDK_DIR}" 2>/dev/null || true

log "Flutter version"
flutter --version

# There is nobody to answer the first-run analytics prompt on CI.
flutter --disable-analytics >/dev/null 2>&1 || true

log "Enabling web"
flutter config --enable-web

log "Resolving packages"
flutter pub get

# --no-wasm-dry-run: the WASM dry run compiles a second target (dart2wasm)
#   alongside dart2js and OOMs Netlify's build instances (exit code 2). This
#   app targets dart2js only; the dry run buys nothing here.
# --build-number: this is what makes version.json differ between deploys. The
#   version checker only offers the "a new page was inked" refresh banner when
#   it changes, and pubspec's version is constant — strip this and the feature
#   silently dies.
log "Building web release"
flutter build web --release --no-wasm-dry-run --build-number="$(date +%s)"

log "Build output in build/web:"
ls -1 build/web | head -20
