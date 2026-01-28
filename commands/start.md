---
name: start
version: v3.0.0
allowed-tools: Read, Glob, Grep, Bash
description: Universal session initialization - detects project type and loads context
argument-hint: [optional task description]
thinking: true
---

# Session Initialization

Your memory resets between sessions. This command loads project context from the Memory Bank.

**Thresholds**: Stale >7 days, warn >5 issues, PCA delivery phase 6.

---

## 0. Detect Context

```bash
source ~/2_project-files/.claude/scripts/detect-context.sh || { echo "ERROR: Failed to load detect-context.sh"; exit 1; }
echo "PROJECT_TYPE=$PROJECT_TYPE"
echo "CURRENT_MACHINE=$CURRENT_MACHINE ($CURRENT_IP)"
echo "SESSION_NUMBER=$SESSION_NUMBER"

# External changes since last Memory Bank update
SINCE_DATE=$(git log -1 --format='%ci' -- .claude/memory-bank/ 2>/dev/null)
[ -z "$SINCE_DATE" ] && SINCE_DATE="7 days ago" && echo "[FIRST SESSION]"
EXTERNAL=$(git log --oneline --since="$SINCE_DATE" -- . 2>/dev/null | grep -v "Claude" | head -10)
echo "=== External Changes ===" && echo "${EXTERNAL:-None}"

# Ralph session check
if [ -d "dev/ralph/active" ] && [ -f "dev/ralph/active/IMPLEMENTATION_PLAN.md" ]; then
    FEATURE=$(grep "^- Feature:" dev/ralph/active/IMPLEMENTATION_PLAN.md | head -1 | cut -d: -f2 | xargs)
    PENDING=$(grep -c "\*\*Status\*\*: pending" dev/ralph/active/IMPLEMENTATION_PLAN.md 2>/dev/null || echo 0)
    COMPLETE=$(grep -c "\*\*Status\*\*: complete" dev/ralph/active/IMPLEMENTATION_PLAN.md 2>/dev/null || echo 0)
    echo "=== Ralph Session ===" && echo "Feature: $FEATURE ($COMPLETE done, $PENDING pending)"
fi
```

---

## 1. Load Memory Bank

Read in parallel: `.claude/memory-bank/project-brief.md`, `active-context.md`, `tech-context.md`, `system-patterns.md`, `CLAUDE.md`
MEAP only: `backport-tracker.md`, `deployment-log.md`

From active-context.md extract: last handoff date (from `## CONTEXT HANDOFF` header), current focus, open issues, next priority. First session if no handoffs exist.

---

## 2. Project-Specific Context

### PCA projects
```bash
bash ~/2_project-files/.claude/scripts/pca-progress.sh 2>/dev/null
```

### MEAP projects
```bash
[ -f ".claude/memory-bank/backport-tracker.md" ] && PENDING=$(grep -c "^- \[ \]" .claude/memory-bank/backport-tracker.md 2>/dev/null) && [ "$PENDING" -gt 0 ] && echo "PENDING BACKPORTS: $PENDING"
```

### Infrastructure/Generic
No additional context. Fast startup.

---

## 3. Output Format

Header box with project name + "Session {N+1} Start", then machine/IP and last session date.

**By type**:
- **PCA**: Progress fraction + percent, current phase name, phase tasks (incomplete + last 2 complete if >6)
- **MEAP**: Pending backport count if >0
- **Infrastructure/Generic**: Skip to context

**All types**: Current focus summary, open issues count, next priority, then footer "Context loaded. Ready to execute."

**Warnings**: `[STALE]` if >7 days since handoff. `[WARN]` if >5 open issues.

If Ralph active, include in header: `[RALPH] Active: {feature} — {done} done, {pending} pending`

---

## 4. Task Context

If $ARGUMENTS provided, search memory bank files for prior mentions. Show relevant context or "No prior context for this task."

---

## 5. Ready for Work

With $ARGUMENTS: begin work immediately.
Without: prompt "What should we work on this session?"

Only ask questions if context raises specific blockers. No generic questions, no todo lists during /start.

---

**Speed target**: <30 seconds (file reads only, no agents)
