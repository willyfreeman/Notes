FROM gitpod/workspace-full:latest

USER root

# Install Xvfb, JavaFX-helpers and Openbox window manager
RUN apt-get update \
    && apt-get install -yq xvfb x11vnc xterm openjfx libopenjfx-java mousepad firefox deluge deluge-gtk megatools fonts-droid-fallback fluxbox \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*

# overwrite this env variable to use a different window manager
ENV WINDOW_MANAGER="fluxbox"

# Install novnc
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc \
 && git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify \
 && curl -O -L https://raw.githubusercontent.com/gitpod-io/workspace-images/master/full-vnc/novnc-index.html \
 && mv novnc-index.html /opt/novnc/index.html

RUN curl -O -L https://github.com/xuiv/gost-heroku/releases/download/1.0/gost-linux \
 && curl -O -L https://github.com/xuiv/v2ray-heroku/releases/download/1.0/v2ray-linux \
 && curl -O -L https://github.com/xuiv/v2ray-heroku/releases/download/1.0/server.json \
 && mv gost-linux /usr/bin/ \
 && mv v2ray-linux /usr/bin/ \
 && mv server.json /usr/bin/ \
 && chmod +x /usr/bin/gost-linux \
 && chmod +x /usr/bin/v2ray-linux \
 && chmod 644 /usr/bin/server.json

# This is a bit of a hack. At the moment we have no means of starting background
# tasks from a Dockerfile. This workaround checks, on each bashrc eval, if the X
# server is running on screen 0, and if not starts Xvfb, x11vnc and novnc.
RUN echo "export DISPLAY=:0" >> ~/.bashrc \
 && echo "DISP=\${DISPLAY:1}" >> ~/.bashrc \
 && echo "VNC_PORT=\$(expr 5900 + \$DISP)" >> ~/.bashrc \
 && echo "NOVNC_PORT=\$(expr 6080 + \$DISP)" >> ~/.bashrc \
 && echo "" >> ~/.bashrc \
 && echo "vvv=\`pstree |grep gost\`" >> ~/.bashrc \
 && echo "if [ \"\${vvv}\"x = \"\"x ]" >> ~/.bashrc \
 && echo "then" >> ~/.bashrc \
 && echo "  nohup gost-linux -L socks+ws://:1081 >/dev/null 2>&1 &" >> ~/.bashrc \
 && echo "  nohup v2ray-linux -port 1082 -config /usr/bin/server.json >/dev/null 2>&1 &" >> ~/.bashrc \
 && echo "  Xvfb -screen \$DISP 1366x830x16 -ac -pn -noreset &" >> ~/.bashrc \
 && echo "  $WINDOW_MANAGER &" >> ~/.bashrc \
 && echo "  mousepad &" >> ~/.bashrc \
 && echo "  firefox &" >> ~/.bashrc \
 && echo "  deluge-gtk &" >> ~/.bashrc \
 && echo "  [ ! -e /tmp/.X0-lock ] && (x11vnc -localhost -shared -display :\$DISP -forever -rfbport \${VNC_PORT} -bg -o \"/tmp/x11vnc-\${DISP}.log\")" >> ~/.bashrc \
 && echo "  cd /opt/novnc/utils && ./launch.sh --vnc \"localhost:\${VNC_PORT}\" --listen \"\${NOVNC_PORT}\" &" >> ~/.bashrc \
 && echo "fi" >> ~/.bashrc

### checks ###
# no root-owned files in the home directory
RUN notOwnedFile=$(find . -not "(" -user gitpod -and -group gitpod ")" -print -quit) \
    && { [ -z "$notOwnedFile" ] \
        || { echo "Error: not all files/dirs in $HOME are owned by 'gitpod' user & group"; exit 1; } }
