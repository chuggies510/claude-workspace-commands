---
name: a-memory-audit
version: v2.0.0
allowed-tools: Read, Glob, Grep, Bash, Edit, Write, AskUserQuestion
description: Universal Memory Bank audit - detects project type, checks structure, content, staleness, consistency
argument-hint: "[structure|content|staleness|consistency|all|fix]"
thinking: true
---

# Memory Audit

Universal command for auditing Memory Bank files across project types.

| Arg | Scope |
|-----|-------|
| `structure` | Phase A only |
| `content` | Phase B only |
| `staleness` | Phase C only |
| `consistency` | Phase D only |
| `all` / empty | All phases |
| `fix` | All phases + apply fixes |

---

## 0. Detect Project Type

**SYNC NOTE**: This detection logic is duplicated in /start, /stop, and /a-memory-audit. Keep synchronized.

```bash
PROJECT_ROOT=$(pwd)
PROJECT_TYPE="generic"

# 1. Infrastructure: emergency.md exists
if [ -f "emergency.md" ]; then
    PROJECT_TYPE="infrastructure"
# 2. PCA: PROJECT-CHECKLIST.md + (cards/ OR analysis/ directory)
elif [ -f "PROJECT-CHECKLIST.md" ] && { [ -d "cards" ] || [ -d "analysis" ]; }; then
    PROJECT_TYPE="pca"
# 3. MEAP: dev/ directory + backport-tracker.md
elif [ -d "dev" ] && [ -f ".claude/memory-bank/backport-tracker.md" ]; then
    PROJECT_TYPE="meap"
fi

echo "Project type: $PROJECT_TYPE"
```

Extract session number for state tracking:

```bash
SESSION_NUMBER=$(awk '/^session:/ {print $2; exit}' .claude/memory-bank/active-context.md 2>/dev/null)
if ! [[ "$SESSION_NUMBER" =~ ^[0-9]+$ ]]; then
    SESSION_NUMBER=0
fi
echo "Session: $SESSION_NUMBER"
```

---

## Setup: Read All Files

Scan three levels. Read all files in parallel, skip gracefully if missing.

**Global** (`~/.claude/`):
- `~/.claude/CLAUDE.md`

**Workspace** (`~/2_project-files/`):
- `~/2_project-files/CLAUDE.md`

**Project** (current directory):
- `CLAUDE.md`
- `.claude/memory-bank/README.md`
- `.claude/memory-bank/project-brief.md`
- `.claude/memory-bank/active-context.md`
- `.claude/memory-bank/tech-context.md`
- `.claude/memory-bank/system-patterns.md`

**MEAP only** (if exist):
- `.claude/memory-bank/backport-tracker.md`
- `.claude/memory-bank/deployment-log.md`

Get baseline line counts:

```bash
echo "=== File Sizes ==="
wc -l ~/.claude/CLAUDE.md \
     ~/2_project-files/CLAUDE.md \
     CLAUDE.md \
     .claude/memory-bank/*.md 2>/dev/null | grep -v "^wc:"
```

---

## Phase A: Structure

Check file organization and routing compliance.

### A1. Header Scan

```bash
echo "=== CLAUDE.md Headers ==="
grep -n "^## \|^### " CLAUDE.md 2>/dev/null
```

### A2. Routing Rules

| Pattern | Belongs In |
|---------|------------|
| Gotcha header OR has `### ` children | CLAUDE.md |
| Overview, Profile, Scope, Building facts | project-brief.md |
| Commands, Workflow, Scripts, Agents, Versions | tech-context.md |
| Data Flow, Architecture, Patterns, Diagrams | system-patterns.md |
| Handoffs, Current Work, Session state | active-context.md |
| Generic patterns (no project nouns) | workspace CLAUDE.md |
| Machine-specific (IP, paths, shell) | global CLAUDE.md |

Non-gotcha `## ` sections in project CLAUDE.md are likely misplaced.

### A3. Memory Bank Pointer

```bash
grep -q "memory-bank\|Memory Bank" CLAUDE.md && echo "HAS_POINTER" || echo "MISSING_POINTER"
```

