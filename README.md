# Claude Desktop Flatpak

This project is a detached fork of [mboman/claude-desktop-flatpak](https://github.com/mboman/claude-desktop-flatpak).

The purpose of this fork is to make the official Claude Desktop for Linux (beta) available on distributions with Flatpak support, including Fedora, Arch, and openSUSE. Builds download checksum-pinned Debian packages directly from Anthropic and repackage the application with its bundled Electron runtime, desktop entry, icons, and file associations.

The fork simplifies maintenance around a single `flatpak-builder` workflow, with local builds and GitHub Actions builds for both x86_64 and aarch64. It adapts the upstream application to the Flatpak environment through Zypak, Wayland with fallback X11, and desktop keyring access. A daily workflow adopts new Claude releases by updating the pinned packages and release metadata, then triggering builds for both architectures.

The manifest currently packages Claude Desktop **2.42304.0** for **x86_64** and **aarch64**, using Freedesktop Platform and Electron BaseApp **25.08**. It uses the Electron runtime shipped with Claude Desktop and Zypak for Chromium sandbox integration inside Flatpak.

The packaged MIME definitions cover `.mcpb`, `.dxt`, and `.skill` files.

## Prerequisites

1. **Flatpak** must be installed on your system
2. **flatpak-builder** for building the package
3. **Internet access** to download the application and build dependencies

The build script enables Flathub for your user and installs the required Flatpak dependencies automatically.

### Installing prerequisites on Fedora:

```bash
sudo dnf install flatpak flatpak-builder
```

### Installing prerequisites on other distros:

- **Ubuntu/Debian**: `sudo apt install flatpak flatpak-builder`
- **Arch**: `sudo pacman -S flatpak flatpak-builder`
- **openSUSE**: `sudo zypper install flatpak flatpak-builder`

## Building the Flatpak

On Fedora Atomic/Bazzite, install `flatpak-builder` with `rpm-ostree install flatpak-builder` and reboot before building.

From the repository directory, run:

```bash
./build.sh
```

The script:

1. Enables the user-level Flathub remote and installs required runtimes and build dependencies.
2. Downloads the official Debian package for the build architecture and verifies its pinned SHA-256 checksum.
3. Repackages the application with `flatpak-builder` into `build-dir/` and exports it to `repo/`.
4. Creates `claude-desktop.flatpak` in the repository directory.

No separate Claude source checkout or Electron download is needed. The script builds for the host's default Flatpak architecture.

### Automated builds

The GitHub Actions workflow in `.github/workflows/build.yml` builds both x86_64 and aarch64 bundles on pull requests, manual runs, and pushes to `main` that change files other than Markdown or license files.

## Installing the Flatpak

After building, install it with:

```bash
flatpak install --user claude-desktop.flatpak
```

Or to install system-wide (may require administrator authorization):

```bash
flatpak install --system claude-desktop.flatpak
```

## Running Claude Desktop

After installation, you can run it from your application menu or from terminal:

```bash
flatpak run com.anthropic.Claude
```

## Permissions

The Flatpak includes these permissions:

- **Network access**: For communicating with Claude services
- **Home directory access**: For project folders, file attachments, and other files in your home directory
- **GPU acceleration**: For better performance
- **Audio**: For any audio features
- **Wayland with fallback X11**: For displaying application windows
- **Shared IPC**: For X11 shared-memory support
- **Desktop integration**: For notifications and tray icons
- **Keyring access**: For storing sign-in credentials through GNOME Keyring or KDE Wallet

## Updating

### Automatic upstream updates

The `Update Claude` workflow runs every day at 00:00 UTC and can also be started manually from GitHub Actions. It reads Anthropic's stable APT package indexes and selects the newest numeric release available for both amd64 and arm64. It keeps the current version if the indexes only offer older releases.

When a newer release is available, the workflow updates the package URLs and SHA-256 checksums in the manifest, adds an AppStream release entry dated when the update is detected, and updates the version in this README. It commits those files directly to `main` and starts the build workflow. If no newer release is available, it makes no commit.

The workflow uses the built-in `GITHUB_TOKEN` with `contents: write` and `actions: write`. Repository rules must permit the bot to push to `main`.

### Updating locally

Run the same updater with Bash, `curl`, `awk`, GNU `sed`, and GNU coreutils, then build and install the bundle:

```bash
./update.sh
./build.sh
flatpak install --user --reinstall claude-desktop.flatpak
```

The manifest pins the application version; rebuilding alone does not select a newer release. The workflow updates this repository and builds bundles; update your local installation by installing a new bundle. `flatpak update` does not fetch new upstream Debian packages.

You can also update the package URLs and SHA-256 checksums for both architectures manually, together with the AppStream release metadata and the version in this README.

## Uninstalling

To remove the Flatpak:

```bash
flatpak uninstall --user com.anthropic.Claude
```

Use `--system` instead of `--user` if you installed system-wide.

## MCP servers and desktop extensions

The upstream application includes MCP server and desktop extension support. Tools launched by Claude run within the Flatpak sandbox and need their executables and dependencies available there. Host-installed commands are not automatically available inside the sandbox.

Flatpak stores the application's configuration under `~/.var/app/com.anthropic.Claude/config/`. The manifest grants access to your home directory for file-based workflows, but individual extensions may need additional setup.

## Troubleshooting

### Build fails with missing runtimes

The build script normally enables Flathub automatically. If building manually, enable it for the same user installation:

```bash
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

### Application won't start

Launch from a terminal to see startup output:

```bash
flatpak run com.anthropic.Claude
```

To inspect the sandbox interactively:

```bash
flatpak run --command=sh com.anthropic.Claude
```

### Need more permissions

Edit `finish-args` in `com.anthropic.Claude.yml`, then rebuild and reinstall the bundle.

## File Structure

- `com.anthropic.Claude.yml` - Main Flatpak manifest
- `com.anthropic.Claude.metainfo.xml` - AppStream metadata
- `build.sh` - Automated build script
- `update.sh` - Updates pinned packages from Anthropic's stable APT indexes
- `.github/workflows/build.yml` - Builds bundles for x86_64 and aarch64
- `.github/workflows/update-claude-version.yml` - Daily upstream checks and automatic update commits
- `README.md` - This file

## Distribution

You can distribute the generated `claude-desktop.flatpak` bundle file to others. They can install it with:

```bash
flatpak install --user claude-desktop.flatpak
```

Recipients need Flatpak, the matching architecture, and access to Flathub for runtime dependencies:

```bash
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

## Contributing

Feel free to modify the manifest to suit your needs. Common modifications:

- **Reduce permissions**: Remove finish-args you don't need
- **Add dependencies**: Add modules for additional tools
- **Change runtime version**: Update to newer Freedesktop Platform versions

## Notes

- This is a community-created Flatpak configuration
- Claude Desktop is developed by Anthropic
- Packages the official Linux application without rebuilding its source

## License

The Claude Desktop application is proprietary software by Anthropic. This Flatpak manifest configuration is provided as-is for packaging purposes.
