# Deskflow on Linux

## What Deskflow Is

Deskflow is a free and open source keyboard-and-mouse sharing app. One machine acts as the server and nearby machines act as clients. It is effectively a software KVM without video sharing.

Official upstream:
- GitHub: `https://github.com/deskflow/deskflow`
- Build wiki: `https://github.com/deskflow/deskflow/wiki/Building`
- Flathub app: `https://flathub.org/apps/org.deskflow.deskflow`

## Installation Options

### 1. Flatpak bundle

Best choice when:
- The user already downloaded a `.flatpak` bundle
- Distro package dependencies are messy
- The machine is a desktop Linux environment with Flathub access

Commands:

```bash
sudo apt-get install -y flatpak
flatpak install --user -y /path/to/deskflow-1.26.0-linux-x86_64.flatpak
flatpak run org.deskflow.deskflow
```

Notes:
- The bundle app id is `org.deskflow.deskflow`.
- First install may pull `org.kde.Platform` and related runtimes from Flathub.
- A valid bundle can be identified with `file` or `xxd`; it starts with a `flatpak` header.

### 2. Native distro package

Best choice when:
- The distro repository already ships a compatible `deskflow` package
- The user wants system-managed upgrades

Typical flow:

```bash
sudo apt-get install -y deskflow
```

Risk:
- Direct `.deb` packages can fail on older library stacks if they require newer `Qt6`, `libportal`, or `libxkbcommon` versions than the distro provides.
- If installation stops halfway, clear the broken package first:

```bash
sudo apt-get remove -y deskflow
```

### 3. AppImage

Best choice when:
- The user wants a portable single-file binary
- They do not want Flatpak or repo package management

Typical flow:

```bash
chmod +x /path/to/Deskflow-*.AppImage
/path/to/Deskflow-*.AppImage
```

Validate the download first:

```bash
file /path/to/Deskflow-*.AppImage
ls -lh /path/to/Deskflow-*.AppImage
```

### 4. Build from source

Best choice when:
- The packaged release does not match the distro
- The user needs the latest code
- The user is debugging or contributing upstream

Official Linux build prerequisites from the upstream build wiki:
- `gcc` or `clang`
- `cmake 3.24+`
- `git`
- `ninja-build` recommended
- `Qt 6.7+`
- `OpenSSL 3.0`
- `libportal 0.8+`
- `libei 1.3+`
- `gtest` optional for tests

Debian/Ubuntu dependency example from upstream:

```bash
sudo apt-get install -y cmake build-essential ninja-build \
  xorg-dev libx11-dev libxtst-dev libssl-dev \
  libglib2.0-dev libxkbfile-dev qt6-base-dev qt6-tools-dev \
  libgtk-3-dev libgtest-dev libgmock-dev libei-dev libportal-dev
```

Source build commands:

```bash
git clone https://github.com/deskflow/deskflow.git
cd deskflow
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"
```

Run the built binary from the build output directory after the build completes.

## Practical Notes

- If the user only wants a working Linux install, prefer Flatpak over chasing distro library mismatches.
- If `apt` is already broken because of a failed Deskflow package, repair that first, then install Flatpak or retry a different package type.
- When verifying startup, benign warnings may appear, but the key check is whether the Deskflow process stays alive and the GUI opens.