If `MISSING_POINTER`, recommend adding routing table at top of CLAUDE.md.

### A4. Duplicate Detection

Check for content appearing in multiple canonical locations:

```bash
echo "=== Checking for duplicates ==="
# Building facts should be in project-brief.md only
grep -l "Building\|Address\|Square [Ff]eet\|Stories" .claude/memory-bank/*.md CLAUDE.md 2>/dev/null | sort | uniq -c | awk '$1 > 1 {print "DUPLICATE: Building facts in", $2}'

# Commands/versions should be in tech-context.md only
grep -l "^## Commands\|^## Versions\|^| Command" .claude/memory-bank/*.md CLAUDE.md 2>/dev/null | sort | uniq -c | awk '$1 > 1 {print "DUPLICATE: Command tables in", $2}'

# Architecture should be in system-patterns.md only
grep -l "Data [Ff]low\|Architecture\|Deployment Model" .claude/memory-bank/*.md CLAUDE.md 2>/dev/null | sort | uniq -c | awk '$1 > 1 {print "DUPLICATE: Architecture in", $2}'
```

**Output**: List misplaced sections with recommended target file.

---

## Phase B: Content

Classify gotcha items in CLAUDE.md files.

### B1. Classification Rules

| Class | Action | Triggers |
|-------|--------|----------|
| TRAP | Keep in CLAUDE.md | fails, breaks, hangs, crashes, silent, wrong, missing, lost, never, don't, must not, careful, gotcha, trap, error, bug, issue, problem |
| DOC | Move to tech-context | overview, structure, workflow, methodology, table, list, reference, config, how to, pattern, example |
| GENERIC | Move to workspace | No project-specific nouns (see below) |
| DUPLICATE | Remove | >50% overlap with Memory Bank content |

### B2. Project Noun Detection

**MEAP nouns**: meap, proto, wordbank, backport, deploy, field-interface, m2-clients
**PCA nouns**: building, equipment, checklist, cards, analysis, cost, PCA, photos
**Infrastructure nouns**: server, service, network, systemd, caddy, docker, ssh

If gotcha contains NO project nouns → likely GENERIC, consider workspace CLAUDE.md.

### B3. Execution

For each `### ` section in project CLAUDE.md:
1. Count TRAP keywords vs DOC keywords
2. Check for project nouns
3. Check for overlap with Memory Bank files
4. Classify and record recommendation

**Output**: Table of gotchas with classification and action.

---

## Phase C: Staleness

Find outdated content.

### C1. Old Handoffs

```bash
current=$(awk '/^session:/ {print $2; exit}' .claude/memory-bank/active-context.md 2>/dev/null)
echo "Current session: $current"

grep -n "^## CONTEXT HANDOFF.*Session" .claude/memory-bank/active-context.md 2>/dev/null | while IFS=: read -r line rest; do
  sess=$(echo "$rest" | grep -oP 'Session \K\d+' 2>/dev/null || echo "$rest" | sed 's/.*Session \([0-9]*\).*/\1/')
  if [ -n "$sess" ] && [ "$current" -gt 0 ] && [ $((current - sess)) -gt 5 ]; then
    echo "STALE: Line $line - Session $sess ($(( current - sess )) sessions old)"
  fi
done
```

Handoffs >5 sessions old should be archived to `.claude/memory-bank/archive/`.

### C2. Broken Paths

```bash
check_paths() {
  local file=$1
  echo "=== Checking paths in $(basename "$file") ==="
  grep -oE '~/[A-Za-z0-9_./-]+' "$file" 2>/dev/null | sed 's/[,;:.)]*$//' | sort -u | while read -r path; do
    expanded="${path/#\~/$HOME}"
    [ -e "$expanded" ] && echo "OK: $path" || echo "BROKEN: $path"
  done
}

check_paths ".claude/memory-bank/system-patterns.md"
check_paths ".claude/memory-bank/tech-context.md"
```

### C3. Old Annotations

```bash
grep -n "FIXED Session\|TODO\|PENDING\|WIP\|OBSOLETE" CLAUDE.md .claude/memory-bank/*.md 2>/dev/null
```

