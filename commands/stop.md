---
name: stop
version: v3.0.0
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, Task, AskUserQuestion
description: Universal session handoff - preserves context, extracts knowledge, cleans cruft
argument-hint: [brief session description]
thinking: true
---

# Session Handoff

Your context resets after this. Write a handoff that sets up the next Claude for success.

**Thresholds**: Max gotchas 10, archive when 4+ handoffs (keep 2), warn if file >400 lines, cruft age 30 days, audit every 5 sessions.

---

## 0. Detect Context

```bash
source ~/2_project-files/.claude/scripts/detect-context.sh || { echo "ERROR: Failed to load detect-context.sh"; exit 1; }
echo "PROJECT_TYPE=$PROJECT_TYPE"
echo "CURRENT_MACHINE=$CURRENT_MACHINE ($CURRENT_IP)"
echo "SESSION_NUMBER=$SESSION_NUMBER"

echo "=== Git Status ==="
TRACKED_CHANGES=$(git status --porcelain 2>/dev/null | grep -v "^??" | wc -l | tr -d ' ')
echo "Tracked changes: $TRACKED_CHANGES"
git status --short 2>/dev/null | head -20
```

Store PROJECT_TYPE and SESSION_NUMBER for all subsequent steps.

---

## 0.5 Lightweight Session Detection

**If TRACKED_CHANGES == 0**: Ask user "No code changes. Quick close or full handoff?" Options: "Quick close" / "Full /stop"

Quick close → output "LIGHTWEIGHT SESSION CLOSE - No code changes. Ready for /clear." and STOP.

**If TRACKED_CHANGES > 0 or user chooses full**: Continue to Section 1.

---

## 1. Gather Context

```bash
git diff --name-only
```

Read `.claude/memory-bank/active-context.md`. SESSION_NUMBER from Step 0 is the session being closed.

---

## 2. Knowledge Extraction

Analyze session for knowledge worth preserving. Review tool calls, user messages, discoveries.

**Extraction targets:**
- **tech-context.md**: IPs, ports, paths, commands, versions
- **system-patterns.md**: Dependencies, data flows, architecture
- **CLAUDE.md § Gotchas**: "Tried X, failed Y, fix Z" patterns
- **backport-tracker.md** (MEAP): Client innovations
- **Workspace CLAUDE.md** (`~/2_project-files/CLAUDE.md`): Universal patterns for ALL projects

**Tier 2 routing** (if `docs/reference/` exists): Route code blocks, configs, procedures >15 lines to tier 2 reference docs. Memory Bank gets REQUIRED pointer + 1-line summary only.

**Pre-filter duplicates**: Read target files, check if content already exists. Only present genuinely new content.

**Present candidates** via AskUserQuestion: "From [activity]: Proposed additions to [target]. Add?" Options: "Yes, add all" / "No, skip" / "Let me specify"

For workspace CLAUDE.md, require extra confirmation: "AFFECTS ALL PROJECTS: Add [pattern]?"

Track approved changes for delta summary.

---

## 3. Update Memory Bank

### active-context.md (always)

In ONE atomic Edit operation:
1. Change frontmatter `session: N` to `session: N+1`
2. Update "Current Work Focus" section
3. Add new handoff after that section

**Handoff structure** (ISO 8601 date: `## CONTEXT HANDOFF - YYYY-MM-DD (Session N)`):
- **Session Summary**: What was accomplished (specific, not vague)
- **Changes made**: Table with Change | Status columns
- **Files modified**: List with descriptions
- **Knowledge extracted**: What was added to which files
- **Next Session Priority**: Goal, not steps
- **Open Issues**: Blockers or "None"

### Apply Approved Extractions

Write approved extractions to target files. For tier 2 content, create `docs/reference/` and section if needed.

---

## 4. Gotcha Hygiene

Run if gotchas added OR CLAUDE.md § Gotchas has 11+ entries.

For each gotcha: Solved (remove), Pattern (move to system-patterns), Universal (move to workspace CLAUDE.md), True gotcha (keep).

Goal: ≤10 gotchas.

---

## 5. Cruft Scanning

