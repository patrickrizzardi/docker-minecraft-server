#!/bin/bash

# Using optimized JVM flags for Velocity proxy
# Why: Proxies need low latency, not high throughput like servers
COMMAND="java -Xms1G -Xmx1G -XX:+UseG1GC -XX:G1HeapRegionSize=4M -XX:+UnlockExperimentalVMOptions -XX:+ParallelRefProcEnabled -XX:+AlwaysPreTouch -XX:MaxInlineLevel=15 -jar $WORKDIR/velocity*.jar"

# Create tmux session if it doesn't exist
# Why: Keeps proxy running in background so we can attach/detach without killing it
if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    echo "No tmux session found, creating one..."
    tmux new-session -d -s "$TMUX_SESSION"
fi

echo "Starting Velocity server..."
tmux send-keys -t "$TMUX_SESSION" "$COMMAND" ENTER

# Wait for proxy to fully start before proceeding
# Why: We need the proxy to generate default config files before we can symlink them
while true; do
    # Get the last line of the log file (2>/dev/null suppresses errors if log doesn't exist yet)
    LAST_LINE=$(tail -1 $WORKDIR/logs/latest.log 2>/dev/null)

    # Proxy is fully started when it prints "Done"
    if echo "$LAST_LINE" | grep -q "Done"; then
        echo "Server has started!"
        break
    fi
    sleep 1
done

# Velocity config files to persist
# Why: velocity.toml has all settings, forwarding.secret is the player info security key
CONFIG_FILES="velocity.toml forwarding.secret"

# CONFIG PERSISTENCE STRATEGY:
# Why: Docker containers are ephemeral - rebuilding destroys everything inside
# Solution: Store configs in a mounted /config volume and symlink them to where the proxy expects them
# Benefit: Configs survive container rebuilds, and you can edit them from the host machine
if [ -d /config ]; then
    # STEP 1: Copy default configs to persistent storage (first run only)
    # Why: Only copy if config doesn't exist in /config AND exists in WORKDIR
    # This handles: first-time setup + optional files that might not exist
    for file in $CONFIG_FILES; do
        if [ ! -f /config/$file ] && [ -f $WORKDIR/$file ]; then
            echo "Copying $file to /config"
            cp $WORKDIR/$file /config/$file
        fi
    done

    # STEP 2: Replace generated configs with symlinks to persistent storage
    # Why: Proxy expects configs in WORKDIR, but we want them to actually live in /config
    # The symlinks make the proxy think files are in WORKDIR while they're actually in /config
    for file in $CONFIG_FILES; do
        filename=$(basename $file)
        # Only create symlink if the file actually exists in /config
        # Why: Avoids creating broken symlinks for optional files that were never created
        if [ -f /config/$file ]; then
            # Remove the original file if it exists (can't symlink over an existing file)
            if [ -f $WORKDIR/$filename ]; then
                echo "Removing $filename from $WORKDIR so we can create a symlink"
                rm $WORKDIR/$filename
            fi
            echo "Creating symlink for $filename"
            ln -s /config/$file $WORKDIR/$filename
        fi
    done
fi
