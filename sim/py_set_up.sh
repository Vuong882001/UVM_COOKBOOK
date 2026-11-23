#!/bin/sh

QUESTA_HOME="$HOME/questasim"
#export GUI
export DISPLAY=:0
export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR=/run/user/1000

# Save current directory
CURRENT_DIR=$(pwd)

# Run Questa setup script from its own directory
cd "$QUESTA_HOME" || exit 1

. ./setenv_questasim.sh
STATUS=$?

# Return to original directory
cd "$CURRENT_DIR" || exit 1

return "$STATUS" 2>/dev/null || exit "$STATUS"