```bash
echo "=== Ralph Session ==="
if [ -d "dev/ralph/active" ] && [ -f "dev/ralph/active/IMPLEMENTATION_PLAN.md" ]; then
    PENDING=$(grep -c "\*\*Status\*\*: pending" dev/ralph/active/IMPLEMENTATION_PLAN.md 2>/dev/null || echo 0)
    BLOCKED=$(grep -c "\*\*Status\*\*: blocked" dev/ralph/active/IMPLEMENTATION_PLAN.md 2>/dev/null || echo 0)
    FEATURE=$(grep "^- Feature:" dev/ralph/active/IMPLEMENTATION_PLAN.md | head -1 | cut -d: -f2 | xargs)
    [ "$PENDING" -gt 0 ] || [ "$BLOCKED" -gt 0 ] && echo "WARNING: $FEATURE incomplete ($PENDING pending, $BLOCKED blocked)"
fi

echo "=== Coordination Files ==="
ls *-COORDINATION.md *-BUILD-*.md *.state.json 2>/dev/null || echo "None"

echo "=== Untracked Files ==="
git ls-files --others --exclude-standard 2>/dev/null | head -20

echo "=== Empty Directories ==="
find . -type d -empty -not -path "./.git/*" 2>/dev/null | head -10
```

**Project-specific** (run if applicable):
- MEAP: `find dev/active/feedback -name "*.md" -mtime +30 2>/dev/null`
- PCA: Check `cards/*.md` not referenced in PROJECT-CHECKLIST.md
- Infrastructure: Check `scripts/*.sh` not referenced in docs

**If cruft found**: Ask user what to do (delete/archive/keep/review individually). Execute approved actions.

---

## 6. Staleness Curation

Check Memory Bank for stale content: outdated versions, missing paths, superseded decisions. Update or remove.

If Memory Bank modified this session, verify cross-references still valid.

---

## 7. Periodic Audit

```bash
[ "$SESSION_NUMBER" -gt 0 ] && [ $((SESSION_NUMBER % 5)) -eq 0 ] && echo "Periodic audit triggered (Session $SESSION_NUMBER)"
```

If triggered: Audit all Memory Bank files + CLAUDE.md for accuracy, outdated patterns, cross-reference integrity, file size (>400 lines = review).

Fix issues immediately.

---

## 8. Archive Old Handoffs

```bash
handoff_count=$(grep -c "^## CONTEXT HANDOFF - " .claude/memory-bank/active-context.md 2>/dev/null || echo 0)
echo "Handoff count: $handoff_count"
```

When 4+ handoffs: Archive oldest to `.claude/memory-bank/archive/handoffs-YYYY-MM-sessions-N-M.md`, keep 2 most recent.

---

## 9. Validate

```bash
wc -l .claude/memory-bank/*.md
```

Check: File >400 lines (wrong place?), grew >100 lines (wrong place?), no changes (meaningful work?), handoff <5 lines (context lost?).

Surface concerns before committing.

---

## 10. Commit

```bash
git add .claude/memory-bank/ CLAUDE.md
[ "$PROJECT_TYPE" = "pca" ] && git add analysis/ cards/ 2>/dev/null
git add archive/ 2>/dev/null
git add -A
git status --short
```

Commit with conventional message (actual content, NO PLACEHOLDERS):
```bash
git commit -m "docs(memory-bank): Session $SESSION_NUMBER handoff

- [Actual changes from this session]

Co-Authored-By: Claude <noreply@anthropic.com>"
```

Push if remote exists. If commit/push fails, STOP until resolved.

**Workspace commands repo** (`~/2_project-files/.claude`): If modified, commit and push separately.

---

## 11. Summary

**Format by project type:**

**MEAP/Infrastructure/Generic**: WHAT/WHY/WHERE narrative
- WHAT WE DID: Actual accomplishments
- WHY: Reason for the work
- WHERE: Files changed with paths
- PRESERVED: Memory Bank updates, commits
- WHAT'S NEXT: Priority for next session
- HOUSEKEEPING: Cruft actions or "None"

**PCA**: Structured format
- Project/Phase/Progress header
- WHAT WAS ACCOMPLISHED (bullets)
- KEY DECISIONS MADE
- FILES CHANGED (Created/Modified/Archived)
- GIT STATUS (commits, pushed, branch)
- MEMORY BANK (file-by-file changes)
- NEXT SESSION (priority, command, open issues)

End with: `Ready for /clear.`

---

**Speed target**: 90-120 seconds
**Agents**: Optional for PCA cruft analysis only
