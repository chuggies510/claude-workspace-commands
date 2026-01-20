---
name: a-issues-v2.5.0
version: v2.5.0
description: Issue resolution with pre-triage verification, housekeeping mode, and schema consumer tracking
---

# Issue Resolution Command

Two-phase workflow with **pre-triage verification** and **approval gates**:
1. **Current session**: Verify → Triage → Interview → Quick fixes → Approval gate → Close
2. **Fresh session**: User runs `/feature-dev #{number}` interactively

**Key changes from v2.4.0**:
- NEW: Pre-triage verification detects already-implemented issues
- NEW: Housekeeping mode with different workflow when no urgency
- NEW: Code-based complexity estimation (read files, not just titles)
- NEW: Schema consumer tracking for wordbank/config changes

## Arguments

- `--triage-only`: Stop after presenting triage analysis (no interview or implementation)
- `--quick`: Quick triage (priority grouping only), then interview and implement
- `--verify-only`: Only run pre-triage verification, report stale issues
- No args: Full workflow with verification, triage, interview, and implement

## Test Bed

**Location:** `m2-clients/_test/` - canonical test project with 101-cal data clone

| Property | Value |
|----------|-------|
| Source | 101-cal (38 equipment, 114 photos) |
| Building | 101 California Street - 48-story office, 1.25M SF |
| Proto8 URL | https://meap.chughes.co/_test |
| Local URL | http://localhost:5255/_test |

**Reset if needed:**
```bash
cp ~/2_project-files/projects/m2-clients/101-cal/analysis/101/building.json ~/2_project-files/projects/m2-clients/_test/analysis/101/
```

## Workflow Overview

```
CURRENT SESSION:
1. Fetch Issues from GitHub
   ↓
2. PRE-TRIAGE VERIFICATION ← NEW in v2.5.0
   ├─ Check if behavior already exists in codebase
   ├─ Mark as: STALE | POSSIBLY_DONE | NEEDS_WORK
   └─ Offer to close stale issues immediately
   ↓
3. Analyze Issues (4 value angles)
   ↓
4. Interview User (detect housekeeping mode)
   ↓
5. IF HOUSEKEEPING MODE: ← NEW in v2.5.0
   ├─ Prioritize stale issue closure
   ├─ Quick verification over implementation
   └─ Skip complex fixes
   ↓
6. For Each Issue:
   ├─ Verify complexity by reading code ← NEW in v2.5.0
   ├─ Check schema consumers if applicable ← NEW in v2.5.0
   ├─ Trivial/Low & confident → Quick fix + verify
   └─ Medium/High or uncertain → Collaborative Exploration
   ↓
7. APPROVAL GATE
   ├─ Present all verification results
   ├─ User approves each fix individually
   └─ Only approved issues get closed
   ↓
8. Generate Session Report

FRESH SESSION (user-initiated):
9. User runs /feature-dev #{number} for complex issues
```

## Execution

### 1. Fetch Issues

```bash
gh issue list --state open --limit 100 --json number,title,labels,body,createdAt
```

**Error handling:**
- Auth/repo errors → Tell user to run `gh auth login` or check they're in a GitHub repo
- Empty results → Report "No open issues found" and exit

---

## 2. Pre-Triage Verification (NEW in v2.5.0)

**Purpose**: Detect issues that are already implemented but never closed. Prevents wasted effort implementing what already exists.

### For Each Issue

1. **Extract keywords** from title and body:
   - Function/class names mentioned
   - File paths referenced
   - Feature descriptions
   - Error messages quoted

2. **Search codebase** for implementation:
   ```bash
   # Search for keywords in likely locations
   grep -r "{keyword}" --include="*.ts" --include="*.md" --include="*.yaml" . 2>/dev/null | head -5
   ```

3. **Check git history** since issue creation:
   ```bash
   # Find commits that might address this issue
   git log --oneline --since="{issue_created_at}" --grep="#{issue_number}" -- .
   git log --oneline --since="{issue_created_at}" --grep="{keyword}" -- .
   ```

