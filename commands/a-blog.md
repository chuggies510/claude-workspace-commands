---
name: a-blog
description: Create blog posts and articles from project work and development insights
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
thinking: true
---

# Create Blog Post

## Goal

Create a blog post from the current session's work. Uses conversational discovery to find the interesting angle, then writes and deploys a simple, matter-of-fact post.

## Input

Topic hint (optional): $ARGUMENTS

## Process

1. Discover the angle through conversation
2. Write the post in a simple, consistent format
3. Create imagery (hero + section breaks as needed)
4. Save to Hugo content directory, build, deploy to blog.chughes.co

---

## Discover the Angle

Read the conversation history. What actually happened? What decisions were made? What was surprising, frustrating, or satisfying?

Propose 2-4 specific angles directly to the user. Be concrete about what makes each worth writing about:

1. **[Specific angle]** - Why it might be worth writing about
2. **[Different angle]** - The insight here
3. **[Third option]** - What makes this notable

Ask which resonates, or if there's something else entirely.

Based on response:
- If they pick one, ask: "What specifically about that feels worth capturing?"
- If they say "something else", ask them to describe it
- If unsure, ask what they'd want to remember in 6 months

Confirm before writing: "So the blog is about [X]. Correct?"

---

## Write the Post

### Voice: Sound Like a Person, Not AI

The goal is writing that sounds like someone telling a story, not generating content.

**AI writing tells:**
> "This isn't a configuration issue. It's a known bug in how the Philips Hue Bridge handles third-party Zigbee devices. IKEA Trådfri bulbs paired to a Hue Bridge don't transition brightness properly during automations. They receive the final value but ignore the fade duration."

**Human writing shows:**
> "I kept thinking I'd configured something wrong. Checked the automation. Checked the bulb settings. Tried different transition times. Nothing helped. Turns out Hue bridges just don't handle IKEA bulbs well. The fade never works—you set a 30-minute transition and they just jump straight to the end brightness."

**What makes writing feel AI-generated:**
- Preemptive defense ("This isn't X, it's Y") - anticipating objections nobody made
- Too systematic - each sentence adds exactly one new fact in order
- Clinical precision - sounds like documentation, not conversation
- Explaining AT the reader instead of talking WITH them
- No uncertainty, no fragments, no trailing thoughts

**What makes writing feel human:**
- Uncertainty and discovery ("I kept thinking...", "Turns out...")
- Fragments and incomplete thoughts ("Nothing helped.")
- Doubling back ("The fade never works—" then explaining what that means)
- Trailing reactions ("Every time.", "At all.", "Obviously.")
- Casual asides ("the ones causing all the problems")
- Questions you actually wondered ("do I set this up myself, or just pay?")

**Practical rules:**
- Start paragraphs with "I" sometimes, not always topic sentences
- Use em-dashes for asides and interruptions
- Let some sentences be short. Really short.
- Include the parts where you were wrong or confused
- End sections with reactions, not summaries

### Content Principles

- Straightforward documentation, not performance
- Write for future reference
- Specific details over generic summaries
- Avoid superlatives and self-congratulation
- Sound like you're telling a friend, with all the technical details intact
- **Always include Claude attribution** at the end (see template)

### Blog Template

Generate the current date with `date +%Y-%m-%d`. Use this structure as a starting point, but let the story dictate the sections:

```markdown
---
title: "[Specific, descriptive title]"
date: [YYYY-MM-DD from date command]
draft: false
tags: ["tag1", "tag2"]
---

![Hero image alt text](/images/{date}-{slug}/hero.svg)

## [Opening that establishes the problem or situation]

[Start with the frustration, the goal, or the trigger. What made you do this?]

## [Sections that follow the story naturally]

[What happened, what you tried, what worked, what didn't.
Use headers that describe what's in the section, not generic labels.
"The DIY Detour" is better than "Approach 1".
"Where Things Broke" is better than "Issues Encountered".]

## [Ending that lands somewhere]

[What's different now. What you'd tell someone else. A reaction, not a summary.]

---

*Written with Claude.*
```

