#!/bin/bash

# Check if proxy is actually running before attempting restart
# Why: No point stopping a proxy that's not running

# Check 1: Does tmux session exist?
# Why: If no tmux session, proxy definitely isn't running
if ! tmux has-session -t $TMUX_SESSION 2>/dev/null; then
    echo "Velocity server is not running! Starting..."
    bash $WORKDIR/scripts/start.sh
    exit 0
fi

# Check 2: Is proxy process actually alive in the tmux session?
# Why: Tmux session might exist but proxy could be stopped/crashed
LAST_LINE=$(tail -3 $WORKDIR/logs/latest.log 2>/dev/null)
if echo "$LAST_LINE" | grep -q "Closing endpoint"; then
    echo "Velocity server is not running! Starting..."
    bash $WORKDIR/scripts/start.sh
    exit 0
fi

# Proxy is running, initiate graceful shutdown
# Why: Graceful stop ensures player connections are closed properly
# Note: Velocity uses "shutdown" not "stop"
tmux send-keys -t $TMUX_SESSION "shutdown" ENTER
echo "Stopping Velocity server..."

# Wait for proxy to fully stop
# Why: Starting before shutdown completes causes port conflicts
while true; do
    # IMPORTANT: Re-read log file each iteration (was a bug - infinite loop!)
    LAST_LINE=$(tail -3 $WORKDIR/logs/latest.log 2>/dev/null)
    
    # Check if shutdown is complete
    if echo "$LAST_LINE" | grep -q "Closing endpoint"; then
        echo "Server has stopped!"
        break
    fi
    sleep 1
done

# Start fresh proxy instance
# Why: Restart complete - fire it back up
echo "Velocity server stopped, restarting..."
bash $WORKDIR/scripts/start.sh
