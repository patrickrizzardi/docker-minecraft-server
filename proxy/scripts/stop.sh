#!/bin/bash

# Send "shutdown" command to the proxy console via tmux
# Why: Graceful shutdown lets proxy close player connections properly
# Note: Velocity uses "shutdown" not "stop"
tmux send-keys -t $TMUX_SESSION "shutdown" ENTER
echo "Stopping Velocity server..."

# Wait for proxy to finish shutdown process
# Why: Need to ensure proxy is fully stopped before killing tmux session
while true; do
    # Check last line of log (suppresses errors if log doesn't exist)
    LAST_LINE=$(tail -1 $WORKDIR/logs/latest.log 2>/dev/null)

    # Proxy prints "Closing endpoint" when shutdown is complete
    if echo "$LAST_LINE" | grep -q "Closing endpoint"; then
        echo "Server has stopped!"
        break
    fi
    sleep 1
done

# Clean up the tmux session
# Why: Tmux session persists even after proxy stops, this cleans it up
tmux kill-session -t $TMUX_SESSION
echo "Velocity server stopped!"
