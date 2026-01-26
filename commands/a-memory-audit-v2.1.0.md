---
name: a-memory-audit
version: v2.1.0
allowed-tools: Read, Glob, Grep, Bash, Edit, Write, AskUserQuestion
description: Universal Memory Bank audit - detects project type, checks structure, content, staleness, consistency, token efficiency
argument-hint: "[structure|content|staleness|consistency|efficiency|all|fix]"
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
| `efficiency` | Phase E only |
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

## Phase E: Token Efficiency

Identify content that's accurate but not needed every session. Apply tiered extraction using REQUIRED pointer pattern.

**Evidence**: Session 196 (MEAP) achieved 53% reduction; Session 159 (chungus-net) achieved 41% reduction.

### E1. Baseline Measurement

```bash
echo "=== Token Efficiency Baseline ==="

# Count all levels
global_lines=$(wc -l < ~/.claude/CLAUDE.md 2>/dev/null || echo 0)
workspace_lines=$(wc -l < ~/2_project-files/CLAUDE.md 2>/dev/null || echo 0)
project_lines=$(wc -l < CLAUDE.md 2>/dev/null || echo 0)
mb_total=$(wc -l .claude/memory-bank/*.md 2>/dev/null | tail -1 | awk '{print $1}')

echo "Global CLAUDE.md: $global_lines lines"
echo "Workspace CLAUDE.md: $workspace_lines lines"
echo "Project CLAUDE.md: $project_lines lines"
echo "Memory Bank total: $mb_total lines"

# Flag bloated files
echo ""
echo "=== Bloat Detection ==="
for f in .claude/memory-bank/*.md; do
  lines=$(wc -l < "$f" 2>/dev/null || echo 0)
  if [ "$lines" -gt 400 ]; then
    echo "BLOATED: $f ($lines lines, threshold 400)"
  fi
done

if [ "$project_lines" -gt 200 ]; then
  echo "BLOATED: CLAUDE.md ($project_lines lines, threshold 200)"
fi
if [ "$workspace_lines" -gt 200 ]; then
  echo "BLOATED: workspace CLAUDE.md ($workspace_lines lines, threshold 200)"
fi
```

### E2. Section Classification (Memory Bank)

For each `## ` section in tech-context.md and system-patterns.md, classify:

| Classification | Criteria | Action |
|----------------|----------|--------|
| KEEP_INLINE | Version tables (<10 rows), IPs, ports, SSH, URLs, paths, "essential", "current" | Keep in Memory Bank |
| EXTRACT | Procedures, configs, examples, sections >40 lines, "when working with" | Move to docs/reference/ |
| REMOVE | "session \d+", "historical", "superseded", "deprecated" | Delete |

```bash
echo "=== Memory Bank Section Analysis ==="

# Analyze tech-context.md sections
echo "tech-context.md sections:"
awk '/^## / {
  if (section) print section, lines, "lines"
  section = $0
  lines = 0
  next
}
{lines++}
END {if (section) print section, lines, "lines"}
' .claude/memory-bank/tech-context.md 2>/dev/null

echo ""
echo "system-patterns.md sections:"
awk '/^## / {
  if (section) print section, lines, "lines"
  section = $0
  lines = 0
  next
}
{lines++}
END {if (section) print section, lines, "lines"}
' .claude/memory-bank/system-patterns.md 2>/dev/null
```

**Classification keywords**:
- KEEP: version, IP, port, ssh, url, path, current, essential, core, quick
- EXTRACT: procedure, detailed, config, example, methodology, workflow, pattern, when working
- REMOVE: historical, superseded, deprecated, "Session \d+", obsolete

### E3. Section Classification (CLAUDE.md)

Apply same tiered treatment to CLAUDE.md at all 3 levels.

| Section Type | Default Classification | Rationale |
|--------------|------------------------|-----------|
| Build commands | KEEP | Every session |
| True gotchas (trap keywords) | KEEP | Error prevention |
| Troubleshooting tables | KEEP | Quick reference |
| Workflow patterns | EXTRACT | Topic-specific |
| Plugin/tool docs | EXTRACT | Only when using tool |
| Methodology sections | EXTRACT | Not operational |
| Historical context | REMOVE | Not actionable |

