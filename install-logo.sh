#!/bin/bash
# Headless, automated install of Siemens LOGO! Soft Comfort 8.4.
#
# The InstallAnywhere installer bundled in Setup.bin does not support console
# or silent mode (it rejects both with "Installer User Interface Mode Not
# Supported"); only the GUI installer works. So we run the GUI installer on a
# virtual X display (Xvfb) with a window manager, and drive the wizard with
# xdotool button clicks. The wizard flow (confirmed by inspecting each screen):
#
#   1. Welcome screen            -> click OK
#   2. License Agreement         -> select "I accept", click Next
#   3. Choose Install Folder     -> pre-filled via -DUSER_INSTALL_DIR, click Next
#   4. Choose Link Location      -> click Install
#   5. Installing... (progress)  -> wait until the LOGOComfort launcher appears
#   6. Done                      -> click Done (installer exits)
#
set -u

SETUP_BIN=${1:-/tmp/Setup.bin}
INSTALL_DIR=${LOGO_INSTALL_DIR:-/opt/LOGOSoftComfort}
DISP=:99

echo "[install-logo] starting virtual display and installer"
export DISPLAY=$DISP
Xvfb $DISP -screen 0 1280x1024x24 >/tmp/xvfb.log 2>&1 &
XVFB_PID=$!
sleep 4
xfwm4 >/tmp/wm.log 2>&1 &
sleep 2

chmod +x "$SETUP_BIN"
"$SETUP_BIN" -i gui -DUSER_INSTALL_DIR="$INSTALL_DIR" >/tmp/logo-install.log 2>&1 &
INSTALLER_PID=$!

# Wait for the installer window to appear
echo "[install-logo] waiting for installer window"
for i in $(seq 1 60); do
    if xdotool search --name "Install LOGO" >/dev/null 2>&1; then
        break
    fi
    sleep 2
done
sleep 5

click() { xdotool mousemove "$1" "$2" click 1; }

# Button coordinates are for the 1280x1024 virtual screen, where the installer
# window is centred. The wizard keeps a stable layout across screens.
echo "[install-logo] 1/4 welcome -> OK"
click 780 703
sleep 6

echo "[install-logo] 2/4 license -> accept + Next"
click 558 620        # "I accept the terms of the License Agreement" radio
sleep 2
click 884 702        # Next
sleep 5

echo "[install-logo] 3/4 install folder -> Next"
click 884 702        # Next (folder is pre-filled with USER_INSTALL_DIR)
sleep 5

echo "[install-logo] 4/4 link location -> Install"
click 884 702        # Install
sleep 5

# Wait for installation to finish: the LOGOComfort launcher appears when done.
echo "[install-logo] installing, waiting for launcher to appear..."
LAUNCHER=""
for i in $(seq 1 150); do   # up to ~10 minutes
    LAUNCHER=$(find "$INSTALL_DIR" -type f -name 'LOGOComfort' 2>/dev/null | head -n1)
    if [ -n "$LAUNCHER" ]; then
        echo "[install-logo] launcher found: $LAUNCHER (after ${i}x4s)"
        break
    fi
    sleep 4
done

# Dismiss the final "Done" screen if the installer is still up
sleep 8
click 884 702        # Done
sleep 4
# Fallback: close any remaining installer window
xdotool search --name "LOGO" windowkill 2>/dev/null || true

# Give the installer process a moment to exit, then clean up the display
sleep 3
kill "$INSTALLER_PID" 2>/dev/null || true
kill "$XVFB_PID" 2>/dev/null || true

echo "[install-logo] ===== install log tail ====="
tail -n 20 /tmp/logo-install.log 2>/dev/null || true

echo "[install-logo] ===== verifying install ====="
LAUNCHER=$(find "$INSTALL_DIR" -type f -name 'LOGOComfort' 2>/dev/null | head -n1)
if [ -z "$LAUNCHER" ]; then
    echo "[install-logo] ERROR: LOGOComfort launcher not found under $INSTALL_DIR" >&2
    echo "[install-logo] contents of $INSTALL_DIR:" >&2
    ls -la "$INSTALL_DIR" 2>/dev/null >&2 || echo "  (missing)" >&2
    exit 1
fi
echo "[install-logo] SUCCESS: $LAUNCHER"
exit 0
