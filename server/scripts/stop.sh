#!/bin/bash

# Force save all world data before stopping
# Why: Ensures zero data loss by saving everything before shutdown
echo "Saving world data..."
tmux send-keys -t $TMUX_SESSION "save-all" ENTER
sleep 2

# Send "stop" command to the server console via tmux
# Why: Graceful shutdown lets server close connections properly after saving
tmux send-keys -t $TMUX_SESSION "stop" ENTER
echo "Stopping Minecraft server..."

# Wait for server to finish shutdown process
# Why: Need to ensure server is fully stopped before killing tmux session
while true; do
    # Check last 3 lines of log (suppresses errors if log doesn't exist)
    LAST_LINE=$(tail -3 $WORKDIR/logs/latest.log 2>/dev/null)

    # Server prints "Closing Server" when shutdown is complete
    if echo "$LAST_LINE" | grep -q "Closing Server"; then
        echo "Server has stopped!"
        break
    fi
    sleep 1
done

# Clean up the tmux session
# Why: Tmux session persists even after server stops, this cleans it up
tmux kill-session -t $TMUX_SESSION
echo "Minecraft server stopped!"
