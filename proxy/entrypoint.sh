#!/bin/bash

# Logging setup for Velocity proxy
# Why: Proper log management ensures we don't miss any proxy output

# Set up logging environment
export LOG_DIR="$WORKDIR/logs"
export LOG_FILE="$LOG_DIR/latest.log"

# Function to clean up on exit
_cleanup() {
    echo "Shutting down..."
    exit 0
}

# Set up signal handlers for graceful shutdown
trap _cleanup SIGTERM SIGINT

# Function to tail logs with rotation handling (runs in foreground)
# Why: Running in foreground ensures output goes directly to container stdout
_tail_logs_forever() {
    echo "Starting log monitor..."

    while true; do
        # Wait for log file to exist
        while [ ! -f "$LOG_FILE" ]; do
            echo "Waiting for log file to be created..."
            sleep 2
        done

        echo "Tailing log file: $LOG_FILE"

        # Use tail -F (capital F) which handles rotation automatically
        # -F = --follow=name --retry (follows by name, retries if file disappears)
        # This handles log rotation gracefully - when latest.log is rotated,
        # tail -F will detect the new file and continue following
        tail -F "$LOG_FILE" 2>/dev/null

        # If tail exits (shouldn't happen with -F unless killed), wait and retry
        echo "Log tail exited, restarting in 2 seconds..."
        sleep 2
    done
}

# Determine desired version from environment or use latest
# Why: Check what version is configured and ensure we have the correct JAR
BASE_URL="https://api.papermc.io/v2/projects/$PROJECT"

# Auto-detect latest version if VERSION env var not set
# Why: Makes updates easier - just rebuild without changing env vars
if [ -z "$VERSION" ]; then
    echo "No version specified, using latest version..."
    VERSION=$(curl -s $BASE_URL | jq -r '.versions[-1]')
    BUILD=$(curl -s $BASE_URL/versions/$VERSION | jq -r '.builds[-1]')
fi

# Auto-detect latest build for the specified version
# Why: Each Velocity version has multiple builds - grab the most stable one
if [ -z "$BUILD" ]; then
    echo "No build specified, using latest build..."
    BUILD=$(curl -s $BASE_URL/versions/$VERSION | jq -r '.builds[-1]')
fi

# Check if we need to download/update the JAR
# Why: Only download if JAR doesn't exist or doesn't match desired version
EXPECTED_JAR="$WORKDIR/$PROJECT-$VERSION-$BUILD.jar"
EXISTING_JAR=$(ls $WORKDIR/$PROJECT*.jar 2>/dev/null | head -1)

if [ ! -f "$EXPECTED_JAR" ]; then
    if [ -n "$EXISTING_JAR" ]; then
        echo "Existing JAR found: $(basename "$EXISTING_JAR")"
        echo "Desired version: $PROJECT-$VERSION-$BUILD.jar"
        echo "Version mismatch detected, downloading correct version..."
    else
        echo "No JAR found, downloading $PROJECT-$VERSION-$BUILD.jar..."
    fi
    
    VERSION_URL="$BASE_URL/versions/$VERSION/builds/$BUILD/downloads/$PROJECT-$VERSION-$BUILD.jar"
    echo "Downloading Velocity server..."
    wget $VERSION_URL -O "$EXPECTED_JAR"
    
    # Remove old JAR if it exists and is different
    if [ -n "$EXISTING_JAR" ] && [ "$EXISTING_JAR" != "$EXPECTED_JAR" ]; then
        echo "Removing old JAR: $(basename "$EXISTING_JAR")"
        rm -f "$EXISTING_JAR"
    fi
else
    echo "Correct JAR already exists: $PROJECT-$VERSION-$BUILD.jar"
fi

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Start proxy in background (& = don't wait for completion)
# Why: We need to tail logs while proxy is starting, not after it finishes
bash $WORKDIR/scripts/start.sh &

# Keep container alive by monitoring logs OR execute custom command
# Why: Docker containers die when their main process exits
# - No args: tail logs forever in foreground (keeps container running + outputs to stdout)
# - With args: execute custom command (for debugging/maintenance)
if [ $# = 0 ]; then
    # Run log tail in foreground - this is the main process now
    # Output goes directly to container stdout (visible via docker attach/logs)
    _tail_logs_forever
else
    exec "$@"
fi
