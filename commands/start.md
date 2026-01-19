---
name: start
version: v2.1.0
allowed-tools: Read, Glob, Grep, Bash
description: Universal session initialization - detects project type and loads context
argument-hint: [optional task description]
thinking: true
---

# Session Initialization

Your memory resets between sessions. This command loads project context from the Memory Bank.

## Configuration Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| STALENESS_WARNING_DAYS | 7 | Warn if last handoff older than this |
| OPEN_ISSUES_WARNING | 5 | Warn if more open issues than this |
| DEFAULT_DELIVERY_PHASE | 6 | PCA phase number when all tasks complete |

---

## 0. Detect Project Type

**SYNC NOTE**: This detection logic is duplicated in both /start and /stop commands. Keep them synchronized when updating.

Determine project type from current working directory and file markers.

**Detection priority** (first match wins):

```bash
PROJECT_ROOT=$(pwd)
PROJECT_TYPE="generic"

# 1. Infrastructure: emergency.md exists (chungus-net pattern)
if [ -f "emergency.md" ]; then
    PROJECT_TYPE="infrastructure"
# 2. PCA: PROJECT-CHECKLIST.md + (cards/ OR analysis/ directory)
elif [ -f "PROJECT-CHECKLIST.md" ] && { [ -d "cards" ] || [ -d "analysis" ]; }; then
    PROJECT_TYPE="pca"
# 3. MEAP: dev/ directory + backport-tracker.md
elif [ -d "dev" ] && [ -f ".claude/memory-bank/backport-tracker.md" ]; then
    PROJECT_TYPE="meap"
fi

echo "Detected project type: $PROJECT_TYPE"
```

Report detected type in output.

---

## 0.5 Detect Current Machine

**Why this matters**: Knowing where Claude is running affects what operations are safe. Don't run stress tests on your own host. Don't SSH to yourself.

```bash
if [ "$(uname -s)" = "Darwin" ]; then
    CURRENT_MACHINE="mac-mini"
else
    case "$(hostname)" in
        DietPi5)  CURRENT_MACHINE="dev-pi" ;;
        DietPi)   CURRENT_MACHINE="infra-pi" ;;
        *)        CURRENT_MACHINE="unknown ($(hostname))" ;;
    esac
fi
echo "Running on: $CURRENT_MACHINE"
```

Include in session header output.

**Operational implications**:
| Running on | Safe operations | Avoid |
|------------|-----------------|-------|
| mac-mini | SSH to any Pi, stress tests on Pis | - |
| dev-pi | SSH to infra-pi, local dev work | Stress tests on self, heavy CPU ops |
| infra-pi | Read-only checks, emergencies only | Almost everything - this is production |

---

## 1. Load Memory Bank

Read all context files. Skip gracefully if any file is missing.

**Universal files** (all project types):
1. `.claude/memory-bank/README.md` - Content routing guidance
2. `.claude/memory-bank/project-brief.md` - Mission, constraints, success criteria
3. `.claude/memory-bank/active-context.md` - Recent handoffs, current work, open issues
4. `.claude/memory-bank/tech-context.md` - Reference data, paths, commands
5. `.claude/memory-bank/system-patterns.md` - Architecture, data flows, connections
6. `CLAUDE.md` - Project-specific gotchas

**MEAP projects only** (if files exist):
7. `.claude/memory-bank/backport-tracker.md` - Client innovation tracking
8. `.claude/memory-bank/deployment-log.md` - Deployment history

### Parse active-context.md

Extract session metadata:
- **Session number**: From `session:` YAML frontmatter. Default to 0 if missing/invalid.
- **Last handoff date**: From most recent `## CONTEXT HANDOFF - YYYY-MM-DD` header
- **Current work focus**: From `## Current Work Focus` section
- **Open issues**: From most recent handoff's `### Open Issues` section
- **Next session priority**: From most recent handoff's `### Next Session Priority` section

**Validate YAML frontmatter**:
```bash
head -5 .claude/memory-bank/active-context.md | grep -n "^---$"
```

If malformed, warn but continue: `[WARN] active-context.md: YAML frontmatter malformed`

**First session case**: If no handoffs exist, display "First session" and skip handoff-derived fields.

---

## 2. Project-Specific Context

### If PROJECT_TYPE == "pca"

Parse `PROJECT-CHECKLIST.md` for progress and current phase using single-pass awk:

