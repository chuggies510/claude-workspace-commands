---
name: stop
version: v2.5.0
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, Task, AskUserQuestion
description: Universal session handoff - preserves context, extracts knowledge, cleans cruft
argument-hint: [brief session description]
thinking: true
---

# Session Handoff

Your context resets after this. Write a handoff that sets up the next Claude for success.

## Configuration Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| MAX_GOTCHAS | 10 | Maximum gotchas to keep in CLAUDE.md |
| HANDOFF_ARCHIVE_THRESHOLD | 4 | Archive handoffs when count exceeds this |
| HANDOFFS_TO_KEEP | 2 | How many recent handoffs to preserve |
| FILE_SIZE_WARNING_LINES | 400 | Warn if Memory Bank file exceeds this |
| CRUFT_AGE_DAYS | 30 | Age threshold for old feedback files |
| PERIODIC_AUDIT_INTERVAL | 5 | Run audit every N sessions |

---

## 0. Detect Context and Check Changes

```bash
# Source shared detection script (exports PROJECT_TYPE, CURRENT_MACHINE, CURRENT_IP, SESSION_NUMBER)
source ~/2_project-files/.claude/scripts/detect-context.sh || {
    echo "ERROR: Failed to load detect-context.sh"; exit 1
}

# Display context
echo "PROJECT_TYPE=$PROJECT_TYPE"
echo "CURRENT_MACHINE=$CURRENT_MACHINE ($CURRENT_IP)"
echo "SESSION_NUMBER=$SESSION_NUMBER"

# Check for tracked file changes
echo ""
echo "=== Git Status ==="
TRACKED_CHANGES=$(git status --porcelain 2>/dev/null | grep -v "^??" | wc -l | tr -d ' ')
echo "Tracked changes: $TRACKED_CHANGES"
git status --short 2>/dev/null | head -20
```

Store PROJECT_TYPE and SESSION_NUMBER values and reuse them in all subsequent steps.

---

## 0.5 Lightweight Session Detection

**If TRACKED_CHANGES is 0** (from section 0 output):

Use AskUserQuestion:
- Question: "No code changes detected. Quick close or full handoff?"
- Options:
  - "Quick close (skip handoff)" - For exploration, triage, research sessions
  - "Full /stop workflow" - If you want to write a handoff anyway

**If user chooses "Quick close":**

Output this and STOP (do not continue to Section 1):

```
═══════════════════════════════════════════════════════════════
LIGHTWEIGHT SESSION CLOSE
═══════════════════════════════════════════════════════════════

No code changes to commit.
Session work captured elsewhere (GitHub, conversation, etc.)

Ready for /clear.
═══════════════════════════════════════════════════════════════
```

**If user chooses "Full /stop workflow":** Continue to Section 1.

**If TRACKED_CHANGES > 0:** Skip this prompt, continue to Section 1.

---

## 1. Gather Context

```bash
git status
git diff --name-only
```

Read `.claude/memory-bank/active-context.md`. The SESSION_NUMBER extracted in Step 0 is the current session being closed.

---

## 2. Knowledge Extraction

Analyze the session to extract knowledge worth preserving beyond the handoff.

### Scan Session Activities

Review what happened this session:
- **Tool calls**: What files were read/edited? What commands were run?
- **User messages**: What problems were discussed? What decisions were made?
- **Discoveries**: What was learned that wasn't known before?

### Identify Candidates by Target File

| Target | What to extract |
|--------|-----------------|
| **tech-context.md** | IPs, ports, paths, commands, versions, reference data |
| **system-patterns.md** | Service dependencies, data flows, architecture changes |
| **CLAUDE.md § Gotchas** | "Tried X, failed because Y, fix was Z" patterns |
| **backport-tracker.md** (MEAP only) | Client innovations discovered during work |
| **Workspace CLAUDE.md** (`~/2_project-files/CLAUDE.md`) | Universal patterns for ALL projects |

### Tiered Routing Check

Before presenting candidates, check if detailed content should route to tier 2 reference files.

