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
3. Save to Hugo content directory, build, deploy to blog.chughes.co

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

### Blog Template

Generate the current date with `date +%Y-%m-%d`. Use this structure as a starting point, but let the story dictate the sections:

```markdown
---
title: "[Specific, descriptive title]"
date: [YYYY-MM-DD from date command]
draft: false
tags: ["tag1", "tag2"]
---

## [Opening that establishes the problem or situation]

[Start with the frustration, the goal, or the trigger. What made you do this?]

## [Sections that follow the story naturally]

[What happened, what you tried, what worked, what didn't.
Use headers that describe what's in the section, not generic labels.
"The DIY Detour" is better than "Approach 1".
"Where Things Broke" is better than "Issues Encountered".]

## [Ending that lands somewhere]

[What's different now. What you'd tell someone else. A reaction, not a summary.]
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

### Deployment

After saving the file, deploy to production:

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
- Deploy script ran (or user informed of failure)
- Deployment URL verified or failure reported
