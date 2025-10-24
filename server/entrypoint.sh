#!/bin/bash

# Enhanced logging setup with rotation detection and old log handling
# Why: Proper log management ensures we don't miss any server output and handle log rotation gracefully

# Set up logging environment
export LOG_DIR="$WORKDIR/logs"
export LOG_FILE="$LOG_DIR/latest.log"
export LOG_PATTERN="$LOG_DIR/*.log*"
export LOG_AGGREGATOR_PID_FILE="/tmp/log_aggregator.pid"

# Function to clean up background processes on exit
_cleanup() {
    echo "Cleaning up background processes..."
    if [ -f "$LOG_AGGREGATOR_PID_FILE" ]; then
        local pid=$(cat "$LOG_AGGREGATOR_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
        fi
        rm -f "$LOG_AGGREGATOR_PID_FILE"
    fi
    exit 0
}

# Set up signal handlers for graceful shutdown
trap _cleanup SIGTERM SIGINT

# Function to start log aggregator that monitors all log files
_start_log_aggregator() {
    # Kill any existing log aggregator
    if [ -f "$LOG_AGGREGATOR_PID_FILE" ]; then
        local old_pid=$(cat "$LOG_AGGREGATOR_PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            kill "$old_pid" 2>/dev/null
        fi
        rm -f "$LOG_AGGREGATOR_PID_FILE"
    fi

    # Start log aggregator in background
    (
        echo "Starting log aggregator..."
        
        # Function to tail all log files and output to stdout
        _tail_all_logs() {
            # Find all log files (including rotated ones)
            local log_files=($(find "$LOG_DIR" -name "*.log*" -type f 2>/dev/null | sort))
            
            if [ ${#log_files[@]} -eq 0 ]; then
                echo "No log files found, waiting..."
                return
            fi
            
            # If we have multiple log files, we need to handle them intelligently
            if [ ${#log_files[@]} -gt 1 ]; then
                # Sort by modification time, newest first
                local sorted_files=($(ls -t "${log_files[@]}" 2>/dev/null))
                
                # Tail the newest file for live updates
                local newest_file="${sorted_files[0]}"
                echo "Tailing newest log file: $newest_file"
                
                # Also show recent content from older files if they exist
                for file in "${sorted_files[@]:1}"; do
                    if [ -f "$file" ] && [ -s "$file" ]; then
                        echo "=== Recent content from $(basename "$file") ==="
                        # Check if file is compressed and handle accordingly
                        if [[ "$file" == *.gz ]]; then
                            zcat "$file" 2>/dev/null | tail -20 | sed 's/^/  /'
                        else
                            tail -20 "$file" 2>/dev/null | sed 's/^/  /'
                        fi
                        echo "=== End of $(basename "$file") ==="
                    fi
                done
                
                # Now tail the newest file for live updates
                tail -f "$newest_file" 2>/dev/null
            else
                # Single log file, just tail it
                echo "Tailing log file: ${log_files[0]}"
                tail -f "${log_files[0]}" 2>/dev/null
            fi
        }
        
        # Monitor for new log files and restart tailing when rotation occurs
        while true; do
            _tail_all_logs
            
            # If tail exits, wait a moment and check for new files
            sleep 2
            
            # Check if we should exit (container is shutting down)
            if [ ! -f "$LOG_AGGREGATOR_PID_FILE" ]; then
                break
            fi
        done
    ) &
    
    # Store the PID
    echo $! > "$LOG_AGGREGATOR_PID_FILE"
    echo "Log aggregator started with PID: $(cat "$LOG_AGGREGATOR_PID_FILE")"
}

# Download Paper server JAR if it doesn't exist
# Why: First-time container setup or after volume wipe needs the server binary
if [ ! -f $WORKDIR/$PROJECT*.jar ]; then
    # Downloads API docs: https://api.papermc.io/docs/swagger-ui/index.html?configUrl=/openapi/swagger-config#/download-controller/download
    BASE_URL="https://api.papermc.io/v2/projects/$PROJECT"
    
    # Auto-detect latest version if VERSION env var not set
    # Why: Makes updates easier - just rebuild without changing env vars
    if [ -z "$VERSION" ]; then
        echo "No version specified, using latest version..."
        VERSION=$(curl -s $BASE_URL | jq -r '.versions[-1]')
        BUILD=$(curl -s $BASE_URL/versions/$VERSION | jq -r '.builds[-1]')
    fi

    # Auto-detect latest build for the specified version
    # Why: Each MC version has multiple Paper builds - grab the most stable one
    if [ -z "$BUILD" ]; then
        echo "No build specified, using latest build..."
        BUILD=$(curl -s $BASE_URL/versions/$VERSION | jq -r '.builds[-1]')
    fi

    VERSION_URL="$BASE_URL/versions/$VERSION/builds/$BUILD/downloads/$PROJECT-$VERSION-$BUILD.jar"

    echo "Downloading Minecraft server..."
    wget $VERSION_URL -O $WORKDIR/$PROJECT-$VERSION-$BUILD.jar
fi

# Auto-accept Minecraft EULA
# Why: Mojang requires EULA acceptance before server starts
if [ ! -f $WORKDIR/eula.txt ]; then
    echo "eula=$EULA" >$WORKDIR/eula.txt
fi

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Pre-create log file to avoid race conditions
# Why: Prevents errors when scripts try to tail a non-existent log during startup
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

# Start log aggregator first
_start_log_aggregator

# Start server in background (& = don't wait for completion)
# Why: We need to tail logs while server is starting, not after it finishes
bash $WORKDIR/scripts/start.sh &

# Wait for log file to be created before proceeding
# Why: tail -f will error if file doesn't exist yet
while [ ! -f "$LOG_FILE" ]; do
    sleep 1
done

# Keep container alive by monitoring logs OR execute custom command
# Why: Docker containers die when their main process exits
# - No args: monitor logs forever (keeps container running)
# - With args: execute custom command (for debugging/maintenance)
if [ $# = 0 ]; then
    # Wait for the log aggregator process
    if [ -f "$LOG_AGGREGATOR_PID_FILE" ]; then
        pid=$(cat "$LOG_AGGREGATOR_PID_FILE")
        wait "$pid" 2>/dev/null || true
    fi
else
    exec "$@"
fi