**Tier 2 routing applies when ANY of these are true:**
1. Extraction contains code blocks (```)
2. Extraction contains YAML/JSON configuration
3. Extraction is >15 lines
4. Extraction is "how to do X" (procedure) rather than "what X is" (context)

**Content shape determines destination:**
| Content shape | Destination | Memory Bank gets |
|---------------|-------------|------------------|
| Code blocks, configs, procedures | Tier 2 reference doc | REQUIRED pointer + 1-line summary |
| Brief facts (<15 lines, no code) | Memory Bank directly | Full content |
| Architecture diagrams (ASCII) | system-patterns.md | Full content (visual context) |

**Routing logic:**
1. Check if `docs/reference/` exists in project
   - If not: route everything to Memory Bank
2. Check if extraction topic matches existing tier 2 section
   - Grep for related headers in `docs/reference/*.md`
   - If match: append to that section
3. If no existing section but content is detailed:
   - Find most appropriate reference file (tech-reference, pattern-reference, infra-reference)
   - Create new section with `## Topic Name` header
   - Add REQUIRED pointer to Memory Bank

**Memory Bank pointer format:**
```markdown
## Topic Name

**REQUIRED**: When working with [topic], read `docs/reference/[file].md#[anchor]` first.

Quick reference: [1-line summary of what's there]
```

**Anchors map to headers**: `#deployment` → `## Deployment` (lowercase-hyphenated → Title Case)

### Pre-Filter Duplicates

Before presenting candidates to user:

1. Read each target file
   - If file doesn't exist: all candidates for that file are new, proceed to presentation
   - If file exists: check for duplicates as described below

2. Check semantic duplication:
   - **tech-context.md**: Check if IP/port/path/command already listed
   - **CLAUDE.md gotchas**: Check if trap already described (same root cause = duplicate)
   - **system-patterns.md**: Check if relationship/flow already diagrammed

3. Handle near-duplicates:
   - If match exists but candidate adds new detail, propose as UPDATE not new entry

4. Only present genuinely new content

### Present Candidates for Approval

Use AskUserQuestion for each category that has candidates.

**For project files** (tech-context, system-patterns, CLAUDE.md gotchas, backport-tracker):

Format:
- Question: "From [activity description]: Proposed additions to [target file]: 1. [item], 2. [item]. Add these?"
- Options: "Yes, add all" / "No, skip all" / "Let me specify which ones"

If user selects "Let me specify," ask about each item individually:
- Question: "Add to [target file]: [item text]?"
- Options: "Yes" / "No"

**For workspace CLAUDE.md** (extra confirmation required):

Format:
- Question: "AFFECTS ALL PROJECTS: Add to ~/2_project-files/CLAUDE.md: [proposed pattern]?"
- Options: "Yes, add to all projects" / "No, keep project-specific"

### Handle Edge Cases

**If zero candidates found:** Skip to Step 3. Note in summary: "Knowledge Delta: None (no new facts discovered)"

**If user rejects all proposals:** Skip to Step 3. Note in summary: "Knowledge Delta: None (user declined all proposals)"

### Track Approved Changes

Record what will be added for the delta summary:
- `tech-context.md: +N entries (brief description)`
- `system-patterns.md: +N patterns`
- `CLAUDE.md gotchas: +N gotchas`
- `backport-tracker.md: +N backports` (MEAP only)
- `workspace CLAUDE.md: +N universal patterns`

---

## 3. Update Memory Bank

Read `.claude/memory-bank/README.md` for routing guidance.

### active-context.md (always)

If file doesn't exist, create with template:
```yaml
---
session: 1
---

# [Project Name] Active Context

## Current Work Focus

[Describe what was done this session]

---
```

If file exists, perform these updates in a SINGLE Edit operation to ensure atomicity:

1. Use SESSION_NUMBER from Step 0 (this is the session being closed)
2. Prepare handoff text with "Session SESSION_NUMBER" header
3. In ONE Edit operation, update the file to:
   - Change frontmatter `session: N` to `session: N+1`
   - Add handoff after "Current Work Focus" section
   - Update "Current Work Focus" section content
4. Verify edit was applied by reading the file back

**CRITICAL**: The session increment and handoff addition MUST happen in the same Edit call. If they're separate, a failure between them causes session number inconsistency.

If multiple `session:` lines exist in frontmatter, use the first one and remove duplicates in the same Edit operation.

**Use ISO 8601 date format** for handoff headers: `## CONTEXT HANDOFF - 2026-01-13 (Session N)`

**Handoff structure** (all three sections required):

```markdown
## CONTEXT HANDOFF - [Date] (Session N)

### Session Summary
[What was accomplished. Be specific - vague summaries don't help your replacement.]

**Changes made:**
| Change | Status |
|--------|--------|
| [Describe specific change] | ✅ [Brief outcome] |

**Files modified:**
- [file] - [what changed]

**Knowledge extracted:** (from Step 2)
- [target file]: [what was added]

### Next Session Priority
[What should be accomplished next? State the goal, not the steps.]

### Open Issues
[Blockers, incomplete work, or "None" - always include this section]

---
```

### Apply Approved Extractions

Write approved extractions from Step 2 to their target files. Format consistently with existing content in each file.

For each approved extraction:
1. Read the target file
2. Find the appropriate section
3. Add the new content in consistent format
4. Verify the edit was applied correctly

If no extractions approved, skip to Step 4.

### Tier 2 File Updates

For extractions routed to tier 2 files (from Tiered Routing Check):

1. Check if `docs/reference/` directory exists
   - If not: create it with `mkdir -p docs/reference`
2. Check if target file exists (e.g., `docs/reference/tech-reference.md`)
   - If not: create with minimal header:
   ```markdown
   # [Tech/Pattern] Reference

   Reference material. Not loaded on `/start` - read when working on specific topics.

   **Navigation:** Use anchor links from Memory Bank pointers.

   ---
   ```
3. Find the target section by anchor (e.g., `## Deployment`)
   - If section exists: append content to that section
   - If section missing: create new section at end of file with proper `## Section Name` header
4. Verify edit applied correctly

**Note:** Tier 2 routing only applies to projects that already have the tiered architecture (REQUIRED pointers in Memory Bank). For projects without `docs/reference/`, route to Memory Bank as normal.

**Important:** When content routes to tier 2, do NOT also add detailed content to Memory Bank. The REQUIRED pointer already serves as the reference. Only add a brief note to Memory Bank if something changed (e.g., "Updated deployment patterns in tech-reference.md").

### Other Memory Bank Updates

Beyond extractions, update if the session produced content that belongs there:
- **tech-context.md**: New versions, paths, commands, reference data
- **system-patterns.md**: Architecture changes, new workflows, dependency updates
- **backport-tracker.md** (MEAP only): Client innovations discovered during work
- **CLAUDE.md § Gotchas**: Traps that would waste future Claude's time

**Bias toward inclusion.** Future Claude can skip irrelevant context but can't recover what wasn't captured.

---

## 4. Gotcha Hygiene

Run this check if EITHER condition is true:
- You added ANY gotchas this session, OR
- CLAUDE.md § Gotchas section has 11+ entries

Scan existing gotchas. For each, ask: "Is this still a trap I'll hit, or is it solved?"

| Category | Action |
|----------|--------|
| **Solved** - fix is in place, won't recur | Remove |
| **Pattern** - architectural decision worth documenting | Move to system-patterns.md |
| **Universal** - applies to all projects | Move to workspace CLAUDE.md |
| **True gotcha** - external limitation, will hit again | Keep |

Goal: Keep gotchas ≤10 entries. Only traps that future Claude will actually encounter.

---

## 5. Cruft Scanning

Detect stale files that confuse people.

### Ralph Session Check

Check for incomplete ralph development sessions:

```bash
echo "=== Ralph Session Check ==="
if [ -d "dev/ralph/active" ]; then
    STATUS=$(grep "^## Status:" dev/ralph/active/IMPLEMENTATION_PLAN.md 2>/dev/null | head -1 | cut -d: -f2 | xargs)
    PENDING=$(grep -c "\\*\\*Status\\*\\*: pending" dev/ralph/active/IMPLEMENTATION_PLAN.md 2>/dev/null || echo 0)
    BLOCKED=$(grep -c "\\*\\*Status\\*\\*: blocked" dev/ralph/active/IMPLEMENTATION_PLAN.md 2>/dev/null || echo 0)
    FEATURE=$(grep "^- Feature:" dev/ralph/active/IMPLEMENTATION_PLAN.md 2>/dev/null | head -1 | cut -d: -f2 | xargs)
    echo "Feature: $FEATURE"
    echo "Status: $STATUS"
    echo "Pending: $PENDING, Blocked: $BLOCKED"
else
    echo "None"
fi
```

**If ralph session is incomplete** (only warn if actually incomplete):

- If `STATUS = "planning"` AND `PENDING > 0`: Ralph planning incomplete
- If `PENDING > 0` OR `BLOCKED > 0`: Ralph build incomplete
- Otherwise (review or complete status): No warning needed

Use AskUserQuestion if warning triggered:
- Question: "Active ralph session incomplete ({PENDING} pending tasks). What should happen?"
- Options:
  - "Continue later (no action)"
  - "Abandon now (/ralph abandon)"
  - "Review now (/ralph review)"

Execute corresponding action and note in session summary.

### Universal Bash Scans (all project types)

Run all scans, collect results:

```bash
echo "=== Coordination Files at Root ==="
ls *-COORDINATION.md *-BUILD-*.md *.state.json 2>/dev/null || echo "None found"

echo "=== Untracked Files ==="
git ls-files --others --exclude-standard 2>/dev/null | head -20

echo "=== Empty Directories ==="
find . -type d -empty -not -path "./.git/*" 2>/dev/null | head -10
```

### Project-Specific Cruft Scans

**If PROJECT_TYPE == "meap":**

```bash
echo "=== Old Feedback Files (>30 days) ==="
find dev/active/feedback -name "*.md" -type f -mtime +30 2>/dev/null || echo "None found"

echo "=== Empty Directories in dev/active ==="
find dev/active -type d -empty 2>/dev/null || echo "None found"
```

**If PROJECT_TYPE == "pca":**

Two options for cruft analysis:

**Option A: Bash scan (default, fast)**
```bash
echo "=== Old Analysis Files ==="
find analysis -name "*.md" -type f -mtime +60 2>/dev/null | head -10

echo "=== Orphaned Card Files ==="
# Cards not referenced in PROJECT-CHECKLIST.md
for card in cards/*.md; do
    cardname=$(basename "$card")
    if ! grep -q "$cardname" PROJECT-CHECKLIST.md 2>/dev/null; then
        echo "$card"
    fi
done 2>/dev/null | head -10
```

**Option B: Agent scan (deeper analysis, optional)**

If the user requests deeper cruft analysis or if significant unreferenced files are found, launch Task agents:

Task 1 - Cruft Scanner:
```
Prompt: Find unreferenced files in project.

Reference sources:
- PROJECT-CHECKLIST.md
- README.md (if exists)
- CLAUDE.md files
- All *-COORDINATION.md files

File types: *.md, *.csv, *.json
Exclusions: .git/, archive/, .claude/archive/, .claude/memory-bank/archive/

Use Glob tool to find all files.
Use Grep tool to find references in docs.
Return list of unreferenced files with metadata.
```

Task 2 - Cruft Analyzer (if scanner found files):
```
Prompt: Analyze unreferenced files for cruft scoring.

Unreferenced files (from scanner):
{list from scanner}

Project context:
- PROJECT-CHECKLIST.md path: [absolute path]
- Project type: PCA

Analyze each file and return confidence scores (0-100).

Rules:
- *-COORDINATION.md files → confidence = 0 (always keep)
- Files < 7 days old → max confidence 50
- Check for status markers (FINAL, Done)

Return JSON with confidence scores >=70 only.
```

**If PROJECT_TYPE == "infrastructure":**

Minimal cruft scanning. Infrastructure projects rarely accumulate cruft.

```bash
echo "=== Scripts Without References ==="
# Check if any scripts/ files are orphaned
if [ -d "scripts" ]; then
    for script in scripts/*.sh scripts/*.py 2>/dev/null; do
        scriptname=$(basename "$script" 2>/dev/null)
        if [ -n "$scriptname" ] && ! grep -rq "$scriptname" . --include="*.md" 2>/dev/null; then
            echo "$script (not referenced in docs)"
        fi
    done | head -5
fi
```

**If PROJECT_TYPE == "generic":**

Use universal bash scans only.

### Present Findings and Get User Decision

If ANY cruft found, use AskUserQuestion to get user decision.

**For coordination files:**
- Question: "Found N coordination files (*-COORDINATION.md, *.state.json) at root. These are usually temporary. Remove?"
- Options: "Yes, delete all" / "No, keep" / "Review individually"

**For old feedback files (MEAP):**
- Question: "Found N old feedback files (>30 days old) in dev/active/feedback/. Archive to dev/archive/feedback-YYYY/?"
- Options: "Yes, archive all" / "No, keep" / "Review individually"

**For empty directories:**
- Question: "Found N empty directories. Remove them?"
- Options: "Yes, delete all" / "No, keep" / "Review individually"

**For untracked files:**
- Question: "Found N untracked files (not in .gitignore). What should I do?"
- Options: "Commit them" / "Add to .gitignore" / "Delete" / "Review individually"

**For high-confidence cruft (PCA agent scan, 90-100):**
```
Found {count} files recommended for archiving:

[1] {file_path}
    Reason: {reason}
    Confidence: {score}%

Archive all high-confidence files?
```
- Options: "Yes, archive all" / "No, keep" / "Review individually"

**For medium-confidence cruft (PCA agent scan, 70-89):**
Present each file individually for approval.

### Execute Approved Actions

For approved actions:

```bash
# Archive feedback files (MEAP)
mkdir -p dev/archive/feedback-$(date +%Y)
mv [files] dev/archive/feedback-$(date +%Y)/

# Remove empty directories
rmdir [directories]

# Delete coordination files
rm [files]

# Archive cruft files (PCA)
# Use SESSION_NUMBER from Step 0 (already extracted and validated)
SESSION_DATE=$(date +%Y-%m-%d)
ARCHIVE_DIR="archive/session-${SESSION_NUMBER}-${SESSION_DATE}"
mkdir -p "$ARCHIVE_DIR"
mv [approved_files] "$ARCHIVE_DIR/"
```

Track actions for summary report.

### Skip Condition

If zero cruft found in all scans, note in summary: "Housekeeping: No cruft detected"

---

## 6. Staleness Curation

Scan Memory Bank files for stale content.

### Content Validation

Check for:
- **Version numbers** that have changed since documentation
- **Paths** that no longer exist
- **Decisions** that were superseded by later work

For each stale item found: update or remove it.

### Cross-Reference Validation

Run this check if ANY Memory Bank file was modified this session.

Verify cross-references:
- Check that file paths referenced in Memory Bank files still exist
- Check that section references point to sections that exist

For broken references:
- If file moved: update path to new location
- If file deleted: remove the reference entirely
- Report what was fixed in the summary

---

## 7. Periodic Audit (every 5 sessions)

Check if audit is triggered using SESSION_NUMBER from Step 0:

```bash
# Use SESSION_NUMBER extracted in Step 0 (no re-extraction needed)
if [ "$SESSION_NUMBER" -gt 0 ] && [ $((SESSION_NUMBER % 5)) -eq 0 ]; then
    echo "Periodic audit triggered (Session $SESSION_NUMBER)"
fi
```

If SESSION_NUMBER is divisible by 5 AND greater than 0, trigger comprehensive audit.

**Audit scope:**
- All Memory Bank files (README, project-brief, active-context, tech-context, system-patterns)
- CLAUDE.md (project root)
- deployment-log.md (MEAP only)
- dev/ planning docs (MEAP only)

**Audit checks:**
- Content accuracy vs current codebase state
- Outdated mental models or patterns no longer used
- Cross-reference integrity
- File size concerns (>400 lines flagged for review)

**Fix issues immediately** during the audit session. Don't defer fixes.

---

## 8. Archive Old Handoffs

After adding the new handoff in Step 3, check the total count:

```bash
handoff_count=$(grep -c "^## CONTEXT HANDOFF - " .claude/memory-bank/active-context.md 2>/dev/null || echo 0)
echo "Handoff count: $handoff_count"

# Check for duplicate session numbers (indicates race condition from prior run)
duplicate_sessions=$(grep "^## CONTEXT HANDOFF - " .claude/memory-bank/active-context.md 2>/dev/null | \
    sed 's/.*Session \([0-9]*\).*/\1/' | sort | uniq -d)

if [ -n "$duplicate_sessions" ]; then
    echo "WARNING: Duplicate session numbers detected: $duplicate_sessions"
    echo "Manual review recommended before archiving."
fi
```

**Archive threshold:**
- When 4+ handoffs exist, archive oldest to keep 2 most recent (applies to all project types)

**Archive process:**
1. `mkdir -p .claude/memory-bank/archive`
2. Identify the oldest handoffs (those furthest down in the file, after "Current Work Focus")
3. Copy them to archive file in chronological order (oldest first)
4. Remove them from active-context.md
5. Keep only 2 most recent handoffs
6. Preserve "Current Work Focus" and "Archived Handoffs" sections

**Archive file naming:** `archive/handoffs-YYYY-MM-sessions-N-M.md` (N=first session, M=last session)

**Update reference:** Change "Archived Handoffs" section to: `Older handoffs in '.claude/memory-bank/archive/' (Sessions 1-N)`

No detailed list - directory contents are the record.

---

## 9. Validate

```bash
wc -l .claude/memory-bank/*.md
```

Review output for these concerns:

- **Any file >400 lines** → content may be in wrong place, consider splitting or moving
- **File grew >100 lines this session** → content may be in wrong place
- **No changes to commit** → was meaningful work done this session?
- **Handoff <5 lines** → is context being lost?

Surface any concerns before committing.

---

## 10. Commit

Stage Memory Bank and documentation changes:

```bash
git add .claude/memory-bank/ CLAUDE.md
```

Stage project-specific directories:

```bash
# PCA projects: analysis and cards
if [ "$PROJECT_TYPE" = "pca" ]; then
    git add analysis/ cards/ 2>/dev/null || true
fi

# All projects: archive directory
git add archive/ 2>/dev/null || true

# Stage any other session changes
git add -A
```

Show staged changes for review:
```bash
git status --short
```

Review staged files before committing. If unexpected files appear, unstage them with `git reset HEAD <file>`.

**Commit with conventional message format:**

Construct the commit message with actual session content. Choose the appropriate type:
- `docs`: Documentation or Memory Bank updates (most common for /stop)
- `feat`: New feature implemented
- `fix`: Bug fix
- `chore`: Maintenance or housekeeping

```bash
# Construct commit message with actual content - NO PLACEHOLDERS
# The message MUST contain real session information, not templates
COMMIT_MSG="docs(memory-bank): Session $SESSION_NUMBER handoff

Session $SESSION_NUMBER:
- Updated active-context.md with handoff
- [Replace with actual key changes from this session]

Generated with Claude Code (https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Before committing, verify no placeholder patterns remain
if echo "$COMMIT_MSG" | grep -qE '\[.*\]|Key change [0-9]|Brief description'; then
    echo "ERROR: Commit message still contains placeholders. Fill in actual session details."
    echo "$COMMIT_MSG"
    # DO NOT PROCEED - fix the message first
fi

if git commit -m "$COMMIT_MSG"; then
    git log -1 --oneline
else
    echo "ERROR: Commit failed. Review staged changes and resolve before continuing."
    # STOP HERE - do not proceed to Summary until commit succeeds
fi
```

**Push if remote exists (REQUIRED for multi-machine sync):**

```bash
if git remote -v | grep -q origin; then
    if ! git push; then
        echo "ERROR: Push failed. Remote is out of sync."
        echo "This project uses Syncthing for cross-machine sync - push is required."
        echo "Resolve with: git push"
        echo ""
        echo "DO NOT proceed to Summary until push succeeds."
        # STOP HERE - push is required for multi-machine workflows
    fi
else
    echo "No remote configured - changes committed locally only"
fi
```

**Critical**: If commit OR push fails, STOP. Do not proceed to Summary until both succeed.

### Workspace Commands Repo

Check if workspace-level files were modified during this session (commands, skills, agents):

```bash
WORKSPACE_CLAUDE_DIR=~/2_project-files/.claude

if [ -d "$WORKSPACE_CLAUDE_DIR/.git" ]; then
    echo "=== Workspace Commands Repo ==="
    cd "$WORKSPACE_CLAUDE_DIR"

    WORKSPACE_CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

    if [ "$WORKSPACE_CHANGES" -gt 0 ]; then
        echo "Found $WORKSPACE_CHANGES changed file(s) in workspace commands:"
        git status --short
    else
        echo "No changes in workspace commands"
    fi

    cd - > /dev/null
fi
```

**If workspace changes detected**, commit them:

1. Review what changed (commands, skills, agents, hooks)
2. Stage and commit with descriptive message
3. Push to remote

```bash
cd "$WORKSPACE_CLAUDE_DIR"

# Stage all changes
git add -A

# Commit with session context
git commit -m "$(cat <<EOF
feat(commands): [Brief description of what changed]

Session work from [project name]:
- [List key changes to commands/skills/agents]

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"

# Push
git push

cd - > /dev/null
```

Include workspace commit in the session summary.

---

## 11. Summary

Present a narrative summary. **All angle-bracket items like `<description>` are instructions to fill in with actual content - never output them literally.**

### If PROJECT_TYPE == "meap" OR PROJECT_TYPE == "infrastructure" OR PROJECT_TYPE == "generic"

Use WHAT/WHY/WHERE narrative format. Example with actual content:

```
═══════════════════════════════════════════════════════
SESSION 93 SUMMARY
═══════════════════════════════════════════════════════

WHAT WE DID:
Created universal /start and /stop commands at workspace level that detect
project type and adapt behavior. Merged features from meap2-it v1.3.0,
101-cal v1.3.0, and chungus-net implementations.

WHY:
Multiple projects had divergent /start and /stop commands. Improvements in
one didn't propagate to others. Universal commands ensure single source of truth.

WHERE:
  • ~/2_project-files/.claude/commands/start.md - Universal session init (277 lines)
  • ~/2_project-files/.claude/commands/stop.md - Universal session handoff (762 lines)

PRESERVED FOR NEXT SESSION:
  • Memory Bank: Session 93 handoff written to active-context.md
  • Knowledge extracted to: workspace CLAUDE.md (+1 pattern)
  • Project commit: abc1234
  • Workspace commit: def5678 (if workspace commands were modified)

WHAT'S NEXT:
Test universal commands across all three project types (chungus-net, meap2-it, 101-cal)
to verify feature parity.

HOUSEKEEPING COMPLETED:
None needed - no cruft detected
═══════════════════════════════════════════════════════
```

**IMPORTANT**: The summary above is an EXAMPLE. Generate actual content from the session's work. Do not copy the example literally.

### If PROJECT_TYPE == "pca"

Use comprehensive structured format. Example with actual content:

```
═══════════════════════════════════════════════════════════════
SESSION 45 PRESERVED - 2026-01-13
═══════════════════════════════════════════════════════════════

Project: 101-cal PCA
Phase: Phase 4: Analysis
Progress: 23/35 tasks (66%)

───────────────────────────────────────────────────────────────
WHAT WAS ACCOMPLISHED
───────────────────────────────────────────────────────────────

• Completed electrical analysis for Building A (equipment count: 47)
• Generated equipment card for RTU-01 with replacement cost estimate
• Fixed CSV import bug affecting cost calculations

───────────────────────────────────────────────────────────────
KEY DECISIONS MADE
───────────────────────────────────────────────────────────────

• Decided to use MO cost database for equipment pricing (vs RSMeans)
• Chose 15-year useful life assumption for RTUs based on field conditions

───────────────────────────────────────────────────────────────
FILES CHANGED
───────────────────────────────────────────────────────────────

Created:
  cards/RTU-01.md

Modified:
  analysis/electrical-summary.md - Added Building A equipment

Archived:
  None

───────────────────────────────────────────────────────────────
GIT STATUS
───────────────────────────────────────────────────────────────

Project commit: f95eda4 docs: Session 45 - Electrical analysis complete
Workspace commit: (none, or commit hash if commands modified)
Pushed: Yes
Branch: master

───────────────────────────────────────────────────────────────
MEMORY BANK
───────────────────────────────────────────────────────────────

project-brief.md     unchanged - rarely changes
active-context.md    Session 45 → 46, handoff added
tech-context.md      +2 entries (equipment codes)
system-patterns.md   unchanged
CLAUDE.md gotchas    +1 entry (CSV encoding issue)

───────────────────────────────────────────────────────────────
FEATURE DEVELOPMENT (if active)
───────────────────────────────────────────────────────────────

No active feature development

───────────────────────────────────────────────────────────────
NEXT SESSION
───────────────────────────────────────────────────────────────

Priority: Complete plumbing analysis for Building A
Command: /a-prepare-v4.3.1
Open Issues: None

═══════════════════════════════════════════════════════════════
```

**IMPORTANT**: The summary above is an EXAMPLE. Generate actual content from the session's work. Do not copy the example literally.

---

After the summary, present:
```
Ready for /clear.
```

---

**Speed target**: 90-120 seconds (includes user interactions)
**Agents**: Optional for PCA cruft analysis, bash by default
**No agents for core workflow**: Git diff provides session context, user provides interpretation
