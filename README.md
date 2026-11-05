# LOGO! Soft Comfort Docker Container

A Docker container running **Siemens LOGO! Soft Comfort 8.4** with a VNC server
and xpra support. This lets you run the engineering software in an isolated,
disposable Linux environment without installing it directly on your host.

## Features

- Based on Ubuntu 26.04 LTS (Resolute Raccoon)
- LOGO! Soft Comfort installed from `Setup.bin` at build time and launched automatically
- TigerVNC server (port 5901, no password)
- noVNC web client (port 6080) — accessible via browser, auto-connects
- **Xpra** (port 14500) — forwards just the LOGO! Soft Comfort window into your host desktop natively
- XFCE4 desktop with taskbar and desktop shortcut
- Project files mounted from `./workspace`

## What is LOGO! Soft Comfort?

LOGO! Soft Comfort is Siemens' programming software for the LOGO! logic module.
You build control programs with function block diagrams (FBD) or ladder diagrams
(LAD), simulate them, and download them to a physical LOGO! device. The
application is Java/JavaFX based and ships with its own bundled runtime, so no
separate Java installation is required inside the container.

## Prerequisites

The installer file `Setup.bin` (the Siemens LOGO! Soft Comfort 8.4 Linux
installer) must be present in this directory before building. It is copied into
the image and installed during the build.

> `Setup.bin` is **not** tracked in this repository (it is ~1 GB, above
> GitHub's file-size limit, and is Siemens-licensed software). Obtain it from
> Siemens and drop it in this directory before running the build.

Download the installer from Siemens:
[LOGO! Soft Comfort V8.4 Demo](https://support.industry.siemens.com/cs/document/109826921/logo!soft-comfort-v8-4-demo?dti=0&lc=en-FI)

> **Note:** downloading requires a (free) Siemens Industry Support account —
> you must register and log in before the download is available. After
> downloading the Linux package, rename/place the installer as `Setup.bin` in
> this directory.

The downloaded package is named `lsc_v8_4_demo.zip`. The `Setup.bin` you need
is inside it at:

```
lsc_v8_4_demo/lsc_v8_4_demo/Web_Installers/InstData/Linux64/VM/Setup.bin
```

Extract that file and place it in this directory as `Setup.bin`.

> **Note:** `Setup.bin` is ~1 GB and bundles its own Java runtime.
>
> This InstallAnywhere installer does **not** support console or silent mode —
> both are rejected with *"Installer User Interface Mode Not Supported"*. Only
> the GUI installer works. The build therefore runs the GUI installer on a
> virtual X display (Xvfb) and drives the wizard automatically with `xdotool`
> (see `install-logo.sh`). The build fails loudly if the install does not
> produce the `LOGOComfort` launcher.

## Getting Started

```bash
docker compose up --build
```

The first build takes a while (installing the desktop, xpra, and running the
~1 GB LOGO! installer).

## Connecting

### Xpra — native window forwarding (recommended)

Xpra forwards the LOGO! Soft Comfort window directly into your Ubuntu desktop.
The window behaves like any local app: it gets its own taskbar entry, you can
resize it, alt-tab to it, etc.

**Install xpra on your Ubuntu host** (once):

> **Important:** Use the official xpra.org repository, not the Ubuntu package.
> Ubuntu 22.04's default package is version 3.x, but the container runs version
> 6.x — the version mismatch causes a `disconnect invalid compression: zlib is
> not available` error on connect.

```bash
# Find your Ubuntu codename:
# jammy = 22.04, noble = 24.04, oracular = 24.10, resolute = 26.04
DISTRO="jammy"   # <-- change this to match your Ubuntu version

# Remove the old Ubuntu package if installed
sudo apt remove -y xpra 2>/dev/null || true

# Add the official xpra.org repository
sudo apt install -y ca-certificates wget
sudo wget -O /usr/share/keyrings/xpra.asc https://xpra.org/xpra.asc
sudo wget -O /etc/apt/sources.list.d/xpra.sources \
    "https://raw.githubusercontent.com/Xpra-org/xpra/master/packaging/repos/${DISTRO}/xpra.sources"
sudo apt update && sudo apt install -y xpra
```

**Connect:**

```bash
xpra attach tcp://localhost:14500
```

The LOGO! Soft Comfort window appears on your desktop. Close the xpra client to
disconnect (the container keeps running).

### noVNC — browser access

```
http://localhost:6080
```

Auto-connects and scales to your browser window. No password needed.

### VNC client

```
localhost:5901  (no password)
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VNC_RESOLUTION` | `1920x1080` | Desktop resolution (VNC/noVNC) |
| `XPRA_PORT` | `14500` | TCP port for the xpra server |
| `LOGO_INSTALL_DIR` | `/opt/LOGOSoftComfort` | Where LOGO! Soft Comfort is installed in the image |

## Workspace

The `./workspace` folder is mounted into the container at `/home/logo/workspace`.
Save your LOGO! circuit programs there so they persist across container restarts.

## Troubleshooting

**The build fails at the install step / "LOGOComfort launcher not found".**
The automated GUI install is driven by fixed button coordinates on a
1280x1024 virtual screen (`install-logo.sh`). If your `Setup.bin` revision has a
slightly different wizard layout, a click can miss. Inspect what happened:

```bash
# Re-run the installer build step and watch the log, or build a debug image
# and run install-logo.sh manually with screenshots.
```

The wizard flow the script expects is: Welcome → OK, License → accept + Next,
Install Folder (pre-filled via `-DUSER_INSTALL_DIR`) → Next, Link Location →
Install, then wait for completion. Adjust the coordinates in `install-logo.sh`
if the layout differs, then rebuild.

**Checking the installed app in the image:**

```bash
docker compose run --rm --entrypoint bash logo-soft
ls -la /opt/LOGOSoftComfort
find / -type f -name LOGOComfort 2>/dev/null
```

If the installer used a different directory, set `LOGO_INSTALL_DIR` in
`docker-compose.yml` to match, then rebuild.

## Notes

- `shm_size: 2gb` helps GUI apps avoid shared-memory crashes
- `SYS_ADMIN` capability is needed for XFCE's icon rendering (glycin/bubblewrap sandbox)
- A desktop shortcut for LOGO! Soft Comfort is on the desktop
- Taskbar at the top shows running windows (click to restore minimized apps)
- Xpra runs on display `:2` separately from VNC (`:1`), so both can be used simultaneously
- The LOGO! Soft Comfort install is baked into the image, so it persists without a mounted volume

## License and Copyright

This repository contains only the containerization tooling (Dockerfile, scripts,
and configuration). That tooling is released under the **MIT License** (see the
[`LICENSE`](LICENSE) file) — you are free to use, modify, and redistribute it.

**Siemens software is not included or redistributed by this repository, and is
not covered by the MIT License.**

LOGO! and LOGO! Soft Comfort are products and trademarks of Siemens AG. The
LOGO! Soft Comfort 8.4 software (`Setup.bin`) is proprietary, copyrighted
software owned by Siemens AG and is **not** distributed here — you must obtain
it yourself from Siemens under their license terms. Your use of that software is
governed solely by the Siemens license agreement that accompanies it.

To keep the Siemens-licensed installer out of this repository and out of any
built image, `Setup.bin` is listed in both `.gitignore` and `.dockerignore`, and
the build bind-mounts it rather than copying it into an image layer. Do not
commit, publish, or redistribute `Setup.bin` or any image containing the
installed Siemens software.

All other trademarks and product names are the property of their respective
owners.
