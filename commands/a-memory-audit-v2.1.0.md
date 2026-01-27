---
name: a-memory-audit
version: v2.1.0
allowed-tools: Read, Glob, Grep, Bash, Edit, Write, AskUserQuestion
description: Universal Memory Bank audit - detects project type, checks structure, content, staleness, consistency, token efficiency
argument-hint: "[structure|content|staleness|consistency|efficiency|all|fix]"
thinking: true
---

# Memory Audit

| Argument | Scope |
|----------|-------|
| `structure` | Phase A |
| `content` | Phase B |
| `staleness` | Phase C |
| `consistency` | Phase D |
| `efficiency` | Phase E |
| `all` / empty | All phases |
| `fix` | All phases + apply fixes |

---

## 0. Detect Project Type and Session

**SYNC NOTE**: Detection logic duplicated in /start, /stop. Keep synchronized.

```bash
# Project type detection
PROJECT_TYPE="generic"
[ -f "emergency.md" ] && PROJECT_TYPE="infrastructure"
[ -f "PROJECT-CHECKLIST.md" ] && { [ -d "cards" ] || [ -d "analysis" ]; } && PROJECT_TYPE="pca"
[ -d "dev" ] && [ -f ".claude/memory-bank/backport-tracker.md" ] && PROJECT_TYPE="meap"

# Session number
SESSION_NUMBER=$(awk '/^session:/ {print $2; exit}' .claude/memory-bank/active-context.md 2>/dev/null)
[[ ! "$SESSION_NUMBER" =~ ^[0-9]+$ ]] && SESSION_NUMBER=0

echo "Project: $PROJECT_TYPE | Session: $SESSION_NUMBER"
```

---

## Setup: Read All Files

Read in parallel, skip missing files gracefully.

| Level | Files |
|-------|-------|
| Global | `~/.claude/CLAUDE.md` |
| Workspace | `~/2_project-files/CLAUDE.md` |
| Project | `CLAUDE.md`, `.claude/memory-bank/*.md` |
| MEAP-only | `backport-tracker.md`, `deployment-log.md` |

```bash
wc -l ~/.claude/CLAUDE.md ~/2_project-files/CLAUDE.md CLAUDE.md .claude/memory-bank/*.md 2>/dev/null | grep -v "^wc:"
```

---

## Phase A: Structure

### Routing Rules

| Content Type | Canonical Location |
|--------------|-------------------|
| Gotchas (has `### ` children) | CLAUDE.md |
| Overview, Profile, Scope | project-brief.md |
| Commands, Workflows, Versions | tech-context.md |
| Architecture, Data Flow, Diagrams | system-patterns.md |
| Handoffs, Current Work | active-context.md |
| Generic patterns | workspace CLAUDE.md |
| Machine-specific (IPs, paths) | global CLAUDE.md |

### Checks

```bash
# A1: Header scan
grep -n "^## \|^### " CLAUDE.md 2>/dev/null

# A2: Memory Bank pointer
grep -q "memory-bank\|Memory Bank" CLAUDE.md && echo "HAS_POINTER" || echo "MISSING_POINTER"

# A3: Duplicate detection
for pattern in "Building\|Address\|Square [Ff]eet" "^## Commands\|^## Versions" "Data [Ff]low\|Architecture"; do
  grep -l "$pattern" .claude/memory-bank/*.md CLAUDE.md 2>/dev/null | sort | uniq -c | awk '$1 > 1 {print "DUPLICATE:", $2}'
done
```

Non-gotcha `## ` sections in CLAUDE.md are likely misplaced.

---

## Phase B: Content

Classify each `### ` section in CLAUDE.md:

| Class | Criteria | Action |
|-------|----------|--------|
| TRAP | fails, breaks, hangs, crashes, silent, wrong, gotcha, trap, error, bug, must not, never | Keep in CLAUDE.md |
| DOC | overview, workflow, methodology, reference, config, how to, pattern, example | Move to tech-context |
| GENERIC | No project nouns | Move to workspace CLAUDE.md |
| DUPLICATE | >50% overlap with Memory Bank | Remove |