```bash
# Calculate progress
TOTAL_TASKS=$(grep -c "^- \[" PROJECT-CHECKLIST.md 2>/dev/null || echo 0)
DONE_TASKS=$(grep -c "^- \[x\]" PROJECT-CHECKLIST.md 2>/dev/null || echo 0)
if [ "$TOTAL_TASKS" -gt 0 ]; then
    PERCENT=$(awk "BEGIN {printf \"%.0f\", ($DONE_TASKS/$TOTAL_TASKS)*100}")
else
    PERCENT=0
fi
echo "PROGRESS: $DONE_TASKS/$TOTAL_TASKS ($PERCENT%)"

# Single-pass extraction of current phase and its tasks
awk '
  /^## Phase [0-9]+:/ {
    phase_num = $3
    sub(/:$/, "", phase_num)
    phase_name = substr($0, index($0, ":") + 2)
    current_phase = "Phase " phase_num ": " phase_name
    if (found_first_incomplete) in_target = 0
  }
  /^- \[ \]/ && !found_first_incomplete {
    found_first_incomplete = 1
    target_phase = current_phase
    in_target = 1
  }
  in_target && /^- \[/ {
    tasks = tasks $0 "\n"
  }
  /^## Phase [0-9]+:/ && in_target && found_first_incomplete {
    exit
  }
  END {
    # DEFAULT_DELIVERY_PHASE = 6 (see Configuration Constants)
    print "PHASE:", (target_phase ? target_phase : "Phase 6: Delivery")
    print "---TASKS---"
    printf "%s", tasks
  }
' PROJECT-CHECKLIST.md
```

### If PROJECT_TYPE == "meap"

Check backport-tracker.md for pending backports:

```bash
if [ -f ".claude/memory-bank/backport-tracker.md" ]; then
    PENDING=$(grep -c "^\- \[ \]" .claude/memory-bank/backport-tracker.md 2>/dev/null || echo 0)
    if [ "$PENDING" -gt 0 ]; then
        echo "PENDING BACKPORTS: $PENDING"
    fi
fi
```

### If PROJECT_TYPE == "infrastructure"

No additional context loading. Infrastructure projects prioritize fast startup.

### If PROJECT_TYPE == "generic"

No additional context loading.

---

## 3. Check External Changes

Check for commits since last Memory Bank update:

```bash
/usr/bin/env bash << 'BASHSCRIPT'
SINCE_DATE=$(git log -1 --format='%ci' -- .claude/memory-bank/ 2>/dev/null)
if [ -z "$SINCE_DATE" ]; then
    SINCE_DATE="7 days ago"
    echo "[FIRST SESSION] No prior Memory Bank commits"
fi
git log --oneline --since="$SINCE_DATE" -- . 2>/dev/null | grep -v "Claude" | head -10
BASHSCRIPT
```

If non-Claude commits found, report:
```
[EXTERNAL] N commits since last session:
- abc1234 Fix typo in config
- def5678 Update dependencies
```

Continue normally. User decides if Memory Bank needs updating.

---

## 4. Present Summary

Format varies by project type.

### All Project Types - Header

```
╔════════════════════════════════════════════════════════════════╗
║  [PROJECT NAME] - Session {N+1} Start                          ║
╚════════════════════════════════════════════════════════════════╝

Running on: {machine}
Last Session: {date} (Session {N})
```

### PCA Projects - Progress Section

```
Progress: {done}/{total} tasks ({percent}%)

## Checklist
{phase name}
{task list from bash output, preserving checkboxes}
```

**Task display rules:**
- Show all tasks from current phase (both complete and incomplete)
- Preserve original checkbox format: `- [x]` or `- [ ]`
- If current phase has >6 tasks, show only incomplete tasks plus last 2 completed

### MEAP Projects - Backport Section

```
Pending Backports: {count} (check backport-tracker.md)
```

Only show if count > 0.

### All Project Types - Context Section

```
## Current Context
{Extract from "## Current Work Focus" section of active-context.md}

Open Issues: {count or "None"}

Next Priority: {from most recent handoff's "### Next Session Priority"}
```

### Staleness Warnings

- Last handoff >7 days: `[STALE] Context may be stale - verify before acting`
- Open issues >5: `[WARN] Many open issues - consider prioritizing`

### Footer

```
Context loaded. Ready to execute.
```

---

## 5. Task Context (if $ARGUMENTS provided)

Search for task mentions in:
- active-context.md handoffs
- CLAUDE.md gotchas
- tech-context.md references
- system-patterns.md flows

Present relevant context found, or "No prior context for this task."

---

## 6. Ready for Work

- If user provided task in $ARGUMENTS → Begin work on that task immediately
- If no task specified → Prompt: "What should we work on this session?"

**Good questions spark discovery** - only ask if context raises specific concerns:
- Blockers or constraints in handoffs?
- Clarification needed on open issues?

**Don't ask generic questions.** Don't create todo lists during /start - that comes after, when you begin actual work.

---

**Speed target**: <30 seconds (file reads only, no agents)
**No agents**: Fast startup > perfect intelligence
