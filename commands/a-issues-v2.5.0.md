---
name: a-issues-v2.5.0
version: v2.5.0
description: Issue resolution with pre-triage verification, housekeeping mode, and schema consumer tracking
---

# Issue Resolution Command

Two-phase workflow: Verify → Triage → Interview → Fix → Approve → Close.
Complex issues get `/feature-dev #{number}` handoff for fresh session.

## Arguments

| Flag | Behavior |
|------|----------|
| (none) | Full workflow: verification, triage, interview, implement |
| `--triage-only` | Stop after presenting triage analysis |
| `--quick` | Priority grouping only, then interview and implement |
| `--verify-only` | Only run pre-triage verification, report stale issues |

---

## 1. Fetch Issues

```bash
gh issue list --state open --limit 100 --json number,title,labels,body,createdAt
```

On error: auth issues → `gh auth login`, empty results → exit.

---

## 2. Pre-Triage Verification

Detect issues already implemented but never closed.

**For each issue:**

1. Extract keywords (function names, file paths, error messages) from title/body
2. Search codebase:
   ```bash
   grep -r "{keyword}" --include="*.ts" --include="*.md" --include="*.yaml" . 2>/dev/null | head -5
   ```
3. Check git history since issue creation:
   ```bash
   git log --oneline --since="{issue_created_at}" --grep="#{issue_number}" -- .
   git log --oneline --since="{issue_created_at}" --grep="{keyword}" -- .
   ```
4. Classify:

| Status | Criteria | Action |
|--------|----------|--------|
| STALE | Issue mentions specific code that now exists | Offer immediate closure |
| POSSIBLY_DONE | Keywords found in recent commits | Flag for verification |
| NEEDS_WORK | No evidence of implementation | Proceed to triage |

**Stale issue prompt** (AskUserQuestion):
- Yes, verify and close all stale issues
- Let me review each one individually
- Skip stale detection, proceed to full triage

If `--verify-only`: Stop here after stale issue handling.

---

## 3. Categorize and Analyze

**Categories** (from labels/title patterns):
- **Bug**: label "bug" or prefix "B0"
- **Feature**: label "enhancement"/"feature" or prefix "F0"
- **Documentation**: label "documentation"/"docs"
- **Wordbank**: label "wordbank" or prefix "W0"
- **Architecture**: prefix "ARCH:"
- **Infrastructure**: contains "agent:", "command:", "deploy"

### Code-Based Complexity Assessment

**Read actual files before estimating.** Do not estimate from titles alone.

For each issue:
1. Grep for mentioned filenames, functions, components
2. Read files to understand scope (lines, imports, dependencies)
3. Check for consumers (what reads this file?)
4. Assign complexity:

| Complexity | Criteria | How to Verify |
|------------|----------|---------------|
| Trivial | Single file, <20 lines, no consumers | Read file, confirm isolated |
| Low | 1-2 files, <50 lines, consumers don't need updates | Read files, grep for imports |
| Medium | 3-5 files, OR consumers need updates | Map dependency graph |
| High | 6+ files, OR architectural, OR unclear scope | Needs exploration first |

---

## 4. Present Triage (4 Value Angles)

**A. Discovery** - What's actually broken
**B. Path of Least Resistance** - Quick wins
**C. Dependencies** - Root causes
**D. Strategic Context** - Active work

Include pre-triage summary and complexity warnings:
```
📋 PRE-TRIAGE: {N} STALE, {N} POSSIBLY_DONE, {N} NEEDS_WORK

⚠️  COMPLEXITY WARNINGS
  - #{number}: Wordbank change but no agent reads new field
  - #{number}: Marked "low" but affects 4 files
```

If `--triage-only`: Stop here.

---

## 5. Interview User

Four questions via AskUserQuestion:

| Question | Purpose | Housekeeping Signal |
|----------|---------|---------------------|
| What's blocking you from using the system right now? | Identify urgency | "Nothing is blocked" |
| Which issue, if fixed, would make 3+ others easier? | Find leverage points | - |
| What are you building or deploying this week? | Get context | "Nothing specific, just cleaning up" |
| If you could only fix one thing before showing someone? | Surface priority | "Don't care about showing others" |