4. **Classify issue**:

| Status | Criteria | Action |
|--------|----------|--------|
| STALE | Issue mentions specific code that now exists | Offer immediate closure |
| POSSIBLY_DONE | Keywords found in recent commits | Flag for verification |
| NEEDS_WORK | No evidence of implementation | Proceed to triage |

### Stale Issue Handling

If STALE issues found, present immediately:

```
╔══════════════════════════════════════════════════════════════╗
║  PRE-TRIAGE: Potentially Stale Issues Found                  ║
╚══════════════════════════════════════════════════════════════╝

These issues appear to be already implemented:

#{number}: {title}
  Evidence: {what was found in codebase}
  File: {path where implementation exists}

#{number}: {title}
  Evidence: {commit message or code snippet}
  Since: {date of relevant commit}
```

Use AskUserQuestion:
```
Question: "Close these stale issues now?"

Options:
- Yes, verify and close all stale issues
- Let me review each one individually
- Skip stale detection, proceed to full triage
```

**If "Yes, verify and close all":**
1. For each stale issue, verify the implementation exists
2. Close with comment noting it was already done
3. Remove from triage list

**If "Review individually":**
1. For each stale issue, show evidence and ask approve/skip
2. Close approved ones, keep others in triage

If `--verify-only` flag: Stop here after stale issue handling.

---

### 3. Categorize and Analyze

**Categories** (from labels and title patterns):
- **Bug**: label "bug" or title prefix "B0"
- **Feature**: label "enhancement"/"feature" or title prefix "F0"
- **Documentation**: label "documentation"/"docs"
- **Wordbank**: label "wordbank" or title prefix "W0"
- **Architecture**: title prefix "ARCH:"
- **Infrastructure**: title contains "agent:", "command:", "deploy"
- **Other**: no match

### Code-Based Complexity Assessment (IMPROVED in v2.5.0)

**DO NOT estimate complexity from titles alone.** For each issue:

1. **Identify likely files** from issue body:
   - Grep for mentioned filenames, functions, components
   - Check referenced paths exist

2. **Read those files** to understand scope:
   - How many lines of code?
   - How many imports/dependencies?
   - Any tests that would need updating?

3. **Check for consumers** (for schema/config changes):
   - What reads this file?
   - Will consumers need updates too?

4. **Then assign complexity**:

| Complexity | Criteria | Verification Method |
|------------|----------|---------------------|
| Trivial | Single file, <20 lines changed, no consumers | Read file, confirm isolated |
| Low | 1-2 files, <50 lines, consumers don't need updates | Read files, grep for imports |
| Medium | 3-5 files, OR consumers need updates | Map dependency graph |
| High | 6+ files, OR architectural change, OR unclear scope | Needs exploration first |

**Example verification:**
```bash
# For wordbank change, check what reads it
grep -r "condition_narrative" reference/deploy/agents/ 2>/dev/null
# If no results → consumers don't use this field → incomplete fix
```

**Easy wins** = Trivial or Low complexity, verified by code inspection.

---

### 4. Present Triage (4 Value Angles)

Same as v2.4.0:

