#!/usr/bin/env bash
# detect-context.sh - Shared context detection for /start and /stop commands
# Location: ~/2_project-files/_shared/scripts/detect-context.sh
# Usage: source ~/2_project-files/_shared/scripts/detect-context.sh
#
# Exports: PROJECT_TYPE, CURRENT_MACHINE, CURRENT_IP, SESSION_NUMBER

# Project type detection (first match wins)
PROJECT_TYPE="generic"
if [ -f "emergency.md" ]; then
    PROJECT_TYPE="infrastructure"
elif [ -f "PROJECT-CHECKLIST.md" ] && { [ -d "cards" ] || [ -d "analysis" ]; }; then
    PROJECT_TYPE="pca"
elif [ -d "dev" ] && [ -f ".claude/memory-bank/backport-tracker.md" ]; then
    PROJECT_TYPE="meap"
fi

# Machine detection with explicit error handling
if [ "$(uname -s)" = "Darwin" ]; then
    CURRENT_MACHINE="mac-mini"
    DEFAULT_IFACE=$(route -n get default 2>/dev/null | grep interface | awk '{print $2}')
    if [ -n "$DEFAULT_IFACE" ]; then
        CURRENT_IP=$(ipconfig getifaddr "$DEFAULT_IFACE" 2>/dev/null || echo "unknown")
    else
        CURRENT_IP="unknown"
    fi
else
    CURRENT_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "unknown")
    case "$(hostname)" in
        dev-pi|DietPi5) CURRENT_MACHINE="dev-pi" ;;
        infra-pi) CURRENT_MACHINE="infra-pi" ;;
        *) CURRENT_MACHINE="unknown" ;;
    esac
fi

# Session number from active-context.md (tr -d '\r' handles CRLF line endings from Syncthing)
SESSION_NUMBER=$(awk '/^session:/ {print $2; exit}' .claude/memory-bank/active-context.md 2>/dev/null | tr -d '\r')
[[ "$SESSION_NUMBER" =~ ^[0-9]+$ ]] || SESSION_NUMBER=0