### Housekeeping Mode

**Triggered when 2+ housekeeping signals detected.**

Housekeeping workflow priorities:
1. STALE issues → verify and close
2. POSSIBLY_DONE issues → verify and close
3. Trivial complexity with high confidence → quick fix
4. Skip anything requiring design decisions

Confirm mode with user before proceeding.

---

## 6. Schema Consumer Tracking

**Applies to:** Wordbank YAML, config files, type definitions, API shapes.

Before marking any schema change as ready:

1. Find all consumers:
   ```bash
   grep -r "{field_name}" reference/deploy/agents/ reference/apps/proto8/
   ```

2. Check if consumers use new content (new field read? renamed refs updated? template registered?)

3. If consumers don't use new content → flag as INCOMPLETE FIX:
   - Update consumer in this session, OR
   - Mark PARTIAL, document gap, don't close, OR
   - Close with note about needed consumer update

| Change Type | Find Consumers With | Update Needed? |
|-------------|---------------------|----------------|
| Wordbank form_field | grep agents/, proto8/src/ | If field affects output |
| Wordbank narrative | grep "narrative" in agents | If format changes |
| Command argument | grep commands/ | If other commands call this |
| Type definition | grep for type name | If shape changes |
| Config key | grep for key name | Always |

---

## 7. Quick Fixes (Trivial/Low, verified)

1. Read issue body
2. Verify complexity by reading actual files
3. Check for schema consumers if applicable
4. Implement changes
5. Verify consumers updated if needed
6. Verify using test bed
7. Add to pending approval queue

### Verification Requirements

| Change Type | Required Verification | Consumer Check |
|-------------|----------------------|----------------|
| Terminology/typo | Syntax check | N/A |
| Wordbank form_field | YAML valid | Proto8 renders field |
| Wordbank narrative | YAML valid | Agents use template |
| Wordbank items_list | YAML valid, item appears | Cost agent recognizes |
| Proto8 UI component | Build passes | N/A |
| Proto8 store | Build passes | Components use store |
| Command | Syntax valid | Other commands work |
| Agent | Markdown valid | Commands invoke correctly |

---

## 8. Approval Gate

Present verification summary for each issue:
```
┌─────────────────────────────────────────────────────────────┐
│ #{number}: {title}                                          │
├─────────────────────────────────────────────────────────────┤
│ Changes: {file}: {description}                              │
│ Verification: ✅ YAML valid ✅ Build passes ✅ Consumer OK  │
│ Complexity: Verified Low (2 files, 45 lines)                │
└─────────────────────────────────────────────────────────────┘
```

- Individual approval for each issue (required)
- Batch approval option (opt-in)
- Close only after explicit approval

---

## 9. Collaborative Exploration (Medium/High Complexity)

For issues too complex for quick fix:
1. Multi-round thematic interviews (5 themes)
2. Write handoff comment for /feature-dev
3. Document handoff instructions for fresh session

---

## 10. Session Report

```markdown
## Session Summary - Issue Triage & Resolution

**Pre-Triage**: {N} stale closed | **Mode**: {Normal | Housekeeping}

**Quick Fixes** (Approved & Closed):
| Issue | Title | Verification | Consumer | Status |
|-------|-------|--------------|----------|--------|

**Incomplete Fixes** (Consumer Update Needed):
| Issue | What's Done | What Remains |
|-------|-------------|--------------|

**Complex Issues** (Ready for /feature-dev):
| Issue | Title | Status |
|-------|-------|--------|

**Interview Insights**: Blockers: {Q1} | Leverage: {Q2} | Context: {Q3} | Priority: {Q4}
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| v2.5.0 | 2026-01-18 | Pre-triage verification, housekeeping mode, code-based complexity, schema consumer tracking, --verify-only flag |
| v2.4.0 | 2026-01-15 | Explicit approval gates, individual/batch approval |
| v2.3.0 | - | Collaborative exploration, multi-round interviews, /feature-dev handoffs |
