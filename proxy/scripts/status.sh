#!/bin/bash

# Check proxy status without disrupting it
# Why: Quick way to see if proxy is running and get basic info

echo "=== Velocity Proxy Status ==="
echo ""

# Check if tmux session exists
# Why: First indicator that proxy might be running
if ! tmux has-session -t $TMUX_SESSION 2>/dev/null; then
    echo "Status: ❌ NOT RUNNING"
    echo "Tmux session does not exist"
    echo ""
    echo "Start the proxy with: start"
    exit 0
fi

# Tmux session exists, check if proxy is actually alive
# Why: Tmux session can exist even if proxy crashed/stopped
if [ -f $WORKDIR/logs/latest.log ]; then
    LAST_LINE=$(tail -3 $WORKDIR/logs/latest.log 2>/dev/null)
    
    if echo "$LAST_LINE" | grep -q "Closing endpoint"; then
        echo "Status: ❌ STOPPED (tmux session still active)"
        echo "Proxy has stopped but tmux session exists"
        echo ""
        echo "Start the proxy with: start"
        exit 0
    elif echo "$LAST_LINE" | grep -q "Done"; then
        echo "Status: ✅ RUNNING"
        echo ""
        
        # Try to get proxy version info
        if [ -f $WORKDIR/$PROJECT*.jar ]; then
            JAR_FILE=$(ls $WORKDIR/$PROJECT*.jar 2>/dev/null | head -1)
            JAR_NAME=$(basename "$JAR_FILE")
            echo "Proxy: $JAR_NAME"
        fi
        
        # Get proxy configuration from velocity.toml
        # Why: Shows how to connect and other useful runtime info
        if [ -f $WORKDIR/velocity.toml ]; then
            # Extract bind address (format: bind = "0.0.0.0:25577")
            BIND=$(grep "^bind = " $WORKDIR/velocity.toml 2>/dev/null | cut -d'"' -f2)
            PORT=$(echo "$BIND" | cut -d':' -f2)
            
            # Extract show-max-players
            MAX_PLAYERS=$(grep "^show-max-players = " $WORKDIR/velocity.toml 2>/dev/null | awk '{print $3}')
            
            # Extract motd (it's usually multi-line, so just get the first component)
            MOTD=$(grep -A1 "^\[motd\]" $WORKDIR/velocity.toml 2>/dev/null | grep "^component = " | head -1 | cut -d'"' -f2)
            
            echo "Port: ${PORT:-25577}"
            [ -n "$MAX_PLAYERS" ] && echo "Max Players: $MAX_PLAYERS"
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
        echo "Proxy is currently starting up"
        echo ""
        echo "Watch logs with: tail -f logs/latest.log"
        exit 0
    fi
else
    echo "Status: ❓ UNKNOWN"
    echo "Tmux session exists but no log file found"
    exit 0
fi