**Section headers should be specific to the content:**
- ❌ "Context", "What Happened", "Outcome" (generic, formulaic)
- ✅ "The Problem That Finally Broke Me", "Three Sessions Down the Drain", "Fine. Nabu Casa It Is." (specific, part of the story)

### Title Guidelines

- Be specific: "Fixing Pi-hole Cross-VLAN DNS with listeningMode" not "DNS Configuration"
- Include the technology: "Setting up ZHA with Sonoff Dongle" not "Smart Home Setup"
- State what happened: "Migrating from Hue to ZHA" not "Lighting System Changes"

### Word Count

Target 300-800 words. Longer is fine if the story needs it—don't cut interesting details to hit a number. Shorter is fine if that's all there is to say.

---

## Imagery

Posts should have visual elements that draw readers in and break up the text. This isn't decoration—it's communication.

### When to Add Images

**Always add a hero image** for substantive posts (300+ words). Short technical notes can skip imagery.

**Add section break images** when the post has distinct conceptual phases or a key insight that benefits from visualization.

### Image Types

| Type | Purpose | Placement |
|------|---------|-----------|
| Hero | Draw reader into the story, set tone | Immediately after frontmatter, before first heading |
| Section break | Visualize a key concept or transition | Between major sections |
| Reference | Ground metaphors, show source material | Near the reference in text |
| Diagram | Explain technical architecture or flow | Inline where the concept is discussed |

### Check for Existing Assets First

Before creating new images, search for relevant existing diagrams:

```bash
# Check existing blog images
ls ~/2_project-files/projects/active-projects/chungus-blog/static/images/

# Search for mermaid diagrams in related docs
grep -r "```mermaid" ~/2_project-files/projects/active-projects/ --include="*.md" -l

# Search for SVGs in the workspace
find ~/2_project-files -name "*.svg" -type f 2>/dev/null | head -20
```

If you find a relevant existing diagram or image, reference it or adapt it rather than creating from scratch.

### Creating New Images

**Style**: Clean, technical, slightly playful. Think institutional documents with a sense of humor. Avoid:
- Cartoony or clip-art aesthetics
- Overly complex illustrations
- Generic stock imagery vibes

**Format**: SVG preferred (scales cleanly, small file size). Use PNG for photos or complex raster images.

**Storage**: Create a directory matching the post slug:

```bash
IMAGES_DIR=~/2_project-files/projects/active-projects/chungus-blog/static/images
POST_SLUG="${DATE}-${SLUG}"  # e.g., 2026-01-21-ai-audit
mkdir -p "${IMAGES_DIR}/${POST_SLUG}"
```

**Reference in markdown**:
```markdown
![Alt text describing the image](/images/2026-01-21-post-slug/hero.svg)
```

### Hero Image Guidelines

The hero should:
- Capture the essence of the post in one visual
- Work at a glance—reader should "get it" without reading
- Set the emotional tone (frustrated? triumphant? absurd?)

Examples:
- Post about AI self-assessment → Robot inspector examining a Pi with "APPROVED BY MYSELF" stamp
- Post about debugging loops → Visual of the loop with armor accumulating
- Post about migration pain → Before/after showing the mess and the solution

### Section Break Guidelines

Section breaks visualize key concepts. They should:
- Appear at natural story transitions
- Reinforce the metaphor or insight
- Be simpler than the hero (supporting role, not starring)

Don't overdo it—2-4 images total is usually right. More than that and they become noise.

### Quick SVG Patterns

For simple conceptual illustrations, SVGs can be created inline. Common patterns:

**Institutional/certificate style** (good for ironic authority):
- Cream background (#faf8f5)
- Serif fonts for headers, monospace for data
- Red stamp elements (#c41e3a)
- Clean borders and grid patterns

**Technical diagram style** (good for architecture):
- Light gray background (#fafafa)
- Sans-serif labels
- Color-coded boxes for different components
- Connecting lines with arrows

**Metaphor visualization** (good for abstract concepts):
- Simple geometric shapes representing ideas
- Minimal color palette (2-3 colors)
- Small text labels anchoring meaning

---

## Pre-Publish Checks

### Confidentiality Review

Before finalizing, scan the post for client identifiers:
- Project codes (e.g., "101-cal", "fourth-street")
- Building names and addresses
- Company names (unless public/approved)
- MOID numbers or other internal references

If found, ask user: "I found potential client identifiers: [list]. Should I anonymize these before publishing?"

### Tone Review

Check for AI-speak patterns that undermine the human voice:
- Dramatic/punchy openers that feel manufactured
- Marketing-speak ("revolutionary", "game-changing", "seamlessly")
- Superlatives without evidence ("extremely", "incredibly", "amazingly")
- Self-congratulation ("I successfully", "I was able to")

If patterns found, revise before proceeding.

### Mermaid/Diagram Verification

If post contains code blocks with `mermaid`, `flowchart`, `graph`, `sequenceDiagram`, or `stateDiagram`:
1. Verify Hugo's Mermaid.js is configured (check `config.toml` or existing posts)
2. Test render locally if possible
3. Note to user: "Post contains Mermaid diagrams - verify they render after deploy"

---

## Save and Deploy

### File Location

```
~/2_project-files/projects/active-projects/chungus-blog/content/posts/
```

### Filename Generation

```bash
BLOG_DIR=~/2_project-files/projects/active-projects/chungus-blog/content/posts
DATE=$(date +%Y-%m-%d)
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | sed 's/ /-/g' | cut -c1-60)
FILENAME="${DATE}-${SLUG}.md"
FILEPATH="${BLOG_DIR}/${FILENAME}"