**Extraction destinations by level**:
- Project CLAUDE.md → `docs/reference/claudemd-reference.md` (or `[project-type]-gotchas-reference.md`)
- Workspace CLAUDE.md → `~/2_project-files/docs/reference/workspace-reference.md`
- Global CLAUDE.md → Skip (typically <50 lines)

```bash
echo "=== CLAUDE.md Section Analysis ==="

# Project CLAUDE.md sections
echo "Project CLAUDE.md sections:"
awk '/^## / {
  if (section) print section, lines, "lines"
  section = $0
  lines = 0
  next
}
{lines++}
END {if (section) print section, lines, "lines"}
' CLAUDE.md 2>/dev/null

# Count gotcha subsections
gotcha_count=$(grep -c "^### " CLAUDE.md 2>/dev/null || echo 0)
echo "Gotcha subsections: $gotcha_count"

# Check for trap keywords vs doc keywords
trap_keywords=$(grep -ciE 'fails|breaks|hangs|crashes|silent|wrong|gotcha|trap|error|bug|must not|never' CLAUDE.md 2>/dev/null || echo 0)
doc_keywords=$(grep -ciE 'overview|workflow|methodology|pattern|example|reference|how to' CLAUDE.md 2>/dev/null || echo 0)
echo "Trap keywords: $trap_keywords, Doc keywords: $doc_keywords"
```

### E4. REQUIRED Pointer Inventory

Count existing REQUIRED pointers and validate targets.

```bash
echo "=== REQUIRED Pointer Inventory ==="

# Count pointers in Memory Bank
echo "REQUIRED pointers by file:"
for f in .claude/memory-bank/*.md; do
  count=$(grep -c "REQUIRED.*read" "$f" 2>/dev/null || echo 0)
  if [ "$count" -gt 0 ]; then
    echo "  $(basename "$f"): $count"
  fi
done

# Count in CLAUDE.md
claude_pointers=$(grep -c "REQUIRED.*read" CLAUDE.md 2>/dev/null || echo 0)
echo "  CLAUDE.md: $claude_pointers"

# Validate pointer targets exist
echo ""
echo "=== Pointer Target Validation ==="
grep -ohE "read \`[^\`]+\`" .claude/memory-bank/*.md CLAUDE.md 2>/dev/null | \
  sed "s/read \`//g; s/\`//g; s/#.*//g" | sort -u | while read -r path; do
    # Handle relative paths
    if [ -f "$path" ]; then
      echo "OK: $path"
    elif [ -f "./$path" ]; then
      echo "OK: $path"
    else
      echo "BROKEN: $path"
    fi
done
```

### E5. Extraction Summary

Calculate potential reduction and present findings.

```bash
echo "=== Extraction Summary ==="

# Calculate totals
total_lines=$((project_lines + mb_total))
echo "Current total: $total_lines lines (CLAUDE.md + Memory Bank)"

# Count sections >40 lines as extraction candidates
candidates=$(awk '/^## / {
  if (section && lines > 40) count++
  section = $0
  lines = 0
  next
}
{lines++}
END {if (section && lines > 40) count++; print count+0}
' .claude/memory-bank/tech-context.md .claude/memory-bank/system-patterns.md CLAUDE.md 2>/dev/null)

echo "Extraction candidates (sections >40 lines): $candidates"
```

**Output table format**:

| Source | Section | Lines | Classification | Reason |
|--------|---------|-------|----------------|--------|
| tech-context.md | ## BiMO Successor | 45 | EXTRACT | Topic-specific |
| system-patterns.md | ## Deployment Patterns | 52 | EXTRACT | Detailed procedure |
| CLAUDE.md | ## Workflow Patterns | 38 | EXTRACT | Methodology |

Present findings and potential reduction percentage.

### E6. Interview (Fix Mode)

When `$ARGUMENTS` contains `fix` or `efficiency`, interview user for extraction scope.

**Question 1: Extraction Scope**

