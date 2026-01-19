---
name: a-feature-dev-superpowered-v1.1
version: v1.1.0
description: Orchestrate feature-dev → write-plan → execute-plan with stateless resume across sessions
argument-hint: Optional feature description or @handoff-file.md to begin
allowed-tools: [SlashCommand, Read, Write, Glob, AskUserQuestion]
thinking: true
---

# Feature Development Orchestrator

## Overview

Manage feature development across multiple sessions by orchestrating feature-dev → write-plan → execute-plan workflow. Automatically detect which phase you're in, persist architecture decisions, and enable seamless resume after `/clear`.

**Core principle:** Filesystem state = workflow state. Scan docs/plans/ and infer where user left off.

---

## What This Command Does

**Session 1: Discovery & Architecture**
- Run feature-dev skill (discovery, exploration, questions, architecture design)
- User approves architecture approach
- Save architecture to `docs/plans/{feature}/architecture.md`
- Offer to continue with planning

**Session 2+: Stateless Resume**
- Detect feature directories in docs/plans/
- Show current phase (architecture / planning / execution)
- Let user choose: continue current feature or start new

**Multi-session workflow:**
- After architecture → run write-plan to create tasks
- After tasks → run execute-plan in batches
- After implementation → run code review

---

## Directory Structure

```
docs/plans/
├── {feature-name}/
│   ├── architecture.md           # From feature-dev Phase 4
│   ├── tasks.md                  # From write-plan
│   └── archive/
│       └── architecture-v1.md    # Old versions if restarted
└── another-feature/
    ├── architecture.md
    └── tasks.md
```

User manually moves completed features to `docs/plans/completed-features/` when done.

---

## Usage

**Start new feature with description:**
/a-feature-dev-superpowered-v1.1 "add CSV export for cost cards"

**Start new feature with handoff document:**
/a-feature-dev-superpowered-v1.1 @docs/handoffs/my-feature.md to begin

**Resume existing feature:**
/a-feature-dev-superpowered-v1.1

---

## The Process

### Entry Point: Note on Dependencies

This command requires marketplace plugins (assumed installed):
- /feature-dev:feature-dev (discovery, exploration, architecture)
- /superpowers:write-plan (task generation)
- /superpowers:execute-plan (batch execution)

If any skill fails to invoke, Claude will show installation instructions automatically.

Proceed to state detection.

---

### State Detection: Determine Current Phase

Use Glob tool to find all feature directories in docs/plans/.
Pattern: `docs/plans/*/architecture.md`

For each feature found:
- Extract feature name from directory path
- Check if architecture.md exists
- Check if tasks.md exists
- Determine phase based on files present

Count total features found.

Route based on state:
- **User provided description** → New Feature Handler
- **Zero features found** → Prompt for description, then New Feature Handler
- **One feature found** → Single Feature Resume Handler
- **Multiple features found** → Multi-Feature Selection Handler

---

### Handler 1: New Feature (Discovery & Architecture)

**Trigger:** User provided feature description

#### Step 1: Parse Arguments and Generate Feature Name

**Check if arguments start with @file syntax:**

