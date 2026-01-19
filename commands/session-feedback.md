---
name: session-feedback
description: Capture session friction and context for meap2-it central learning
version: 2.0.0
tags: [workspace, feedback, debugging]
scope: workspace
---

# /session-feedback

Capture what went wrong in this session. Output goes to meap2-it central for learning.

## Process

1. **Review the conversation** and identify friction points:
   - Redirections: "No, I meant X" / "not that"
   - Retries: "do it again" / "that's wrong"
   - Repeated feedback: "I already said..."
   - Frustration: short responses, caps, explicit annoyance
   - Giving up: "forget it" / "just do X"

2. **Present findings** to user for confirmation

3. **Save** to `~/2_project-files/projects/active-projects/meap2-it/docs/planning/input/`
   - Filename: `feedback-{project}-{YYYY-MM-DD}.md`

## Output Format

```markdown
# Session Feedback: {Project} - {Date}

## Session Context

**Project**: {name and path}
**Starting state**: {what was loaded}
**Commands run**: {slash commands, in order}
**Key files**: {files read/written/edited}
**Tools used**: {Bash, Read, Write, agents, etc.}

## Friction Points

### {Issue Title}
**User said**: "{exact quote}"
**What happened**: {what Claude did wrong}
**Pain level**: low | medium | high
**Lesson**: {what to do differently}

## What Worked
- {positive patterns}

## Pattern Summary
{recurring failure modes, recommendations for meap2-it}
```

## Key Principle

Show the pain. Quote exact user words. A debugger reading this should understand both the state and the frustration.
