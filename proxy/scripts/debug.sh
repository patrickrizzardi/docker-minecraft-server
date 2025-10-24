#!/bin/bash

# Check if proxy is running before trying to attach
# Why: Tmux gives a cryptic error if session doesn't exist - give a helpful message instead
if ! tmux has-session -t $TMUX_SESSION 2>/dev/null; then
    echo "❌ Velocity server is not running!"
    echo "Start it with: start"
    exit 1
fi

# Attach to the running proxy console
# Why: Gives you direct access to proxy console for commands/debugging
# To detach without stopping proxy: Press Ctrl+B, then D
echo "Attaching to server console... (Ctrl+B then D to detach)"
tmux attach -t $TMUX_SESSION
