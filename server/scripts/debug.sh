#!/bin/bash

# Check if server is running before trying to attach
# Why: Tmux gives a cryptic error if session doesn't exist - give a helpful message instead
if ! tmux has-session -t $TMUX_SESSION 2>/dev/null; then
    echo "❌ Minecraft server is not running!"
    echo "Start it with: start"
    exit 1
fi

# Attach to the running server console
# Why: Gives you direct access to server console for commands/debugging
# To detach without stopping server: Press Ctrl+B, then D
echo "Attaching to server console... (Ctrl+B then D to detach)"
tmux attach -t $TMUX_SESSION
