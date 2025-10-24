#!/bin/bash

# Using Aikar's flags for optimal Paper server performance
COMMAND="java -Xms12G -Xmx12G --add-modules=jdk.incubator.vector -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true -XX:G1NewSizePercent=40 -XX:G1MaxNewSizePercent=50 -XX:G1HeapRegionSize=16M -XX:G1ReservePercent=15 -jar $WORKDIR/paper*.jar --nogui"

# Create tmux session if it doesn't exist
# Why: Keeps server running in background so we can attach/detach without killing it
if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    echo "Creating new tmux session..."
    tmux new-session -d -s "$TMUX_SESSION"
fi

echo "Starting Minecraft server..."
tmux send-keys -t "$TMUX_SESSION" "$COMMAND" ENTER

# Wait for server to fully start before proceeding
# Why: We need the server to generate default config files before we can symlink them
while true; do
    # Get the last 3 lines of the log file (2>/dev/null suppresses errors if log doesn't exist yet)
    LAST_LINE=$(tail -3 $WORKDIR/logs/latest.log 2>/dev/null)

    # Check if we're catching the tail end of a previous server shutdown
    # Why: On restart, the old log might still contain "Closing Server" until the new log is written
    if echo "$LAST_LINE" | grep -q "Closing Server"; then
        sleep 1
        continue
    fi

    # Server is fully started when it prints "Done"
    if echo "$LAST_LINE" | grep -q "Done"; then
        echo "Server has started!"
        break
    fi
    sleep 1
done

# Standard Bukkit/Spigot/Paper config files that live in the root directory
CONFIG_FILES="banned-ips.json banned-players.json bukkit.yml commands.yml help.yml ops.json permissions.yml server.properties spigot.yml whitelist.json"

# Paper-specific config files that live in the config subdirectory
PAPER_CONFIG_FILES="paper-global.yml paper-world-defaults.yml"

# CONFIG PERSISTENCE STRATEGY:
# Why: Docker containers are ephemeral - rebuilding destroys everything inside
# Solution: Store configs in a mounted /config volume and symlink them to where the server expects them
# Benefit: Configs survive container rebuilds, and you can edit them from the host machine
if [ -d /config ]; then
    # STEP 1: Copy default configs to persistent storage (first run only)
    # Why: Only copy if config doesn't exist in /config AND exists in WORKDIR
    # This handles: first-time setup + optional files that might not exist (like permissions.yml)
    for file in $CONFIG_FILES; do
        if [ ! -f /config/$file ] && [ -f $WORKDIR/$file ]; then
            echo "Copying $file to /config"
            cp $WORKDIR/$file /config/$file
        fi
    done

    # Same logic for Paper config files (they live in a subdirectory)
    for file in $PAPER_CONFIG_FILES; do
        if [ ! -f /config/$file ] && [ -f $WORKDIR/config/$file ]; then
            echo "Copying $file to /config"
            cp $WORKDIR/config/$file /config/$file
        fi
    done

    # STEP 2: Replace generated configs with symlinks to persistent storage
    # Why: Server expects configs in WORKDIR, but we want them to actually live in /config
    # The symlinks make the server think files are in WORKDIR while they're actually in /config
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

    # Same symlink logic for Paper config files
    for file in $PAPER_CONFIG_FILES; do
        filename=$(basename $file)
        if [ -f /config/$file ]; then
            if [ -f $WORKDIR/config/$filename ]; then
                echo "Removing $filename from $WORKDIR/config so we can create a symlink"
                rm $WORKDIR/config/$filename
            fi
            echo "Creating symlink for $filename"
            ln -s /config/$file $WORKDIR/config/$filename
        fi
    done
fi
