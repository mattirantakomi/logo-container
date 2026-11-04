#!/bin/bash
set -e

LOGO_INSTALL_DIR=${LOGO_INSTALL_DIR:-/opt/LOGOSoftComfort}

# Clean previous VNC/xpra logs on every start
rm -rf /home/logo/.config/tigervnc/*.log
mkdir -p /home/logo/.config/tigervnc

# Locate the LOGO! Soft Comfort launcher inside the install dir.
# The executable is named "LOGOComfort" on Linux; its exact sub-path depends
# on the installer layout, so find it dynamically.
LOGO_LAUNCHER=$(find "$LOGO_INSTALL_DIR" -type f -name 'LOGOComfort' 2>/dev/null | head -n1)
if [ -z "$LOGO_LAUNCHER" ]; then
    LOGO_LAUNCHER=$(find "$LOGO_INSTALL_DIR" -type f \( -iname 'LOGOComfort*' -o -iname 'LOGO*Soft*Comfort*' \) 2>/dev/null | grep -vi '\.\(jar\|dll\|exe\|app\)$' | head -n1)
fi

if [ -n "$LOGO_LAUNCHER" ]; then
    chmod +x "$LOGO_LAUNCHER" 2>/dev/null || true
    echo "LOGO! Soft Comfort launcher: $LOGO_LAUNCHER"
else
    echo "WARNING: could not find the LOGOComfort launcher under $LOGO_INSTALL_DIR"
    echo "Contents of $LOGO_INSTALL_DIR:"
    ls -la "$LOGO_INSTALL_DIR" 2>/dev/null || echo "  (install dir missing)"
fi

# Write the desktop shortcut's Exec line now that we know the launcher path
if [ -n "$LOGO_LAUNCHER" ]; then
    cat > /home/logo/Desktop/LOGOSoftComfort.desktop <<EOF
[Desktop Entry]
Type=Application
Name=LOGO! Soft Comfort
Exec=$LOGO_LAUNCHER
Icon=applications-engineering
Terminal=false
Categories=Development;Engineering;
EOF
    chmod +x /home/logo/Desktop/LOGOSoftComfort.desktop
    gio set /home/logo/Desktop/LOGOSoftComfort.desktop metadata::trusted true 2>/dev/null || true
fi

# Set display resolution (default 1920x1080)
RESOLUTION=${VNC_RESOLUTION:-1920x1080}

# Start VNC server without password (SecurityTypes=None)
vncserver :1 -geometry "$RESOLUTION" -depth 24 -localhost no -SecurityTypes None --I-KNOW-THIS-IS-INSECURE -xstartup /home/logo/.vnc/xstartup

# Start noVNC (web-based VNC client) for browser access
websockify --web=/usr/share/novnc/ --heartbeat=30 0.0.0.0:6080 localhost:5901 &

# Start xpra seamless server on display :2, TCP port 14500 (no auth for LAN use)
# LOGO! Soft Comfort is launched as the managed app so only its window is forwarded
XPRA_PORT=${XPRA_PORT:-14500}
if [ -n "$LOGO_LAUNCHER" ]; then
    xpra seamless :2 \
        --bind-tcp=0.0.0.0:${XPRA_PORT} \
        --html=on \
        --start="$LOGO_LAUNCHER" \
        --exit-with-children=no \
        --mdns=no \
        --notifications=no \
        --pulseaudio=no \
        --systemd-run=no \
        --daemon=yes \
        --log-file=/home/logo/.xpra/xpra.log \
        --auth=none \
        --bandwidth-limit=0 \
        --video-scaling=1 \
        --encoding=rgb \
        --compress=0 \
        2>/home/logo/.xpra/xpra-start.log
fi

echo "============================================"
echo " LOGO! Soft Comfort Docker Container Running"
echo "============================================"
echo " Browser (noVNC):  http://localhost:6080"
echo " VNC client:       localhost:5901 (no password)"
echo " Resolution:       $RESOLUTION"
echo "--------------------------------------------"
echo " Xpra native (recommended):"
echo "   xpra attach tcp://localhost:${XPRA_PORT}"
echo " Xpra web UI:      http://localhost:${XPRA_PORT}"
echo "============================================"

# Keep container running
sleep 2
tail -f /home/logo/.vnc/*.log /home/logo/.config/tigervnc/*.log /home/logo/.xpra/xpra.log 2>/dev/null || sleep infinity