### Project Nouns by Type

- **MEAP**: meap, proto, wordbank, backport, deploy, field-interface
- **PCA**: building, equipment, checklist, cards, analysis, photos
- **Infrastructure**: server, service, network, systemd, caddy, docker, ssh

For each section: count TRAP vs DOC keywords, check for project nouns, check Memory Bank overlap.

---

## Phase C: Staleness

### Checks

```bash
# C1: Old handoffs (>5 sessions)
current=$(awk '/^session:/ {print $2; exit}' .claude/memory-bank/active-context.md 2>/dev/null)
grep -n "^## CONTEXT HANDOFF.*Session" .claude/memory-bank/active-context.md 2>/dev/null | while IFS=: read -r line rest; do
  sess=$(echo "$rest" | grep -oP 'Session \K\d+' 2>/dev/null || echo "$rest" | sed 's/.*Session \([0-9]*\).*/\1/')
  [ -n "$sess" ] && [ "$current" -gt 0 ] && [ $((current - sess)) -gt 5 ] && echo "STALE: Line $line - Session $sess"
done

# C2: Broken paths
for file in .claude/memory-bank/system-patterns.md .claude/memory-bank/tech-context.md; do
  grep -oE '~/[A-Za-z0-9_./-]+' "$file" 2>/dev/null | sed 's/[,;:.)]*$//' | sort -u | while read -r path; do
    expanded="${path/#\~/$HOME}"
    [ ! -e "$expanded" ] && echo "BROKEN: $path in $(basename "$file")"
  done
done

# C3: Old annotations (remove after 10+ sessions)
grep -n "FIXED Session\|TODO\|PENDING\|WIP\|OBSOLETE" CLAUDE.md .claude/memory-bank/*.md 2>/dev/null

# C4: Broken file references
grep -ohE '\b[a-z0-9-]+\.md\b' CLAUDE.md .claude/memory-bank/*.md 2>/dev/null | sort -u | while read -r ref; do
  case "$ref" in README.md|CLAUDE.md) continue ;; esac
  find . -name "$ref" -type f 2>/dev/null | grep -q . || echo "MISSING: $ref"
done | head -10
```

Archive handoffs >5 sessions old to `.claude/memory-bank/archive/`.

---

## Phase D: Consistency

Cross-reference Memory Bank claims against actual state.

### D1. Universal: Archive References

```bash
refs=$(grep -oE 'archive/[A-Za-z0-9_-]+\.md' .claude/memory-bank/active-context.md 2>/dev/null | sort -u)
if [ -d ".claude/memory-bank/archive" ]; then
  actual=$(ls .claude/memory-bank/archive/*.md 2>/dev/null | xargs -n1 basename | sed 's/^/archive\//' | sort -u)
  for ref in $refs; do echo "$actual" | grep -q "^${ref}$" || echo "MISSING: $ref"; done
  for file in $actual; do echo "$refs" | grep -q "^${file}$" || echo "ORPHANED: $file"; done
fi
```

### D2. MEAP-Specific

```bash
# Agent versions
if [ -d "reference/deploy/agents" ]; then
  refs=$(grep -oE '[a-z]+-agent-v[0-9.]+' .claude/memory-bank/tech-context.md 2>/dev/null | sort -u)
  actual=$(ls reference/deploy/agents/*.md 2>/dev/null | xargs -n1 basename | sed 's/.md$//' | sort -u)
  for ref in $refs; do echo "$actual" | grep -q "^${ref}$" || echo "BROKEN_REF: $ref"; done
fi

# Backport status
[ -f ".claude/memory-bank/backport-tracker.md" ] && {
  pending=$(grep -c "^\- \[ \]" .claude/memory-bank/backport-tracker.md 2>/dev/null || echo 0)
  completed=$(grep -c "^\- \[x\]" .claude/memory-bank/backport-tracker.md 2>/dev/null || echo 0)
  echo "Backports: $pending pending, $completed completed"
}
```