# Handle collisions
COUNTER=2
while [[ -f "$FILEPATH" ]]; do
    FILENAME="${DATE}-${SLUG}-${COUNTER}.md"
    FILEPATH="${BLOG_DIR}/${FILENAME}"
    ((COUNTER++))
done

# Use $FILEPATH for saving
```

### Git Commit

Before deploying, commit the new post and any images:

```bash
cd ~/2_project-files/projects/active-projects/chungus-blog
git add content/posts/${FILENAME}
git add static/images/${POST_SLUG}/ 2>/dev/null || true  # Images dir may not exist
git commit -m "Add post: ${TITLE}"
```

### Deployment

After committing, deploy to production:

```bash
cd ~/2_project-files/projects/active-projects/chungus-blog && ./deploy.sh
```

This runs Hugo build and rsyncs to Infrastructure Pi at `/var/www/blog.chughes.co`.

### Verify Deployment

Construct the URL from the saved filename. For `2026-01-17-example-post.md`, the URL is `https://blog.chughes.co/posts/example-post/`.

```bash
# Extract slug from filename (strip date prefix and .md extension)
SLUG=$(basename "$FILEPATH" .md | sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-//')
curl -s -o /dev/null -w "%{http_code}" "https://blog.chughes.co/posts/${SLUG}/"
```

Report the URL to user with success (200) or failure status.

---

## Error Handling

**Before starting:**
- Verify blog directory exists. If missing, create with `mkdir -p ~/2_project-files/projects/active-projects/chungus-blog/content/posts/`

**During deployment:**
- Deploy script fails: File is already saved in content/posts/. Warn user and show saved path. They can run `./deploy.sh` manually later.
- SSH to Infrastructure Pi fails: Same as above. Deployment can wait, post is saved locally.
- Hugo build fails: Report error output. Post is saved but not deployed.

---

## Verification

Before completing, confirm:
- Blog post saved to content/posts/ with correct filename
- Frontmatter has valid date and title
- Confidentiality review passed (no client identifiers)
- Tone review passed (no AI-speak patterns)
- Hero image created and referenced (for posts 300+ words)
- All image files saved to static/images/{post-slug}/
- Mermaid diagrams noted if present
- Git commit created with post and images
- Deploy script ran (or user informed of failure)
- Deployment URL verified or failure reported
- All images return 200 status when fetched