**A. Discovery** (What's actually broken)
**B. Path of Least Resistance** (Quick wins)
**C. Dependencies** (Root causes)
**D. Strategic Context** (Active work)

**Additional output for v2.5.0:**
```
📋 PRE-TRIAGE RESULTS
  - {N} issues marked STALE (already implemented)
  - {N} issues marked POSSIBLY_DONE (needs verification)
  - {N} issues marked NEEDS_WORK (proceed to fix)

⚠️  COMPLEXITY WARNINGS
  - #{number}: Wordbank change but no agent reads new field
  - #{number}: Marked "low" but affects 4 files
```

If `--triage-only` flag: Stop here, exit command.

---

### 5. Interview User (with Housekeeping Detection)

Use AskUserQuestion with these 4 questions:

```
Question 1: "What's blocking you from using the system right now?"
- Nothing is blocked, all issues are nice-to-have
- [List high-priority bugs from triage]
- [List field-validated issues]
- Something else not in the issue list

Question 2: "Which issue, if fixed, would make 3+ other things easier?"
- [List issues that enable multiple features]
- [List architectural issues]
- Not sure / none of them
- Something else

Question 3: "What are you building or deploying this week?"
- Proto8 field interface work
- Wordbank templates and data
- Client project (101-cal, traverse, etc.)
- System infrastructure (agents, commands, MCP)
- Nothing specific, just cleaning up issues  ← HOUSEKEEPING SIGNAL

Question 4: "If you could only fix one thing before showing someone, what would it be?"
- [Top bug by severity]
- [Top easy win by impact]
- [Most embarrassing issue from triage]
- Don't care about showing others yet  ← LOW URGENCY SIGNAL
```

### Housekeeping Mode Detection (NEW in v2.5.0)

**Trigger conditions** (any 2 of these):
- Q1 = "Nothing is blocked"
- Q3 = "Nothing specific, just cleaning up"
- Q4 = "Don't care" or similar low-urgency answer

**When housekeeping mode detected:**

```
╔══════════════════════════════════════════════════════════════╗
║  HOUSEKEEPING MODE DETECTED                                  ║
╚══════════════════════════════════════════════════════════════╝

No urgent priorities detected. Switching to cleanup workflow:

1. Close stale issues (already implemented)
2. Verify and close "possibly done" issues
3. Quick wins with high confidence only
4. Skip complex fixes (save for dedicated sessions)

Proceed with housekeeping workflow?
```

Use AskUserQuestion:
```
Question: "Housekeeping approach?"

Options:
- Yes, prioritize closing stale issues (Recommended)
- Focus on quick bug fixes instead
- Actually, let me pick specific issues to work on
```

**Housekeeping workflow priorities:**
1. STALE issues → verify and close
2. POSSIBLY_DONE issues → verify and close
3. Trivial complexity with high confidence → quick fix
4. Skip anything requiring design decisions

---

### 6. Schema Consumer Tracking (NEW in v2.5.0)

**For any change to:**
- Wordbank YAML files (form_fields, items_list, narrative templates)
- Config files read by multiple components
- Type definitions used across modules
- API response shapes

**Before marking as "ready":**

1. **Find all consumers:**
   ```bash
   # For wordbank field
   grep -r "{field_name}" reference/deploy/agents/ reference/apps/proto8/

   # For config key
   grep -r "{config_key}" --include="*.ts" --include="*.md"
   ```

2. **Check if consumers use the new content:**
   - New field added? → Do consumers read it?
   - Field renamed? → Are all references updated?
   - New template? → Is it registered/imported?

3. **If consumers don't use new content:**
   ```
   ⚠️  INCOMPLETE FIX DETECTED

   Issue #{number}: {title}

   Added: condition_narrative field to wordbank
   Problem: pca-report-agent doesn't read condition_narrative

   Options:
   - Update consumer (pca-report-agent) in this session
   - Mark issue as PARTIAL, document gap, don't close
   - Close anyway with note about consumer update needed
   ```

   Use AskUserQuestion to decide approach.

**Consumer tracking table:**

| Change Type | Find Consumers With | Consumer Update Needed? |
|-------------|---------------------|------------------------|
| Wordbank form_field | grep agents/, proto8/src/ | If field affects output |
| Wordbank narrative | grep "narrative" in agents | If narrative format changes |
| Command argument | grep commands/ for refs | If other commands call this |
| Type definition | grep for type name | If shape changes |
| Config key | grep for key name | Always |

---

## Quick Fixes (Trivial/Low, verified)

Same as v2.4.0 but with additional checks:

1. Read issue body to understand requirements
2. **Verify complexity by reading actual files** ← IMPROVED
3. **Check for schema consumers if applicable** ← NEW
4. Implement changes (Edit/Write tools)
5. **Verify consumers updated if needed** ← NEW
6. Verify changes using test bed
7. Add to pending approval queue

### Verification Requirements (EXPANDED in v2.5.0)

| Change Type | Required Verification | Consumer Check |
|-------------|----------------------|----------------|
| Terminology/typo | Syntax check | N/A |
| Wordbank form_field | YAML valid | Proto8 renders field |
| Wordbank narrative | YAML valid | Agents use template |
| Wordbank items_list | YAML valid, item appears | Cost agent recognizes item |
| Proto8 UI component | Build passes | N/A |
| Proto8 store | Build passes | Components use store |
| Command | Syntax valid | Other commands don't break |
| Agent | Markdown valid | Commands invoke correctly |

---

## Approval Gate

Same as v2.4.0:
- Present verification summary
- Individual approval for each issue
- Batch approval option (opt-in)
- Close only after explicit approval

**Additional v2.5.0 output:**
```
┌─────────────────────────────────────────────────────────────┐
│ #{number}: {title}                                          │
├─────────────────────────────────────────────────────────────┤
│ Changes:                                                    │
│   - {file1}: {description}                                  │
│                                                             │
│ Verification:                                               │
│   ✅ YAML valid                                             │
│   ✅ Build passes                                           │
│   ✅ Consumer check: pca-report-agent reads new field       │ ← NEW
│                                                             │
│ Complexity: Verified Low (2 files, 45 lines)                │ ← NEW
└─────────────────────────────────────────────────────────────┘
```

---

## Collaborative Exploration

Same as v2.4.0:
- Multi-round thematic interviews (5 themes)
- Write handoff comment for /feature-dev
- Handoff instructions for fresh session

---

## Session Report

```markdown
## Session Summary - Issue Triage & Resolution

**Pre-Triage Results**:
- Stale issues closed: {count}
- Verified as already done: {list}

**Mode**: {Normal | Housekeeping}

**Quick Fixes** (Approved & Closed): {count}
| Issue | Title | Verification | Consumer Check | Status |
|-------|-------|--------------|----------------|--------|
| #{n} | {title} | ✅ verified | ✅ consumers OK | Closed |

**Incomplete Fixes** (Consumer Update Needed): {count}
| Issue | Title | What's Done | What Remains |
|-------|-------|-------------|--------------|
| #{n} | {title} | Wordbank updated | Agent needs update |

**Complex Issues** (Explored): {count}
| Issue | Title | Status |
|-------|-------|--------|
| #{n} | {title} | 📝 Ready for /feature-dev |

**Interview Insights**:
- Blockers: {Q1 answer}
- Leverage: {Q2 answer}
- Context: {Q3 answer}
- Priority: {Q4 answer}
- Mode detected: {Housekeeping | Normal}
```

---

## Version History

**v2.5.0** (2026-01-18): Pre-triage verification and housekeeping mode
- NEW: Pre-triage verification detects already-implemented issues
- NEW: Housekeeping mode with different workflow when no urgency
- NEW: Code-based complexity estimation (read files, not just titles)
- NEW: Schema consumer tracking for wordbank/config changes
- NEW: `--verify-only` flag for stale issue detection only
- IMPROVED: Complexity assessment requires reading actual code
- IMPROVED: Verification table includes consumer checks

**v2.4.0** (2026-01-15): Approval gates
- NEW: Explicit approval gates before closing
- NEW: Individual approval for each issue
- NEW: Batch approval opt-in

**v2.3.0**: Collaborative exploration
- NEW: Multi-round thematic interviews
- NEW: Handoff comments for /feature-dev

## Notes

- **Pre-triage verification**: Catches stale issues before wasted effort
- **Housekeeping mode**: Different workflow for cleanup sessions
- **Consumer tracking**: Schema changes aren't complete until consumers updated
- **Code-based complexity**: Read files before estimating, not just titles
- **Approval gates**: No issue closes without explicit user approval
- GitHub issue operations require gh CLI authentication