### D3. PCA-Specific

```bash
# Equipment count validation
stated=$(grep -oP 'Equipment.*:\s*\K\d+' .claude/memory-bank/project-brief.md 2>/dev/null | head -1)
building_json=$(find analysis -name "building.json" 2>/dev/null | head -1)
[ -n "$building_json" ] && {
  actual=$(python3 -c "
import json
with open('$building_json') as f:
    d = json.load(f)
    items = d if isinstance(d, list) else d.get('equipment', list(d.values())[0] if d else [])
    print(len([e for e in items if isinstance(e, dict) and e.get('component') and e.get('component') != 'metadata']))" 2>/dev/null)
  [ -n "$stated" ] && [ -n "$actual" ] && {
    diff=$((stated > actual ? stated - actual : actual - stated))
    pct=$((diff * 100 / (stated > 0 ? stated : 1)))
    [ "$pct" -gt 5 ] && echo "MISMATCH: Stated $stated vs actual $actual ($pct% drift)" || echo "OK: Equipment matches"
  }
}

# Agent versions (PCA)
[ -d ".claude/agents" ] && {
  refs=$(grep -oE 'pca-[a-z]+-agent-v[0-9.]+' .claude/memory-bank/tech-context.md 2>/dev/null | sort -u)
  actual=$(ls .claude/agents/pca-*.md 2>/dev/null | xargs -n1 basename | sed 's/.md$//' | sort -u)
  for ref in $refs; do echo "$actual" | grep -q "^${ref}$" || echo "BROKEN_REF: $ref"; done
}
```

### D4. Infrastructure-Specific

```bash
# Service validation
services=$(grep -oE '[a-z-]+\.service' .claude/memory-bank/tech-context.md 2>/dev/null | sort -u)
for svc in $services; do
  systemctl list-unit-files "$svc" &>/dev/null && echo "OK: $svc" || echo "MISSING: $svc"
done
```

---

## Phase E: Token Efficiency

Extract content not needed every session to reference docs with REQUIRED pointers.

### E1. Baseline and Bloat Detection

```bash
# Line counts
global_lines=$(wc -l < ~/.claude/CLAUDE.md 2>/dev/null || echo 0)
workspace_lines=$(wc -l < ~/2_project-files/CLAUDE.md 2>/dev/null || echo 0)
project_lines=$(wc -l < CLAUDE.md 2>/dev/null || echo 0)
mb_total=$(wc -l .claude/memory-bank/*.md 2>/dev/null | tail -1 | awk '{print $1}')

echo "Global: $global_lines | Workspace: $workspace_lines | Project: $project_lines | MB: $mb_total"

# Bloat detection (thresholds: MB files 400, CLAUDE.md 200)
for f in .claude/memory-bank/*.md; do
  lines=$(wc -l < "$f" 2>/dev/null || echo 0)
  [ "$lines" -gt 400 ] && echo "BLOATED: $f ($lines lines)"
done
[ "$project_lines" -gt 200 ] && echo "BLOATED: CLAUDE.md ($project_lines lines)"
```

### E2. Section Classification

| Classification | Criteria | Action |
|----------------|----------|--------|
| KEEP | IPs, ports, SSH, paths, version tables <10 rows, build commands, true gotchas | Keep inline |
| EXTRACT | Procedures, configs, examples, >40 lines, methodology, workflows | Move to docs/reference/ |
| REMOVE | "historical", "superseded", "deprecated", "Session \d+" | Delete |

```bash
# Section analysis (reusable AWK)
analyze_sections() {
  awk '/^## / { if (section) print section, lines, "lines"; section = $0; lines = 0; next } {lines++} END {if (section) print section, lines, "lines"}' "$1" 2>/dev/null
}

echo "=== tech-context.md ===" && analyze_sections .claude/memory-bank/tech-context.md
echo "=== system-patterns.md ===" && analyze_sections .claude/memory-bank/system-patterns.md
echo "=== CLAUDE.md ===" && analyze_sections CLAUDE.md

# Keyword ratio
trap_kw=$(grep -ciE 'fails|breaks|hangs|crashes|silent|wrong|gotcha|error|must not|never' CLAUDE.md 2>/dev/null || echo 0)
doc_kw=$(grep -ciE 'overview|workflow|methodology|pattern|example|reference' CLAUDE.md 2>/dev/null || echo 0)
echo "Trap: $trap_kw | Doc: $doc_kw keywords"
```

