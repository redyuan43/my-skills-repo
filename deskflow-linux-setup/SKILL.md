---
name: deskflow-linux-setup
description: Install, run, and troubleshoot Deskflow on Linux using Flatpak bundles, distro packages, AppImage downloads, or source builds. Use when users ask to set up Deskflow keyboard and mouse sharing, verify a downloaded Deskflow installer, fix broken Linux package installs, or build Deskflow from source.
---

# Deskflow Linux Setup

Use this skill to install or recover Deskflow on Linux.

## Program Summary

Deskflow is a free and open source software KVM: one computer shares its keyboard, mouse, or trackpad with nearby computers over the network. Clipboard sharing is supported, TLS is enabled by default, and Wayland support depends on `libei` and `libportal`.

For installation details and source builds, read:
- `deskflow-linux-setup/references/install-methods.md`

## Recommended Workflow

1. Detect what the user downloaded:
   - `.flatpak`
   - `.deb`
   - `.rpm`
   - `.AppImage`
2. Prefer Flatpak on Linux desktops when dependency drift or distro package compatibility is uncertain.
3. If a `.deb` install left APT in a broken state, remove the half-installed `deskflow` package before installing anything else.
4. After installation, launch and verify with the method matching the package type.

## Flatpak Workflow

1. Check whether `flatpak` exists:

```bash
command -v flatpak
```

2. If missing, install it with the system package manager.
3. Install the downloaded bundle for the current user:

```bash
flatpak install --user -y /path/to/deskflow-*.flatpak
```

4. Launch:

```bash
flatpak run org.deskflow.deskflow
```

5. Expect the first install to pull required runtimes from Flathub.

## Recover Broken `.deb` Installs

If `apt` reports unmet dependencies caused by a half-installed `deskflow` package:

```bash
sudo apt-get remove -y deskflow
```

Then retry the intended install path. Do not keep piling packages onto a broken APT state.

## Source Build Workflow

Use the official build instructions and distro dependency lists from:
- `deskflow-linux-setup/references/install-methods.md`

Core Linux build flow:

```bash
git clone https://github.com/deskflow/deskflow.git
cd deskflow
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"
```

## Validation

After any install path:

1. Start the app.
2. Confirm the process stays alive.
3. If running on Wayland, expect `libei` and `libportal` support to be present on source builds.
4. If the GUI opens, proceed to actual server/client pairing only after install is proven stable.