Old "FIXED Session N" annotations can be removed after 10+ sessions.

### C4. Broken File References

```bash
# Check for references to files that don't exist
echo "=== Checking file references ==="
grep -ohE '\b[a-z0-9-]+\.md\b' CLAUDE.md .claude/memory-bank/*.md 2>/dev/null | sort -u | while read -r ref; do
  # Skip common markdown files and patterns
  case "$ref" in
    README.md|CLAUDE.md|*.local.md) continue ;;
  esac
  # Check if referenced file exists somewhere in project
  if ! find . -name "$ref" -type f 2>/dev/null | grep -q .; then
    echo "MISSING: $ref (referenced but not found)"
  fi
done | head -10
```

**Output**: List stale items with age and recommended action.

---

## Phase D: Consistency

Cross-reference Memory Bank claims against actual state. Checks vary by project type.

### D1. Universal Checks (all project types)

**Archive References**:

```bash
echo "=== Archive Reference Validation ==="
refs=$(grep -oE 'archive/[A-Za-z0-9_-]+\.md' .claude/memory-bank/active-context.md 2>/dev/null | sort -u)
if [ -d ".claude/memory-bank/archive" ]; then
  actual=$(ls .claude/memory-bank/archive/*.md 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/^/archive\//' | sort -u)
  for ref in $refs; do
    echo "$actual" | grep -q "^${ref}$" || echo "MISSING: $ref"
  done
  for file in $actual; do
    echo "$refs" | grep -q "^${file}$" || echo "ORPHANED: $file"
  done
else
  echo "No archive directory"
fi
```

### D2. MEAP-Specific Checks

**Agent Versions** (if PROJECT_TYPE == "meap"):

```bash
echo "=== Agent Version Validation ==="
refs=$(grep -oE '[a-z]+-agent-v[0-9.]+' .claude/memory-bank/tech-context.md 2>/dev/null | sort -u)
if [ -d "reference/deploy/agents" ]; then
  actual=$(ls reference/deploy/agents/*.md 2>/dev/null | xargs -n1 basename | sed 's/.md$//' | sort -u)
  for ref in $refs; do
    echo "$actual" | grep -q "^${ref}$" || echo "BROKEN_REF: $ref"
  done
fi
```

**Backport Status**:

```bash
if [ -f ".claude/memory-bank/backport-tracker.md" ]; then
  pending=$(grep -c "^\- \[ \]" .claude/memory-bank/backport-tracker.md 2>/dev/null || echo 0)
  completed=$(grep -c "^\- \[x\]" .claude/memory-bank/backport-tracker.md 2>/dev/null || echo 0)
  echo "Backports: $pending pending, $completed completed"
fi
```

### D3. PCA-Specific Checks

**Equipment Metrics** (if PROJECT_TYPE == "pca"):

```bash
echo "=== Metrics Validation ==="
# Check stated vs actual equipment count
stated=$(grep -oP 'Equipment.*:\s*\K\d+' .claude/memory-bank/project-brief.md 2>/dev/null | head -1)

# Find building.json - could be in analysis/*/
building_json=$(find analysis -name "building.json" 2>/dev/null | head -1)
if [ -n "$building_json" ]; then
  actual=$(python3 -c "
import json, sys
try:
    with open('$building_json') as f:
        d = json.load(f)
        if isinstance(d, list):
            items = d
        elif isinstance(d, dict):
            items = d.get('equipment', list(d.values())[0] if d else [])
        else:
            items = []
        count = len([e for e in items if isinstance(e, dict) and e.get('component') and e.get('component') != 'metadata' and 'narrative' not in str(e.get('component', ''))])
        print(count)
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
" 2>&1)
  if [ -n "$stated" ] && [ -n "$actual" ]; then
    diff=$((stated > actual ? stated - actual : actual - stated))
    pct=$((diff * 100 / (stated > 0 ? stated : 1)))
    if [ "$pct" -gt 5 ]; then
      echo "MISMATCH: Stated $stated vs actual $actual equipment ($pct% drift)"
    else
      echo "OK: Equipment count matches ($stated stated, $actual actual)"
    fi
  fi
fi

# Photo count
stated_photos=$(grep -oP 'Photos.*:\s*\K\d+' .claude/memory-bank/project-brief.md 2>/dev/null | head -1)
actual_photos=$(find analysis -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" 2>/dev/null | wc -l)
if [ -n "$stated_photos" ]; then
  echo "Photos: stated $stated_photos, actual $actual_photos"
fi
```

