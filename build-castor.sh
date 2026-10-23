#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source_dir="${FIREFOX_SOURCE_DIR:-$repo_root/firefox}"
firefox_repository="${FIREFOX_REPOSITORY:-https://github.com/mozilla-firefox/firefox.git}"
firefox_branch="${FIREFOX_BRANCH:-release}"
output_dir="$repo_root/build-output"
target_platform="${CASTOR_PLATFORM:-linux}"

if [[ "$target_platform" != linux && "$target_platform" != windows ]]; then
  printf 'Error: CASTOR_PLATFORM must be linux or windows.\n' >&2
  exit 1
fi

if [[ ! -f "$source_dir/mach" ]]; then
  if [[ -e "$source_dir" ]]; then
    printf 'Error: %s exists but is not a Firefox source checkout.\n' "$source_dir" >&2
    exit 1
  fi
  command -v git >/dev/null || { printf 'Error: git is required.\n' >&2; exit 1; }
  if [[ "$target_platform" == windows ]]; then
    git config --global core.longpaths true
  fi
  git clone --depth 1 --branch "$firefox_branch" "$firefox_repository" "$source_dir"
fi

if [[ ! -d "$source_dir/browser/branding/unofficial" ]]; then
  printf 'Error: %s does not look like a Firefox source checkout.\n' "$source_dir" >&2
  exit 1
fi

branding_dir="$source_dir/browser/branding/castor"
mkdir -p "$branding_dir"
cp -a "$source_dir/browser/branding/unofficial/." "$branding_dir/"
cat "$repo_root/branding/castor/branding.nsi" >> "$branding_dir/branding.nsi"

cat > "$branding_dir/locales/en-US/brand.ftl" <<'EOF'
-brand-shorter-name = Castor
-brand-short-name = Castor
-brand-shortcut-name = Castor
-brand-full-name = Castor Browser
-brand-product-name = Castor Browser
-vendor-short-name = Poniek Labs
trademarkInfo = { " " }
EOF

cat > "$branding_dir/pref/firefox-branding.js" <<'EOF'
pref("app.update.channel", "release");
pref("app.update.enabled", false);
pref("startup.homepage_override_url", "https://github.com/Poniek-Labs/CastorBrowserAlpha");
pref("startup.homepage_welcome_url", "https://github.com/Poniek-Labs/CastorBrowserAlpha");
EOF

logo_png="$repo_root/logo/castor.png"
if [[ ! -f "$logo_png" ]]; then
  printf 'Error: Castor logo not found: %s\n' "$logo_png" >&2
  exit 1
fi
if [[ "$target_platform" == linux ]]; then
  command -v convert >/dev/null || { printf 'Error: ImageMagick convert is required.\n' >&2; exit 1; }
  convert "$logo_png" -resize 16x16 "$branding_dir/default16.png"
  convert "$logo_png" -resize 22x22 "$branding_dir/default22.png"
  convert "$logo_png" -resize 24x24 "$branding_dir/default24.png"
  convert "$logo_png" -resize 32x32 "$branding_dir/default32.png"
  convert "$logo_png" -resize 48x48 "$branding_dir/default48.png"
  convert "$logo_png" -resize 64x64 "$branding_dir/default64.png"
  convert "$logo_png" -resize 128x128 "$branding_dir/default128.png"
  convert "$logo_png" -resize 256x256 "$branding_dir/default256.png"
else
  command -v magick >/dev/null || { printf 'Error: ImageMagick magick is required.\n' >&2; exit 1; }
  magick "$logo_png" -define icon:auto-resize=256,128,64,48,32,16 "$branding_dir/firefox.ico"
  magick "$logo_png" -define icon:auto-resize=256,128,64,48,32,16 "$branding_dir/firefox64.ico"
  for size in 16 32 48 64 128 256; do
    magick "$logo_png" -resize "${size}x${size}" "$branding_dir/default${size}.png"
  done
fi

preferences_dir="$source_dir/browser/app/profile/defaults/preferences"
mkdir -p "$preferences_dir"
cp "$repo_root/patches/prefs.js" "$preferences_dir/castor.js"

shared_theme="$source_dir/browser/themes/shared"
shared_stylesheet="$shared_theme/browser-shared.css"
if [[ ! -f "$shared_stylesheet" ]]; then
  printf 'Error: expected Firefox stylesheet not found: %s\n' "$shared_stylesheet" >&2
  exit 1
fi
cp "$repo_root/patches/theme.css" "$shared_theme/castor-theme.css"
if ! grep -Fq '@import url("castor-theme.css");' "$shared_stylesheet"; then
  printf '\n@import url("castor-theme.css");\n' >> "$shared_stylesheet"
fi

mozconfig="$(mktemp)"
trap 'rm -f "$mozconfig"' EXIT
cat > "$mozconfig" <<'EOF'
ac_add_options --with-branding=browser/branding/castor
ac_add_options --enable-update-channel=release
EOF
export MOZCONFIG="$mozconfig"

cd "$source_dir"
./mach bootstrap --application-choice browser
./mach build
./mach package

mkdir -p "$output_dir"
find "$output_dir" -maxdepth 1 -type f -delete
while IFS= read -r -d '' artifact; do
  case "$(basename "$artifact")" in
    *crashreporter-symbols*) continue ;;
  esac
  cp "$artifact" "$output_dir/"
done < <(find "$source_dir" -type f -path '*/obj-*/dist/*' \( -iname '*.tar.*' -o -iname '*.zip' -o -iname '*.installer.exe' -o -iname '*setup*.exe' \) -print0)

if [[ "$target_platform" == linux ]]; then
  linux_archive="$(find "$output_dir" -maxdepth 1 -type f -iname '*.tar.*' -print -quit)"
  if [[ -z "$linux_archive" ]]; then
    printf 'Error: Linux build completed but no tar package was found for Debian packaging.\n' >&2
    exit 1
  fi
  "$repo_root/packaging/build-deb.sh" "$linux_archive" "$output_dir" "${CASTOR_VERSION:-0.1.0}"
fi

if [[ -z "$(find "$output_dir" -maxdepth 1 -type f -print -quit)" ]]; then
  printf 'Error: Mozilla build completed but no package archive was found.\n' >&2
  exit 1
fi

if [[ "$target_platform" == windows ]] && [[ -z "$(find "$output_dir" -maxdepth 1 -type f -iname '*.exe' -print -quit)" ]]; then
  printf 'Error: Windows build completed but no installer executable was found.\n' >&2
  exit 1
fi

printf 'Castor Browser %s packages are available in %s\n' "$target_platform" "$output_dir"