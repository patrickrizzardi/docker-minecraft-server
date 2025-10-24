#!/bin/bash

# Check if server is actually running before attempting restart
# Why: No point stopping a server that's not running

# Check 1: Does tmux session exist?
# Why: If no tmux session, server definitely isn't running
if ! tmux has-session -t $TMUX_SESSION 2>/dev/null; then
    echo "Minecraft server is not running! Starting..."
    bash $WORKDIR/scripts/start.sh
    exit 0
fi

# Check 2: Is server process actually alive in the tmux session?
# Why: Tmux session might exist but server could be stopped/crashed
LAST_LINE=$(tail -3 $WORKDIR/logs/latest.log 2>/dev/null)
if echo "$LAST_LINE" | grep -q "Closing Server"; then
    echo "Minecraft server is not running! Starting..."
    bash $WORKDIR/scripts/start.sh
    exit 0
fi

# Force save all world data before stopping
# Why: Ensures zero data loss by saving everything before restart
echo "Saving world data..."
tmux send-keys -t $TMUX_SESSION "save-all" ENTER
sleep 2

# Server is running, initiate graceful shutdown
# Why: Graceful stop ensures clean shutdown after saving
tmux send-keys -t $TMUX_SESSION "stop" ENTER
echo "Stopping Minecraft server..."

# Wait for server to fully stop
# Why: Starting before shutdown completes causes port conflicts and data corruption
while true; do
    # IMPORTANT: Re-read log file each iteration (was a bug - infinite loop!)
    LAST_LINE=$(tail -3 $WORKDIR/logs/latest.log 2>/dev/null)
    
    # Check if shutdown is complete
    if echo "$LAST_LINE" | grep -q "Closing Server"; then
        echo "Server has stopped!"
        break
    fi
    sleep 1
done

# Start fresh server instance
# Why: Restart complete - fire it back up
echo "Minecraft server stopped, restarting..."
bash $WORKDIR/scripts/start.sh