Use AskUserQuestion:
```
Token Efficiency Analysis found:
- Memory Bank: [X] lines across [N] files
- CLAUDE.md: [Y] lines at project level
- [M] sections identified for potential extraction
- Potential reduction: [P]%

Select extraction scope:
```
Options:
- `SKIP` - Analysis only, no changes
- `SURGICAL` - Extract only sections >50 lines with clear topic boundaries
- `MODERATE` - Extract all topic-specific content, keep core references
- `AGGRESSIVE` - Maximum extraction, keep only version tables and critical paths

**Question 2: CLAUDE.md Treatment**

Use AskUserQuestion:
```
Project CLAUDE.md has [N] sections ([M] lines total).

Current breakdown:
- [X] true gotchas (keep for error prevention)
- [Y] workflow/methodology sections (could extract)
- [Z] historical/deprecated content (could remove)

Apply tiered treatment to CLAUDE.md?
```
Options:
- `YES` - Full tiered treatment (extract workflows, remove historical)
- `PARTIAL` - Extract only, keep historical for reference
- `NO` - CLAUDE.md stays as-is

### E7. Execute Extraction (Fix Mode)

When user approves extraction scope:

**Step 1: Create reference doc structure**

```bash
mkdir -p docs/reference

# Determine reference doc name by project type
case $PROJECT_TYPE in
  pca) ref_file="docs/reference/pca-reference.md" ;;
  meap) ref_file="docs/reference/meap-reference.md" ;;
  infrastructure) ref_file="docs/reference/infra-reference.md" ;;
  *) ref_file="docs/reference/project-reference.md" ;;
esac
```

**Step 2: For each EXTRACT section**

1. Read section content from source file
2. Append to reference doc with anchor heading (`## Section Name`)
3. Replace source section with REQUIRED pointer stub:

```markdown
## [Topic]

**REQUIRED**: When working with [topic] (discussing, planning, or executing), read `docs/reference/[file].md#[anchor]` first.

Quick reference:
- [1-2 line essential fact from original section]
```

**Step 3: For each REMOVE section**

1. Verify no active references exist
2. Delete section from source file

**Step 4: Update state file**

Record extraction in `.memory-audit-state.json` efficiency object.

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
| E: Efficiency | R extractable | W |
| **Total** | **T** | **L** |

## Phase A: Structure
[findings]

## Phase B: Content
[findings]

## Phase C: Staleness
[findings]

## Phase D: Consistency
[findings]

## Phase E: Token Efficiency

**Baseline**:
| Source | Lines | Status |
|--------|-------|--------|
| tech-context.md | N | OK/BLOATED |
| system-patterns.md | N | OK/BLOATED |
| project CLAUDE.md | N | OK/BLOATED |
| Memory Bank total | N | OK/BLOATED |

**Classification Summary**:
| Classification | Sections | Lines |
|----------------|----------|-------|
| KEEP_INLINE | N | X |
| EXTRACT | N | Y |
| REMOVE | N | Z |

**REQUIRED Pointers**: N existing, M targets validated
**Extraction Candidates**: [table of sections with >40 lines]
**Potential Reduction**: N lines (X%)

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
    "consistency": N,
    "efficiency": N
  },
  "potential_reduction": L,
  "efficiency": {
    "last_run": "YYYY-MM-DD",
    "baseline": {
      "memory_bank_lines": N,
      "claudemd_lines": {
        "global": N,
        "workspace": N,
        "project": N
      }
    },
    "extractions": [
      {
        "source": "file.md",
        "section": "## Section Name",
        "destination": "docs/reference/file.md#anchor",
        "lines": N,
        "date": "YYYY-MM-DD"
      }
    ],
    "required_pointers": {
      "tech-context.md": N,
      "system-patterns.md": N,
      "CLAUDE.md": N
    },
    "reduction_achieved": N
  }
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
- Extract sections (Phase E) → Create reference doc, add REQUIRED pointer, remove original
- Remove obsolete sections (Phase E) → Delete after verifying no references

**Safety**:
- Never delete without confirmation
- Show what will change before applying
- Update state file after fixes

---

**Speed target**: <60s analysis, +30s for fixes
**Frequency**: Monthly, after 5+ sessions, or when files feel bloated
