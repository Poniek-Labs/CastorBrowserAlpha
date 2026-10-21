#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 3 ]]; then
  printf 'Usage: %s FIREFOX_TARBALL OUTPUT_DIR VERSION\n' "$0" >&2
  exit 2
fi

firefox_tarball="$1"
output_dir="$2"
package_version="${3#v}"

if [[ ! -f "$firefox_tarball" ]]; then
  printf 'Error: Firefox package not found: %s\n' "$firefox_tarball" >&2
  exit 1
fi
if [[ ! "$package_version" =~ ^[0-9][A-Za-z0-9.+:~-]*$ ]]; then
  printf 'Error: invalid Debian package version: %s\n' "$package_version" >&2
  exit 1
fi
command -v dpkg-deb >/dev/null || { printf 'Error: dpkg-deb is required.\n' >&2; exit 1; }

case "$(uname -m)" in
  x86_64) package_architecture=amd64 ;;
  aarch64|arm64) package_architecture=arm64 ;;
  *) printf 'Error: unsupported Debian package architecture: %s\n' "$(uname -m)" >&2; exit 1 ;;
esac

package_root="$(mktemp -d)"
trap 'rm -rf "$package_root"' EXIT
mkdir -p \
  "$package_root/DEBIAN" \
  "$package_root/opt/castor-browser" \
  "$package_root/usr/bin" \
  "$package_root/usr/share/applications"

tar -xf "$firefox_tarball" --strip-components=1 -C "$package_root/opt/castor-browser"
if [[ ! -x "$package_root/opt/castor-browser/firefox" ]]; then
  printf 'Error: Firefox executable not found in %s\n' "$firefox_tarball" >&2
  exit 1
fi

cat > "$package_root/DEBIAN/control" <<EOF
Package: castor-browser
Version: $package_version
Section: web
Priority: optional
Architecture: $package_architecture
Depends: libc6, libstdc++6, libgtk-3-0 | libgtk-3-0t64, libdbus-1-3, libasound2 | libasound2t64, libnss3, libx11-6, libxt6
Maintainer: Poniek Labs
Homepage: https://github.com/Poniek-Labs/CastorBrowserAlpha
Description: Castor Browser
 Community-built web browser based on Mozilla Firefox.
EOF

cat > "$package_root/usr/bin/castor-browser" <<'EOF'
#!/bin/sh
exec /opt/castor-browser/firefox "$@"
EOF
chmod 755 "$package_root/usr/bin/castor-browser"
chmod 755 "$package_root" "$package_root/DEBIAN"

cat > "$package_root/usr/share/applications/castor-browser.desktop" <<'EOF'
[Desktop Entry]
Name=Castor Browser
Comment=Browse the web with Castor Browser
Exec=/usr/bin/castor-browser %u
Icon=web-browser
Terminal=false
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
EOF
chmod 644 "$package_root/DEBIAN/control" "$package_root/usr/share/applications/castor-browser.desktop"

mkdir -p "$output_dir"
dpkg-deb --build --root-owner-group "$package_root" "$output_dir/castor-browser_${package_version}_${package_architecture}.deb"