### E3. REQUIRED Pointer Validation

```bash
# Count pointers
for f in .claude/memory-bank/*.md CLAUDE.md; do
  count=$(grep -c "REQUIRED.*read" "$f" 2>/dev/null || echo 0)
  [ "$count" -gt 0 ] && echo "$(basename "$f"): $count pointers"
done

# Validate targets
grep -ohE "read \`[^\`]+\`" .claude/memory-bank/*.md CLAUDE.md 2>/dev/null | \
  sed "s/read \`//g; s/\`//g; s/#.*//g" | sort -u | while read -r path; do
    [ -f "$path" ] || [ -f "./$path" ] && echo "OK: $path" || echo "BROKEN: $path"
done
```

### E4. Extraction (Fix Mode)

When `$ARGUMENTS` contains `fix` or `efficiency`:

**Interview** (AskUserQuestion):
1. **Scope**: SKIP / SURGICAL (>50 lines) / MODERATE (all topic-specific) / AGGRESSIVE (maximum)
2. **CLAUDE.md treatment**: YES (full) / PARTIAL (extract only) / NO

**Execution**:
```bash
mkdir -p docs/reference
case $PROJECT_TYPE in
  pca) ref_file="docs/reference/pca-reference.md" ;;
  meap) ref_file="docs/reference/meap-reference.md" ;;
  infrastructure) ref_file="docs/reference/infra-reference.md" ;;
  *) ref_file="docs/reference/project-reference.md" ;;
esac
```

For EXTRACT sections: move content to reference doc, replace with REQUIRED pointer stub:
```markdown
## [Topic]
**REQUIRED**: When working with [topic], read `docs/reference/[file].md#[anchor]` first.
Quick reference: [1-2 line essential fact]
```

For REMOVE sections: verify no references, delete.

---

## Output

### Report Format

```markdown
# Memory Audit Report
**Date:** YYYY-MM-DD | **Session:** N | **Type:** [type] | **Scope:** [all|phase]

| Phase | Issues | Lines |
|-------|--------|-------|
| A: Structure | N | X |
| B: Content | M | Y |
| C: Staleness | P | Z |
| D: Consistency | Q | - |
| E: Efficiency | R | W |

[Phase findings...]

---
*State: .memory-audit-state.json | Run with `fix` to apply*
```

### State File (`.memory-audit-state.json`)

```json
{
  "last_run": "YYYY-MM-DD",
  "session": N,
  "project_type": "meap|pca|infrastructure|generic",
  "lines": { "global": N, "workspace": N, "project": N, "memory_bank": M },
  "findings": { "structure": N, "content": N, "staleness": N, "consistency": N, "efficiency": N },
  "efficiency": {
    "extractions": [{ "source": "file.md", "section": "## Name", "destination": "path#anchor", "lines": N }],
    "reduction_achieved": N
  }
}
```

Delta on subsequent runs: `Structure: 5 → 2 (-3) | Stale: 3 → 0 (archived)`

---

## Fix Mode

When `$ARGUMENTS` contains `fix`:

1. Run all phases
2. Present fixable items summary
3. AskUserQuestion: "Found N fixable issues. Apply?" → "Yes, fix all" / "Review each" / "Skip"
4. Apply with Edit tool
5. Update state file

**Fixable items**: Archive old handoffs, remove duplicates, move misrouted content, fix broken paths, extract sections, remove obsolete content.

**Safety**: Confirm before delete, show changes before applying.

---

**Target**: <60s analysis, +30s fixes | **Frequency**: Monthly or after 5+ sessions
