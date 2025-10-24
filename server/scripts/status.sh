#!/bin/bash

# Check server status without disrupting it
# Why: Quick way to see if server is running and get basic info

echo "=== Minecraft Server Status ==="
echo ""

# Check if tmux session exists
# Why: First indicator that server might be running
if ! tmux has-session -t $TMUX_SESSION 2>/dev/null; then
    echo "Status: ❌ NOT RUNNING"
    echo "Tmux session does not exist"
    echo ""
    echo "Start the server with: start"
    exit 0
fi

# Tmux session exists, check if server is actually alive
# Why: Tmux session can exist even if server crashed/stopped
if [ -f $WORKDIR/logs/latest.log ]; then
    LAST_LINE=$(tail -3 $WORKDIR/logs/latest.log 2>/dev/null)
    
    if echo "$LAST_LINE" | grep -q "Closing Server"; then
        echo "Status: ❌ STOPPED (tmux session still active)"
        echo "Server has stopped but tmux session exists"
        echo ""
        echo "Start the server with: start"
        exit 0
    elif echo "$LAST_LINE" | grep -q "Done"; then
        echo "Status: ✅ RUNNING"
        echo ""
        
        # Try to get server version info
        if [ -f $WORKDIR/$PROJECT*.jar ]; then
            JAR_FILE=$(ls $WORKDIR/$PROJECT*.jar 2>/dev/null | head -1)
            JAR_NAME=$(basename "$JAR_FILE")
            echo "Server: $JAR_NAME"
        fi
        
        # Get server configuration from server.properties
        # Why: Shows how to connect and other useful runtime info
        if [ -f $WORKDIR/server.properties ]; then
            PORT=$(grep "^server-port=" $WORKDIR/server.properties 2>/dev/null | cut -d'=' -f2)
            MAX_PLAYERS=$(grep "^max-players=" $WORKDIR/server.properties 2>/dev/null | cut -d'=' -f2)
            MOTD=$(grep "^motd=" $WORKDIR/server.properties 2>/dev/null | cut -d'=' -f2)
            GAMEMODE=$(grep "^gamemode=" $WORKDIR/server.properties 2>/dev/null | cut -d'=' -f2)
            DIFFICULTY=$(grep "^difficulty=" $WORKDIR/server.properties 2>/dev/null | cut -d'=' -f2)
            
            echo "Port: ${PORT:-25565}"
            echo "Max Players: ${MAX_PLAYERS:-20}"
            echo "Gamemode: ${GAMEMODE:-survival}"
            echo "Difficulty: ${DIFFICULTY:-normal}"
            [ -n "$MOTD" ] && echo "MOTD: $MOTD"
        fi
        
        # Show last few log lines for context
        echo ""
        echo "Recent activity:"
        tail -5 $WORKDIR/logs/latest.log | sed 's/^/  /'
        echo ""
        echo "Attach to console with: debug"
        exit 0
    else
        echo "Status: 🔄 STARTING..."
        echo "Server is currently starting up"
        echo ""
        echo "Watch logs with: tail -f logs/latest.log"
        exit 0
    fi
else
    echo "Status: ❓ UNKNOWN"
    echo "Tmux session exists but no log file found"
    exit 0
fi

