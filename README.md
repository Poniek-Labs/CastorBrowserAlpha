# Castor Browser

Castor Browser is a community-built browser project based on Mozilla Firefox.
Builds are intended for Canadian users and are distributed from this project's
GitHub Releases page.

## Download

[Download the latest Castor Browser release](https://github.com/Poniek-Labs/CastorBrowserAlpha/releases/latest).

Release availability depends on the CI build completing successfully. Verify the
release notes and platform before installing.

## Build from source

The build script uses a Firefox source checkout. Set `FIREFOX_SOURCE_DIR` to an
existing checkout, or let the script clone Mozilla's Firefox repository into
`./firefox`:

```sh
./build-castor.sh
```

To use an existing checkout:

```sh
FIREFOX_SOURCE_DIR=/path/to/firefox ./build-castor.sh
```

The first build bootstraps Mozilla's build dependencies and compiles Firefox's
stable `release` branch. Castor branding is applied to the browser UI, application
icons, Windows installer, startup preferences, and Linux desktop launcher. Linux
builds include a Debian `.deb` package alongside the original Firefox archive.
Set `CASTOR_PLATFORM=windows` when running under MozillaBuild to produce a
Windows installer `.exe`. Builds require substantial disk space and time. Output
packages are written to `build-output/`.

Mozilla's automatic update channel is disabled so the build cannot silently
replace Castor with a Mozilla-branded release. Version tags beginning with `v`
trigger Linux and Windows builds. The Windows job requires MozillaBuild and
publishes an installer `.exe`; the Linux job publishes a `.deb`. Both are attached
to the GitHub Release.

## Project files

- `.github/workflows/release.yml` builds and publishes packages for version tags
	beginning with `v`.
- `branding/castor/branding.nsi` contains Castor installer branding definitions.
- `patches/theme.css` defines the Castor theme color tokens.
- `patches/prefs.js` disables selected Firefox telemetry and data-submission
	preferences.

Castor Browser is an independent community project and is not affiliated with
Mozilla. See [LICENSE](LICENSE) for the source license.