**Agent Versions** (PCA projects also have deployed agents):

```bash
if [ -d ".claude/agents" ]; then
  refs=$(grep -oE 'pca-[a-z]+-agent-v[0-9.]+' .claude/memory-bank/tech-context.md 2>/dev/null | sort -u)
  actual=$(ls .claude/agents/pca-*.md 2>/dev/null | xargs -n1 basename | sed 's/.md$//' | sort -u)
  for ref in $refs; do
    echo "$actual" | grep -q "^${ref}$" || echo "BROKEN_REF: $ref"
  done
  for file in $actual; do
    echo "$refs" | grep -q "^${file}$" || echo "UNDOCUMENTED: $file"
  done
fi
```

### D4. Infrastructure-Specific Checks

**Service References** (if PROJECT_TYPE == "infrastructure"):

```bash
echo "=== Service Validation ==="
# Check if referenced services exist in systemd
services=$(grep -oE '[a-z-]+\.service' .claude/memory-bank/tech-context.md 2>/dev/null | sort -u)
for svc in $services; do
  systemctl list-unit-files "$svc" &>/dev/null && echo "OK: $svc" || echo "MISSING: $svc"
done
```

**Output**: List mismatches with stated vs actual values.

---

## Output

### Report Format

```markdown
# Memory Audit Report

**Date:** YYYY-MM-DD | **Session:** N | **Project Type:** [type] | **Scope:** [all|phase]

| Phase | Issues | Lines Affected |
|-------|--------|----------------|
| A: Structure | N misplaced | X |
| B: Content | M misclassified | Y |
| C: Staleness | P stale | Z |
| D: Consistency | Q mismatches | - |
| **Total** | **T** | **L** |

## Phase A: Structure
[findings]

## Phase B: Content
[findings]

## Phase C: Staleness
[findings]

## Phase D: Consistency
[findings]

---
*State saved to .memory-audit-state.json*
*Run with `fix` argument to apply recommendations*
```

### State File

Save to `.memory-audit-state.json` in project root:

```json
{
  "last_run": "YYYY-MM-DD",
  "session": N,
  "project_type": "meap|pca|infrastructure|generic",
  "lines": {
    "global_claude_md": N,
    "workspace_claude_md": N,
    "project_claude_md": N,
    "memory_bank_total": M
  },
  "findings": {
    "structure": N,
    "content": N,
    "staleness": N,
    "consistency": N
  },
  "potential_reduction": L
}
```

On subsequent runs, show delta from previous:

```
Since last audit (N sessions ago):
- Structure issues: 5 → 2 (-3 fixed)
- Stale handoffs: 3 → 0 (archived)
- Total potential reduction: 150 → 45 lines
```

---

## Fix Mode

When `$ARGUMENTS` contains `fix`:

1. Run all phases to collect findings
2. Present summary of fixable items
3. Use AskUserQuestion to confirm:
   - Question: "Found N fixable issues. Apply fixes?"
   - Options: "Yes, fix all" / "Review each" / "Skip fixes"
4. Apply approved fixes with Edit tool
5. Update state file

**Fixable items**:
- Archive old handoffs → move to `.claude/memory-bank/archive/`
- Remove duplicate sections → Edit to delete
- Move misrouted content → Edit source (remove) + Edit target (add)
- Update broken paths → Edit with correct path

**Safety**:
- Never delete without confirmation
- Show what will change before applying
- Update state file after fixes

---

**Speed target**: <60s analysis, +30s for fixes
**Frequency**: Monthly, after 5+ sessions, or when files feel bloated
