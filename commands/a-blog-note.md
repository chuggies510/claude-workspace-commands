---
name: a-blog-note
version: v1.0.0
description: Quick capture of session insights worth blogging about
argument-hint: '"topic title for the blog note"'
allowed-tools: [Read, Write, Bash, AskUserQuestion]
thinking: true
---

# /a-blog-note Command

Quickly capture insights and discoveries from the current session for later blog post development. Simpler than `/a-retrospective` - this is for in-the-moment capture, not deep historical exploration.

## Example Usage

```
/a-blog-note "SD card benchmarking deep dive"
```

Creates `docs/blog-notes/2026-01-19-sd-card-benchmarking-deep-dive.md` with structured template.

## When to Use

- You've discovered something interesting during work
- Data or insights worth sharing publicly
- "This would make a good blog post" moments
- Technical learnings with evidence

## Implementation

### Step 1: Parse Arguments

Extract topic from `$ARGUMENTS`. If no topic provided, ask user directly:

> What's the topic for this blog note? (e.g., "SD card benchmarking deep dive")

### Step 2: Generate Slug and Path

**Action**: Run these bash commands to generate file path:

```bash
DATE=$(date +%Y-%m-%d)
SLUG=$(echo "$TOPIC" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-' | sed 's/--*/-/g; s/^-//; s/-$//')
FILE_PATH="docs/blog-notes/${DATE}-${SLUG}.md"
mkdir -p docs/blog-notes/
```

### Step 3: Gather Context Automatically

**Action**: Collect context without user input using these commands:

```bash
# Session number (fallback to "unknown" if not found)
SESSION=$(grep "^session:" .claude/memory-bank/active-context.md 2>/dev/null | awk '{print $2}' || echo "unknown")

# Recent commits from today (empty if not a git repo or no commits)
COMMITS=$(git log --since="00:00" --oneline 2>/dev/null | head -5 || echo "No commits today")

# Project name from directory
PROJECT=$(basename "$(pwd)")
```

### Step 4: Quick Interview

**Action**: Use AskUserQuestion tool with these parameters:

```json
{
  "questions": [
    {
      "question": "What did you discover?",
      "header": "Discovery",
      "options": [
        {"label": "Performance insight", "description": "Benchmarks, measurements, timing data"},
        {"label": "Debugging revelation", "description": "Root cause found, fix discovered"},
        {"label": "Architecture pattern", "description": "Design decision, structural insight"},
        {"label": "Tool/workflow improvement", "description": "Better way to do something"}
      ],
      "multiSelect": false
    },
    {
      "question": "What evidence do you have?",
      "header": "Evidence",
      "options": [
        {"label": "Benchmark data", "description": "Measurements, performance numbers"},
        {"label": "Code snippets", "description": "Configs, examples, diffs"},
        {"label": "Before/after comparison", "description": "Visual or data comparison"},
        {"label": "Screenshots/logs", "description": "Visual evidence, log output"}
      ],
      "multiSelect": true
    },
    {
      "question": "What visual would capture this?",
      "header": "Imagery",
      "options": [
        {"label": "Architecture diagram", "description": "Boxes and arrows showing flow or structure"},
        {"label": "Before/after visual", "description": "Side-by-side comparison of the change"},
        {"label": "Metaphor illustration", "description": "Robot, certificate, journey—something evocative"},
        {"label": "Screenshot with annotations", "description": "Real output with callouts"}
      ],
      "multiSelect": true
    }
  ]
}
```

After AskUserQuestion, ask in free text: "What's the key 'aha' moment readers should take away?"

### Step 5: Create Blog Note

**Action**: Write markdown file to `$FILE_PATH` with this template (substitute variables):

```markdown
# {Topic Title}

**Session**: {SESSION} ({DATE})
**Project**: {PROJECT}
**Status**: Draft - needs development

## The Discovery

{2-3 sentences summarizing the insight from interview answers}

## Key Insights

### 1. {First insight from discovery type}

{Placeholder for user to expand}

### 2. {Second insight}

{Placeholder}

### 3. {Third insight}

{Placeholder}

## Evidence

**Types**: {List evidence types selected}

### Raw Data

{Placeholder for pasting data}

### References

- Session {SESSION} handoff
- Commits: {COMMITS}

## Blog Post Angles

1. **{Angle based on discovery type}**: {Brief description}
2. **{Alternative angle}**: {Brief description}

## Visual Ideas

**Type**: {Imagery type(s) selected}

**Hero concept**: {One-sentence description of the main image that would draw readers in}

**Supporting visuals**:
- {Placeholder for additional visual ideas}

**Existing assets to check**:
```bash
# Related diagrams in this project
grep -r "```mermaid" . --include="*.md" -l 2>/dev/null | head -5
# Existing blog images
ls ~/2_project-files/projects/active-projects/chungus-blog/static/images/ 2>/dev/null | tail -10
```

## TODO

- [ ] Expand key insights with detail
- [ ] Add raw data and screenshots
- [ ] Sketch or describe hero image concept
- [ ] Check for reusable existing diagrams
- [ ] Choose blog post angle
- [ ] Draft post with imagery: /a-blog
```

### Step 6: Report Success

**Action**: Tell user:

```
Created: {FILE_PATH}

Next steps:
1. Fill in the key insights while they're fresh
2. Paste any raw data or screenshots
3. Jot down the hero image idea before you forget
4. When ready to publish: /a-blog (will create imagery automatically)
```

## Notes

- Keep it fast - capture while context is fresh
- The output is a starting point, not a finished product
- Works in any project with a `docs/` directory
- Related commands: `/a-retrospective` (deep historical exploration)
