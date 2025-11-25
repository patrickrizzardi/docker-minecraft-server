FROM ubuntu:22.04

# User/group configuration
# Why: Running as non-root is a security best practice
ENV USER=velocity
ENV UID=1000
ENV GID=1000
ENV WORKDIR=/velocity

# Script configuration
# Why: These are referenced by all the management scripts
ENV TMUX_SESSION=velocity
ENV PROJECT=velocity

# Create non-root user with sudo access
# Why: Don't run proxy as root (security), but allow admin tasks if needed
RUN groupadd --gid ${GID} ${USER} && \
    useradd --create-home --shell /bin/bash --uid ${UID} --gid ${GID} ${USER} && \
    usermod -aG sudo ${USER}

# Install system dependencies
# Why: Tools needed for proxy management and Velocity API downloads
# - vim: editing configs
# - curl/wget: downloading Velocity JAR from Paper API
# - tmux: background proxy process management
# - jq: parsing Velocity API JSON responses
# - software-properties-common: needed for add-apt-repository
RUN apt update && apt upgrade -y && apt install -y --no-install-recommends \
    vim \
    curl \
    software-properties-common \
    ca-certificates \
    apt-transport-https \
    gnupg \
    wget \
    tmux \
    jq

# Add Amazon Corretto repository
# Why: Using Corretto (AWS's OpenJDK) for better performance and LTS support
RUN curl https://apt.corretto.aws/corretto.key | apt-key add - && \
    add-apt-repository 'deb https://apt.corretto.aws stable main'

# Install Java 21 and GUI libraries
# Why: Java 21 is latest LTS with best plugin compatibility
# Why libxi6/libxtst6/libxrender1: Required for some proxy plugins that use GUI/rendering
RUN apt update && apt install -y --no-install-recommends \
    java-21-amazon-corretto-jdk \
    libxi6 \
    libxtst6 \
    libxrender1

# Clean up apt cache to reduce image size
# Why: apt cache isn't needed at runtime, removing saves ~100MB+
RUN apt-get -y autoremove \
    && apt-get -y clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/*

# Switch to non-root user
# Why: All operations from here on should be as velocity user for security
USER ${USER}
WORKDIR $WORKDIR

# Copy management scripts and make them executable
# Why: These scripts handle start/stop/restart/debug/status operations
COPY --chown=${USER}:${USER} scripts scripts
RUN chmod +x scripts/*

# Copy default log rotation config
# Why: Prevents logs from filling disk, can be overridden via volume mount
COPY --chown=${USER}:${USER} log4j2.xml log4j2.xml

# Create user bin directory and symlinks for easy access
# Why: Makes scripts available as commands without needing full paths or aliases
RUN mkdir -p ~/bin && \
    ln -s $WORKDIR/scripts/start.sh ~/bin/start && \
    ln -s $WORKDIR/scripts/stop.sh ~/bin/stop && \
    ln -s $WORKDIR/scripts/restart.sh ~/bin/restart && \
    ln -s $WORKDIR/scripts/status.sh ~/bin/status && \
    ln -s $WORKDIR/scripts/debug.sh ~/bin/debug

# Add user bin to PATH and create aliases
# Why: Makes scripts available as commands in all shells, not just interactive bash
RUN echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc && \
    echo 'export PATH="$HOME/bin:$PATH"' >> ~/.profile && \
    echo "alias start='bash $WORKDIR/scripts/start.sh'" >> ~/.bashrc && \
    echo "alias stop='bash $WORKDIR/scripts/stop.sh'" >> ~/.bashrc && \
    echo "alias restart='bash $WORKDIR/scripts/restart.sh'" >> ~/.bashrc && \
    echo "alias status='bash $WORKDIR/scripts/status.sh'" >> ~/.bashrc && \
    echo "alias debug='bash $WORKDIR/scripts/debug.sh'" >> ~/.bashrc

# Copy and configure entrypoint script
# Why: Entrypoint handles first-time setup (download Velocity, start proxy)
COPY --chown=${USER}:${USER} entrypoint.sh /home/${USER}/entrypoint.sh
RUN chmod +x /home/${USER}/entrypoint.sh

# Set entrypoint
# Why: This runs when container starts - downloads proxy if needed and starts it
ENTRYPOINT ["sh", "-c", "/home/$USER/entrypoint.sh"]

# Health check to ensure proxy is responsive
# Why: Docker can auto-restart if proxy becomes unresponsive or crashes
# Checks: 1) tmux session exists, 2) proxy hasn't stopped (no "Closing endpoint" in logs)
HEALTHCHECK --interval=30s --timeout=10s --start-period=3m --retries=3 \
    CMD bash -c 'tmux has-session -t velocity 2>/dev/null && ! tail -3 /velocity/logs/latest.log 2>/dev/null | grep -q "Closing endpoint" || exit 1'