If arguments start with `@`:
- Extract file path (everything between @ and first space)
- Read file to understand feature context
- Infer feature name from:
  1. Filename (strip path, date prefix, -requirements suffix, extension)
  2. File title/header (first # heading)
  3. If unclear, ask user for feature name
- Store full arguments (including @file) to pass to feature-dev

If arguments are plain description:
- Use existing Feature Naming Rules (see Common Patterns)
- Convert description to valid directory name

Examples:
- `@docs/handoffs/2025-11-22-proto67-requirements.md to begin` → infer "proto67" or "proto67-deployment"
- `"Add CSV Export for Cost Cards"` → "add-csv-export-cost-cards"

Present the generated name to user:
- Feature description: "Add CSV export for cost cards"
- Generated feature name: add-csv-export-cost-cards

Ask: Use this name?
1. Yes, proceed
2. No, let me provide custom name

If user chooses custom name:
- Prompt for their preferred name
- Validate it follows naming rules (lowercase, hyphens only, no special chars)
- If invalid, show error and ask again
- If valid, use their custom name

#### Step 2: Check for Name Collision

Check if directory already exists at `docs/plans/{feature-name}/`

If directory exists, show warning:
- Feature directory already exists: docs/plans/{feature-name}/
- This feature may already be in progress

Present options:
1. Resume existing feature
2. Archive existing and start fresh
3. Use different feature name
4. Exit

Handle each option accordingly.

If directory doesn't exist, proceed to next step.

#### Step 3: Launch Feature-Dev Skill

Invoke `/feature-dev:feature-dev` via SlashCommand tool.

**Construct command with Phase 4 stop instruction**:

Append stop instruction to user's arguments to prevent feature-dev from proceeding to implementation.

**Command format**:
- With @file: `/feature-dev:feature-dev @docs/handoffs/{file}.md to begin. STOP after Phase 4 (Architecture Design) - do not proceed to Phase 5 (Implementation). Return control to orchestrator for planning phase.`
- Without @file: `/feature-dev:feature-dev {description}. STOP after Phase 4 (Architecture Design) - do not proceed to Phase 5 (Implementation). Return control to orchestrator for planning phase.`

**Why**: Feature-dev normally runs all 7 phases. We only need Architecture (Phase 4), then orchestrator hands off to write-plan for planning/execution.

Feature-dev will run through:
- Phase 1: Discovery (understand problem, reads @file if provided)
- Phase 2: Codebase Exploration (2-3 code-explorer agents)
- Phase 3: Clarifying Questions (ask user for details)
- Phase 4: Architecture Design (2-3 code-architect agents)
- **STOP here** (per instruction)

Wait for Phase 4 to complete. User will see 2-3 architecture options and approve one.

#### Step 4: Capture Architecture Decision

After feature-dev Phase 4 completes, ask user which approach they approved.

Present prompt:
- feature-dev presented architecture options
- Which approach did you approve?

Options:
1. Minimal Changes (smallest change, maximum reuse)
2. Clean Architecture (maintainability, elegant abstractions)
3. Pragmatic Balance (speed + quality)
4. None - Phase 4 didn't complete or I need to revise

**If user chooses 4:**
- Show: "Please complete feature-dev Phase 4 first, then run this command again."
- Exit gracefully

**If user chooses 1, 2, or 3:**
- Proceed to extract architecture from conversation

#### Step 5: Extract Architecture from Conversation

Read the conversation to find feature-dev's Phase 4 output.
Locate the code-architect agent outputs for the three approaches.
Find the specific approach the user selected (Option 1, 2, or 3).

Extract from that approach:
- Approach name and summary
- Files to modify (list with descriptions)
- Files to create (list with purposes)
- Implementation steps (ordered list)
- Trade-offs (pros and cons)
- Time estimate
- Risk assessment

**If extraction succeeds:**
- Proceed to Step 6 with extracted details

**If extraction fails:**
Show warning: Could not extract architecture details from conversation.

Present recovery options:
1. Manual entry (I'll ask 5 questions)
2. Copy/paste from conversation
3. Re-run feature-dev Phase 4
4. Exit

**If option 1 (manual entry):**
Ask user for architecture details:
1. Which approach? [Minimal/Clean/Pragmatic]
2. Main files to modify (comma-separated)
3. Main files to create (comma-separated)
4. Brief rationale (1-2 sentences)
5. Estimated time (hours)

Collect answers and generate architecture.md from responses.

**If option 2 (copy/paste):**
Prompt: Please copy the architecture details from above and paste here.
Wait for user to paste text.
Parse the pasted text to extract files, steps, trade-offs.

**If option 3 or 4:**
- Exit appropriately

#### Step 6: Create Feature Directory and Save Architecture

Now that architecture is captured, create the directory structure:
- Create `docs/plans/{feature-name}/`
- Create `docs/plans/{feature-name}/archive/`

Write architecture to `docs/plans/{feature-name}/architecture.md`:

```markdown
# Architecture: {Feature Name}

**Created**: {current date}
**Source**: feature-dev Phase 4 (code-architect agents)
**Approach**: {Minimal Changes / Clean Architecture / Pragmatic Balance}

---

## Problem Statement

{User's feature description}

## Architecture Decision

**Approach Chosen**: {chosen approach}

**Rationale**: {why this approach}

---

## Implementation Plan

### Files to Modify

{numbered list from extraction}

### Files to Create

{numbered list from extraction}

### Implementation Steps

{ordered steps from agent output}

---

## Trade-offs

### Pros
{list from agent analysis}

### Cons
{list from agent analysis}

---

## Time Estimate

{from agent output or manual entry}

---

**Next Step**: Run `/a-feature-dev-superpowered-v1.1` to continue with implementation planning.
```

#### Step 7: Offer Next Action

Announce: Architecture saved!
- File: docs/plans/{feature-name}/architecture.md
- Approach: {chosen approach}

Present options:
1. Continue with planning (run write-plan)
2. Review architecture first
3. Exit and resume later

**If option 1:** Proceed to Planning Handler
**If option 2 or 3:** Show file path and exit with resume instructions

---

### Handler 2: Single Feature Resume

**Trigger:** Found exactly one feature in docs/plans/

Determine which phase the feature is in:
- **architecture.md exists, tasks.md doesn't** → Planning Phase
- **tasks.md exists** → Execution Phase
- **Only directory, no files** → Corrupted state

#### Planning Phase

Show feature status (see Common Patterns § Feature Status Display):
- Feature name
- Architecture status: Complete (with file path)
- Plan status: Not created yet
- Next action: Generate implementation plan

Present options:
1. Continue with planning (run write-plan)
2. Review/edit architecture
3. Restart architecture
4. Start different feature
5. Exit

**If option 1 (Continue with planning):**

Read architecture.md to get context.
Invoke `/superpowers:write-plan` via SlashCommand.

write-plan will:
- Read the architecture from docs/plans/{feature-name}/architecture.md
- Generate bite-sized tasks (2-5 minutes each)
- Create exact file paths and code examples
- Add verification steps per task
- Save to docs/plans/{feature-name}/tasks.md

After write-plan completes, announce:
- Implementation plan created
- File: docs/plans/{feature-name}/tasks.md

Present options:
1. Start execution (run execute-plan)
2. Review task list
3. Exit and resume later

If user chooses execution, proceed to Execution Handler.

**If option 2 (Review/edit):**
- Show: "Architecture file: docs/plans/{feature-name}/architecture.md"
- Exit with resume instructions

**If option 3 (Restart architecture):**
- Create archive: Move current architecture.md to archive/ with timestamp
- Launch feature-dev Phase 4 again (architecture design only)
- Return to Step 4 of New Feature Handler (capture architecture)

**If option 4 (Different feature):**
- Prompt for new feature description
- Go to New Feature Handler

**If option 5 (Exit):**
- Exit with resume instructions

#### Execution Phase

Show feature status (see Common Patterns § Feature Status Display):
- Feature name
- Architecture status: Complete (with file path)
- Plan status: Complete (with file path)
- Execution status: Ready to continue
- Next action: Execute implementation plan

Present options:
1. Continue execution (run execute-plan)
2. Review task list
3. Regenerate plan
4. Start code review
5. Start different feature
6. Exit

**If option 1 (Continue execution):**

Invoke `/superpowers:execute-plan` via SlashCommand.

execute-plan will:
- Read tasks.md
- Check git commits to identify completed tasks
- Resume from next incomplete task
- Execute batch (default 3 tasks)
- Wait for user approval between batches

execute-plan handles its own progress tracking and resume logic.

After user exits execute-plan, announce:
- Progress saved in git commits
- Resume next batch: Run /a-feature-dev-superpowered-v1.1

**If option 2 (Review):**
- Show file path
- Exit with resume instructions

**If option 3 (Regenerate plan):**
- Check if architecture.md exists
- If yes: Archive old tasks.md, re-run write-plan from architecture
- If no: Show error (cannot regenerate without architecture)

**If option 4 (Code review):**

Ask user to confirm:
- Start code review now?
- Note: Code review works best after all tasks are complete
- If tasks are still in progress, review will analyze what's done so far
- Continue? [y/n]

If user confirms, invoke `/superpowers:requesting-code-review`.

Provide context:
- Feature name: {feature-name}
- Task file: docs/plans/{feature-name}/tasks.md
- Architecture file: docs/plans/{feature-name}/architecture.md
- Git commits since tasks.md was created

requesting-code-review will launch code-reviewer agents and report findings.

**If option 5 or 6:**
- Handle same as Planning Phase

---

### Handler 3: Multi-Feature Selection

**Trigger:** Found multiple feature directories in docs/plans/

For each feature, determine its phase:
- Check if architecture.md exists
- Check if tasks.md exists
- Classify as: Architecture only / Planning needed / Execution ready / In progress

Present feature list:

Found {N} features in progress:

[1] proto67-deployment (2025-11-22)
- Status: ✅ Architecture → ✅ Tasks → 🔄 Execution in progress

[2] auth-fix (2025-11-18)
- Status: ✅ Architecture → ⏸️ Planning needed

[3] ui-refactor (2025-11-12)
- Status: ✅ Architecture only

Ask user to choose:
- Enter [1-{N}] to continue feature
- Enter 'new' to start fresh feature
- Enter 'archive' to clean up old features
- Enter 'exit' to cancel

**If user selects a number:**
- Load that feature's state
- Route to Single Feature Resume Handler with that feature

**If user enters 'new':**
- Prompt for feature description
- Go to New Feature Handler

**If user enters 'archive':**

Ask which features to archive:
- Enter numbers separated by commas (e.g., "1,3")
- Enter 'all' to archive all features
- Enter 'back' to cancel

For each selected feature:
- Create `docs/plans/completed-features/` if needed
- Move entire feature directory there
- Confirm: "Archived: {feature-name}"

After archiving, re-scan docs/plans/ and show updated list.
If zero features remain, prompt for new feature description.

**If user enters 'exit':**
- Exit gracefully

---

## Common Patterns

### Feature Naming Rules

**Valid characters:** `a-z`, `0-9`, `-` (hyphen)
**Format:** `lowercase-with-hyphens`
**Length:** 1-50 characters
**No:** Spaces, uppercase, special characters, leading/trailing hyphens

**Auto-sanitization process:**
- Convert to lowercase
- Replace spaces with hyphens
- Remove invalid characters
- Trim to 50 characters
- Strip leading/trailing hyphens

**Examples:**
- ✅ "add-csv-export"
- ✅ "fix-auth-timeout"
- ❌ "Add_CSV_Export" (uppercase, underscores)
- ❌ "-fix-bug-" (leading/trailing hyphens)

### Feature Status Display

Show feature status with this format:

**Template:**
- Feature name: {feature-name}
- Architecture status: {Complete with path / Not created}
- Plan status: {Complete with path / Not created}
- Execution status: {Ready / In progress / Not started}
- Next action: {Phase-specific guidance}

**Status indicators:**
- ✅ Complete
- ⏳ Not started
- 🔄 In progress
- ⏸️  Paused/waiting

**Phase-specific formats:**

Planning phase (architecture exists, no tasks):
- Architecture: ✅ Complete (docs/plans/{feature}/architecture.md)
- Plan: ⏳ Not created yet
- Next: Generate implementation plan from architecture

Execution phase (tasks exist):
- Architecture: ✅ Complete
- Plan: ✅ Complete (docs/plans/{feature}/tasks.md)
- Execution: 🔄 Ready to continue
- Next: Execute implementation plan

### Exit Messages

When user chooses to exit, show:
- Feature: {feature-name}
- Current phase: {phase}
- Resume anytime with: /a-feature-dev-superpowered-v1.1

When user needs to review files, show:
- Architecture: docs/plans/{feature-name}/architecture.md
- Tasks: docs/plans/{feature-name}/tasks.md
- Run /a-feature-dev-superpowered-v1.1 when ready to continue

---

## Error Handling

### Error: No Feature Description Provided

**When:** User runs command without arguments and no features exist

Show error message:
- No feature description provided and no existing features found
- Usage: /a-feature-dev-superpowered-v1.1 "feature description"
- Examples: "add dark mode toggle" or "fix authentication timeout"

### Error: Missing Required Skills

**When:** Dependency validation fails (skills not installed)

Show error message listing missing skills:
- /feature-dev:feature-dev (not found)
- /superpowers:write-plan (not found)

Provide installation instructions:
- /plugin install feature-dev
- /plugin install superpowers
- Or check: /plugin list

### Error: Invalid Feature Name

**When:** User provides custom name with illegal characters

Show warning:
- Invalid feature name: "{user-input}"
- Feature names must use lowercase, numbers, hyphens only
- No spaces (use hyphens instead)
- Length: 1-50 characters
- Suggested name: "{sanitized-version}"

Ask: Use suggested name?
1. Yes
2. No, let me try again

### Error: Cannot Create Directory

**When:** File permission error creating docs/plans/{feature}/

Show error:
- Cannot create directory: docs/plans/{feature-name}/
- Permission denied

Guide user to check permissions:
- Check: ls -ld docs/plans/
- Fix: chmod 755 docs/plans/

### Error: Corrupted Feature State

**When:** Directory exists but missing expected files

Show warning:
- Corrupted feature state: {feature-name}
- Directory exists but missing required files

List expected files:
- architecture.md (missing)
- archive/ subdirectory (missing)

Present recovery options:
1. Archive corrupted state and start fresh
2. Manually fix files
3. Delete feature directory

---

## Integration Notes

### Marketplace Plugin Dependencies

This command orchestrates marketplace plugins (installed globally, not MEAP-specific):

**feature-dev plugin:**
- Provides: /feature-dev:feature-dev
- Used for: Discovery, exploration, architecture design (Phases 1-4)
- Installation: /plugin install feature-dev
- We use Phases 1-4 only (implementation/review handled by superpowers)

**superpowers plugin:**
- Provides: /superpowers:write-plan, /superpowers:execute-plan, /superpowers:requesting-code-review
- Used for: Task generation, batch execution, code review
- Installation: /plugin install superpowers

**If plugins missing:** Command validates dependencies at entry point and shows installation instructions.

### SlashCommand Tool Usage

Invoke skills using SlashCommand tool with full skill path and arguments.

**Invocations used in this workflow:**
- SlashCommand("/feature-dev:feature-dev {description}")
- SlashCommand("/superpowers:write-plan")
- SlashCommand("/superpowers:execute-plan")
- SlashCommand("/superpowers:requesting-code-review")

**Context passing:**
Before invoking write-plan or execute-plan, provide file paths in conversation context. Skills can access current working directory and read docs/plans/ files.

**Integration contracts:**
- write-plan reads architecture.md, outputs tasks.md
- execute-plan reads tasks.md, checks git for progress, resumes automatically
- requesting-code-review analyzes git commits against task list

---

## Success Criteria

**v1.1 is successful if:**
- ✅ User can start feature, complete discovery, save architecture
- ✅ User can resume next session, generate plan from architecture
- ✅ User can execute plan in batches across multiple sessions
- ✅ State persists across /clear (filesystem-based)
- ✅ Multi-feature support (show all, let user choose)
- ✅ Clear prompts guide user through transitions
- ✅ Graceful error handling with recovery options

---

## What's Not Included (v1.1)

**Out of scope:**
- Automatic cleanup of old features (user archives manually)
- Feature branching (git worktree integration)
- Progress percentage tracking (delegated to execute-plan)
- Architecture comparison tool (show diffs between approaches)
- Auto-commit after each phase
- Rollback mechanism (user deletes files to restart)

**Consider for v2.0:**
- `/a-archive-feature` command for cleanup
- Feature comparison (diff architectures before choosing)
- Progress dashboard (visual task completion)
- Git integration (auto-branch per feature)

---

**Version**: v1.1.0
**Created**: 2025-11-23
**Purpose**: Orchestrate feature-dev → write-plan → execute-plan with stateless resume
**Pattern**: Pure workflow orchestration - leverage existing skills, provide seamless multi-session experience
