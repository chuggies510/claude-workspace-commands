---
name: a-retrospective
version: v1.0.0
description: Explore project history for documentation and storytelling
argument-hint: "[topic: feature-name|architecture|debugging|migrations|failures]"
allowed-tools: [Read, Grep, Glob, Bash, Task, Write, AskUserQuestion]
thinking: true
---

# /a-retrospective Command

Explore a project's history through conversation to uncover stories worth documenting. This is collaborative - user corrections and context additions are essential.

## Example Usage

```
/a-retrospective authentication
/a-retrospective "the timeout bug"
/a-retrospective failures
```

## When to Use

- After completing a major feature or migration
- When you want to document how something evolved
- To capture lessons learned before they fade
- Building internal documentation or blog content

## Implementation

### Initial Exploration

**If topic provided in $ARGUMENTS**, launch 3-4 parallel explore agents:

| Agent Focus | What to Search |
|-------------|----------------|
| Memory Bank | `.claude/memory-bank/archive/` - session handoffs mentioning topic |
| Git History | `git log --all --oneline --grep="{topic}"` - commits, dates, reverts |
| Documentation | `docs/`, README files, CLAUDE.md gotchas |
| Code | Files related to topic, tests, configs |

**If no topic provided**, ask:

> What part of this project's history should we explore?
> Examples: feature names, architecture changes, debugging sagas, failures

### Present and Iterate

After agents return, present findings:

```
## Initial Findings: {Topic}

### Timeline (What I Found)
| Date | Event | Evidence |
|------|-------|----------|
| ... | ... | commit/file |

### Gaps (What's Missing)
- {Areas where evidence is thin}

### Threads to Follow
1. {Interesting thread}
2. {Another thread}

What should we dig into? What am I missing?
```

**This phase repeats** based on user input:

| User Says | Action |
|-----------|--------|
| "What about X?" | Search: `git log --all --oneline --grep="X" -i`, `grep -r "X" --include="*.md"` |
| "Actually, Y happened because..." | Capture quote verbatim - this context is gold |
| "You didn't mention Z" | Search specifically for Z evidence |

Continue until user is satisfied with coverage.

### Build Timeline

As evidence accumulates, maintain detailed timeline:

```markdown
## Timeline: {Topic}

### {Era/Phase Name}

**Date**: YYYY-MM-DD
**Event**: What happened
**Evidence**: Commit hash, file path, session number
**Context**: Why it happened (from user input)
**User Quote**: "{Direct quote if available}"
```

Include exact dates, commit hashes, session numbers, file paths, and user quotes.

### Extract Stories

For significant events, capture:

```markdown
### Story: {Title}

**The Problem**: What pain or need existed
**Why We Tried This**: The rational reason (not just "it failed")
**What We Built**: Specific files, commits, features
**What Happened**: Success, failure, pivot
**The Lesson**: What we learned
**Evidence**: {commit hash, file path, session number}
```

**Failure stories are valuable** - document:
1. Why it made sense at the time
2. What was built (files, commits)
3. Why it failed (specific, technical)
4. What replaced it
5. The lesson for future work

### Write Documentation

When story is complete, write to `docs/history/{topic}.md`:

```markdown
# {Topic} History

{Brief description}

**Documented**: Session {N} ({DATE})
**Scope**: {Date range covered}

## {Era 1}
{Rich narrative with evidence}

## {Era 2}
...

## Key Dates
| Date | Event |
|------|-------|

## Lessons Learned
1. ...

## Blog Topics
{Ideas for public content, with redaction notes if needed}
```

**Quality checklist before finalizing**:
- All dates have evidence (commit hash or file date)
- User quotes captured verbatim
- "Why we tried it" documented for failures
- Timeline chronologically accurate
- Lessons are specific, not generic

## Example Session Flow

```
User: "/a-retrospective authentication"

Claude: [Launches parallel explore agents]
        [Presents timeline: initial implementation, security fixes, refactors]

User: "What about the JWT migration?"

Claude: [Searches for JWT commits and files]
        [Adds JWT migration to timeline]

User: "Actually, we tried session tokens first but they didn't scale"

Claude: [Captures quote about sessions not scaling]
        [Updates timeline with session tokens as predecessor]

User: "Now document this properly"

Claude: [Creates docs/history/authentication.md]
        [Includes timeline, lessons, user quotes]
```

## Notes

- This is exploration and documentation, not implementation
- User corrections are features, not interruptions
- Capture user quotes verbatim - they explain the "why"
- Sensitive data must be flagged before public sharing
- Related commands: `/a-blog-note` (quick capture), `/a-blog` (publish, planned)
