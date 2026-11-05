# syntax=docker/dockerfile:1

# =============================================================================
# Stage 1: builder — runs the GUI installer headlessly to produce
# /opt/LOGOSoftComfort. Everything here (Setup.bin, Xvfb, xdotool, apt caches)
# stays in this stage and is discarded from the final image.
# =============================================================================
FROM ubuntu:26.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV LOGO_INSTALL_DIR=/opt/LOGOSoftComfort

# The InstallAnywhere installer is a JavaFX GUI app, so the build stage needs an
# X stack + window manager to drive it with Xvfb/xdotool.
RUN apt-get update && apt-get install -y \
    xvfb \
    xdotool \
    xfwm4 \
    dbus-x11 \
    libasound2t64 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libgtk2.0-0 \
    libnspr4 \
    libnss3 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    libxshmfence1 \
    libxtst6 \
    libxi6 \
    libxrender1 \
    libxext6 \
    libfreetype6 \
    libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*

COPY install-logo.sh /tmp/install-logo.sh
# Bind-mount Setup.bin instead of COPY so the 1 GB binary never becomes a
# persistent image layer. The installer needs an executable, writable copy, so
# we copy it to a scratch path inside the same RUN and delete it afterwards;
# nothing from this stage reaches the final image anyway. The installed result
# is baked into /opt/LOGOSoftComfort.
RUN --mount=type=bind,source=Setup.bin,target=/mnt/Setup.bin \
    cp /mnt/Setup.bin /tmp/Setup.bin && \
    chmod +x /tmp/install-logo.sh /tmp/Setup.bin && \
    /tmp/install-logo.sh /tmp/Setup.bin && \
    rm -f /tmp/Setup.bin /tmp/install-logo.sh

# =============================================================================
# Stage 2: runtime — only the packages needed to run the app, the VNC/noVNC/xpra
# desktop, and the installed LOGO! Soft Comfort copied from the builder.
# =============================================================================
FROM ubuntu:26.04

LABEL org.opencontainers.image.source=https://github.com/mattirantakomi/logo-container

ENV DEBIAN_FRONTEND=noninteractive
ENV LOGO_INSTALL_DIR=/opt/LOGOSoftComfort

# Install dependencies for LOGO! Soft Comfort, VNC, and a lightweight desktop
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    ca-certificates \
    gnupg \
    # VNC server and lightweight desktop
    tigervnc-standalone-server \
    tigervnc-common \
    dbus-x11 \
    xfce4 \
    xfce4-terminal \
    # X11 / GTK / rendering libs needed by the bundled JRE + JavaFX UI
    libasound2t64 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libgtk2.0-0 \
    libnspr4 \
    libnss3 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    libxshmfence1 \
    libxtst6 \
    libxi6 \
    libxrender1 \
    libxext6 \
    libsecret-1-0 \
    libxss1 \
    libfreetype6 \
    libfontconfig1 \
    xdg-utils \
    # SVG/icon rendering (needed for XFCE panel)
    librsvg2-common \
    glib-networking \
    # Useful dev tools
    git \
    sudo \
    # Clipboard support for noVNC copy-paste
    xclip \
    xsel \
    fonts-liberation \
    # noVNC for browser-based access (optional)
    novnc \
    websockify \
    # Xpra dependencies (xpra itself installed from official repo below)
    apt-transport-https \
    software-properties-common \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Update icon/pixbuf caches (prevents crashes in XFCE panel)
# Remove glycin-loaders which uses bwrap sandbox (crashes in Docker), reinstall XFCE deps
RUN apt-get update && \
    apt-get remove -y glycin-loaders glycin-thumbnailers libglycin-2-0 && \
    apt-get install -y --fix-broken xfce4 xfce4-terminal librsvg2-2 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
RUN gdk-pixbuf-query-loaders > /usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0/2.10.0/loaders.cache 2>/dev/null || true
RUN gtk-update-icon-cache /usr/share/icons/hicolor 2>/dev/null || true

# Install Xpra from official repo (Ubuntu 26.04 = "resolute")
# Note: on arm64 there is no monolithic "xpra-client" package; the GTK3 client
# is "xpra-client-gtk3" and the browser client is "xpra-html5".
RUN apt-get update && apt-get install -y ca-certificates wget && \
    wget -O /usr/share/keyrings/xpra.asc https://xpra.org/xpra.asc && \
    DISTRO="resolute" && \
    wget -O /etc/apt/sources.list.d/xpra.sources \
        "https://raw.githubusercontent.com/Xpra-org/xpra/master/packaging/repos/${DISTRO}/xpra.sources" && \
    apt-get update && apt-get install -y \
        xpra \
        xpra-client-gtk3 \
        xpra-html5 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Set noVNC defaults: autoconnect, remote resize, fullscreen-like viewport
RUN sed -i "s/UI.initSetting('autoconnect', false)/UI.initSetting('autoconnect', true)/" /usr/share/novnc/app/ui.js && \
    sed -i "s/UI.initSetting('resize', 'off')/UI.initSetting('resize', 'remote')/" /usr/share/novnc/app/ui.js && \
    sed -i "s/UI.initSetting('reconnect', false)/UI.initSetting('reconnect', true)/" /usr/share/novnc/app/ui.js && \
    sed -i "s/UI.initSetting('reconnect_delay', 5000)/UI.initSetting('reconnect_delay', 1000)/" /usr/share/novnc/app/ui.js
COPY novnc-index.html /usr/share/novnc/index.html

# Create non-root user
RUN useradd -m -s /bin/bash -G sudo logo \
    && echo "logo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Copy the installed LOGO! Soft Comfort from the builder stage, owned by logo.
# This avoids both the 1 GB Setup.bin layer and the duplicate chown -R layer.
COPY --from=builder --chown=logo:logo /opt/LOGOSoftComfort /opt/LOGOSoftComfort

USER logo
WORKDIR /home/logo

# Set up VNC and xpra directories
RUN mkdir -p /home/logo/.vnc /home/logo/.config/tigervnc /home/logo/Desktop \
    /home/logo/.config/xfce4/xfconf/xfce-perchannel-xml \
    /home/logo/.xpra /home/logo/.local/share/applications

# VNC startup config
COPY --chown=logo:logo xstartup /home/logo/.vnc/xstartup
RUN chmod +x /home/logo/.vnc/xstartup

# Workspace directory for projects (LOGO! circuit programs)
RUN mkdir -p /home/logo/workspace

# Desktop shortcuts
COPY --chown=logo:logo desktop-icons/LOGOSoftComfort.desktop /home/logo/Desktop/LOGOSoftComfort.desktop
RUN chmod +x /home/logo/Desktop/*.desktop

# Panel config (taskbar with window list)
COPY --chown=logo:logo panel-config/xfce4-panel.xml /home/logo/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
COPY --chown=logo:logo panel-config/xfce4-desktop.xml /home/logo/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml

# Expose VNC port, noVNC port, and xpra port
EXPOSE 5901 6080 14500

# Entrypoint script
COPY --chown=logo:logo entrypoint.sh /home/logo/entrypoint.sh
RUN chmod +x /home/logo/entrypoint.sh

ENTRYPOINT ["/home/logo/entrypoint.sh"]
