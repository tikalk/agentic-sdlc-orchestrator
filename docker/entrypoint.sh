#!/bin/bash
# entrypoint.sh - Entrypoint for OpenCode agent pod
# Clones repo, checks out branch, and starts OpenCode server

set -e

# Add opencode to PATH (installed by opencode installer)
export PATH="$HOME/.opencode/bin:$PATH"

echo "========================================"
echo "  OpenCode Agent Pod Starting"
echo "========================================"
echo ""

# Show environment info
echo "Environment:"
echo "  TASK_ID: ${TASK_ID:-not set}"
echo "  GIT_REPO: ${GIT_REPO:-not set}"
echo "  GIT_BRANCH: ${GIT_BRANCH:-not set}"
echo "  TASK_CONTEXT_PATH: ${TASK_CONTEXT_PATH:-/workspace}"
echo "  OPENCODE_SERVER_USERNAME: ${OPENCODE_SERVER_USERNAME:-opencode}"
echo ""

# Create workspace if it doesn't exist
mkdir -p "${TASK_CONTEXT_PATH}"
cd "${TASK_CONTEXT_PATH}"

# Clone repository if GIT_REPO is set
if [ -n "$GIT_REPO" ]; then
    echo "📦 Cloning repository: $GIT_REPO"
    
    # Check if workspace is empty
    if [ -z "$(ls -A ${TASK_CONTEXT_PATH})" ]; then
        git clone "$GIT_REPO" .
        echo "✅ Repository cloned successfully"
    else
        echo "⚠️  Workspace not empty, skipping clone"
    fi
    
    # Checkout branch if specified and different from current
    if [ -n "$GIT_BRANCH" ]; then
        echo "🔄 Checking out branch: $GIT_BRANCH"
        git fetch origin
        git checkout "$GIT_BRANCH" || git checkout -b "$GIT_BRANCH"
        git pull origin "$GIT_BRANCH" || true
        echo "✅ Branch checked out"
    fi
    
    echo ""
fi

# Show current directory contents
echo "📁 Workspace contents:"
ls -la

echo ""
echo "========================================"
echo "  Starting OpenCode Server"
echo "========================================"
echo ""
echo "Server Configuration:"
echo "  Port: 4096"
echo "  Hostname: 0.0.0.0"
echo "  Username: ${OPENCODE_SERVER_USERNAME:-opencode}"
echo "  Password: ${OPENCODE_SERVER_PASSWORD:-not set}"
echo ""
echo "Ready to receive commands from OpenCode client"
echo ""

# Verify opencode is available
OPENCODE_BIN="$HOME/.opencode/bin/opencode"
if [ ! -x "$OPENCODE_BIN" ]; then
    echo "❌ Error: opencode binary not found at $OPENCODE_BIN"
    echo "   Searching for opencode..."
    find / -name 'opencode' -type f 2>/dev/null | head -5
    exit 1
fi

echo "✅ OpenCode binary found: $OPENCODE_BIN"
echo "✅ OpenCode version: $($OPENCODE_BIN --version 2>/dev/null || echo 'unknown')"
echo "✅ Server password: ${OPENCODE_SERVER_PASSWORD:-NOT SET}"
echo ""

# Start OpenCode server with explicit password
exec env OPENCODE_SERVER_PASSWORD="$OPENCODE_SERVER_PASSWORD" OPENCODE_SERVER_USERNAME="$OPENCODE_SERVER_USERNAME" "$OPENCODE_BIN" serve --port 4096 --hostname 0.0.0.0
