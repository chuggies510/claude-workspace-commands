#!/usr/bin/env bash
# PCA project progress calculation - sourced by /start command
# Outputs: PROGRESS line, task list, PHASE line
[ ! -f "PROJECT-CHECKLIST.md" ] && { return 0 2>/dev/null; exit 0; }

TOTAL=$(grep -c "^- \[" PROJECT-CHECKLIST.md 2>/dev/null || echo 0)
DONE=$(grep -c "^- \[x\]" PROJECT-CHECKLIST.md 2>/dev/null || echo 0)
[ "$TOTAL" -gt 0 ] && PERCENT=$((DONE * 100 / TOTAL)) || PERCENT=0
echo "PROGRESS: $DONE/$TOTAL ($PERCENT%)"

awk '
  /^## Phase [0-9]+:/ { phase=$0; sub(/^## /, "", phase); if (found) exit }
  /^- \[ \]/ && !found { found=1; target=phase; in_target=1 }
  in_target && /^- \[/ { print }
  END { if (target) print "PHASE:", target; else print "PHASE: Phase 6: Delivery" }
' PROJECT-CHECKLIST.md
