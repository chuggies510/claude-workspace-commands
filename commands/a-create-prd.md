---
allowed-tools: [Read, Write, Glob, Grep, Bash]
description: Create comprehensive Product Requirement Documents (PRDs) with structured analysis and clarifying questions
thinking: true
---

# /a-create-prd: Product Requirement Document Generator

## Purpose
Generate comprehensive Product Requirement Documents (PRDs) for new features or projects through structured analysis and clarifying questions. Works from any directory and creates PRDs in the appropriate project location.

## Usage
```
/a-create-prd [feature-name] [optional-description]
```

## Process Overview
1. **Feature Analysis**: Understand the requested feature or project
2. **Clarifying Questions**: Ask structured questions to gather requirements
3. **PRD Generation**: Create comprehensive PRD with all sections
4. **File Management**: Save PRD in appropriate project location
5. **Next Steps**: Guide user toward task generation phase

## Implementation

### Step 1: Feature Analysis and Setup
```thinking
I need to:
1. Understand what feature/project the user wants to create a PRD for
2. Determine the current project context (if any)
3. Ask clarifying questions to gather comprehensive requirements
4. Generate a structured PRD document
5. Save it in the appropriate location
```

**Detect Current Project Context**:
```bash
# Check if we're in a project directory
if [ -f "CLAUDE.md" ] || [ -f ".claude/memory-bank/project-brief.md" ]; then
    echo "Project context detected"
    pwd
else
    echo "No project context - will create standalone PRD"
    pwd
fi
```

**Parse User Input**:
- Extract feature name from command arguments
- Extract optional description if provided
- Prompt for basic feature description if not provided

### Step 2: Structured Clarifying Questions

Ask comprehensive questions across these categories:

#### Core Feature Questions
1. **Feature Purpose**: What problem does this feature solve? Who are the target users?
2. **Success Metrics**: How will you measure if this feature is successful?
3. **Scope Boundaries**: What is explicitly IN scope vs OUT of scope?
4. **Priority Level**: Is this a must-have, nice-to-have, or experimental feature?

#### Technical Questions
1. **Platform Requirements**: What platforms/systems must this work on?
2. **Performance Requirements**: Any specific performance, scale, or reliability requirements?
3. **Integration Points**: What existing systems/features must this integrate with?
4. **Data Requirements**: What data does this feature need to access or store?

#### User Experience Questions
1. **User Workflow**: Walk through the complete user journey for this feature
2. **Edge Cases**: What unusual scenarios or error conditions must be handled?
3. **Accessibility**: Any specific accessibility or usability requirements?
4. **Security**: Any security, privacy, or compliance considerations?

#### Business Questions
1. **Timeline**: When does this need to be completed? Any milestone dependencies?
2. **Resources**: What skills, tools, or external dependencies are needed?
3. **Risks**: What could go wrong? What are the biggest risks or unknowns?
4. **Future Evolution**: How might this feature evolve over time?

### Step 3: PRD Document Generation

Create comprehensive PRD with these sections:

```markdown
# PRD: [Feature Name]

## Executive Summary
[2-3 sentence overview of the feature and its value]

## Problem Statement
### Current State
[Description of current situation/problems]

### Desired State
[Description of ideal outcome after feature implementation]

### Success Metrics
- [Measurable metric 1]
- [Measurable metric 2]
- [Measurable metric 3]

## Feature Requirements

### Functional Requirements
1. **[Requirement Category]**
   - [Specific requirement 1]
   - [Specific requirement 2]

### Non-Functional Requirements
- **Performance**: [Performance requirements]
- **Security**: [Security requirements]
- **Accessibility**: [Accessibility requirements]
- **Compatibility**: [Platform/browser requirements]

### User Stories
- As a [user type], I want [capability] so that [benefit]
- As a [user type], I want [capability] so that [benefit]

## Technical Specifications

### System Architecture
[High-level architectural approach]

### Data Model
[Key data structures or database changes]

### API Requirements
[External integrations or API changes needed]

### Security Considerations
[Security analysis and requirements]

## User Experience Design

### User Workflows
1. **[Primary workflow name]**
   - Step 1: [Action]
   - Step 2: [Action]
   - Step 3: [Action]

### Error Handling
- [Error scenario 1]: [How to handle]
- [Error scenario 2]: [How to handle]

### Edge Cases
- [Edge case 1]: [Expected behavior]
- [Edge case 2]: [Expected behavior]

## Implementation Considerations

### Dependencies
- [External dependency 1]
- [Internal dependency 2]

### Risks and Mitigation
- **Risk**: [Description] | **Mitigation**: [Strategy]
- **Risk**: [Description] | **Mitigation**: [Strategy]

### Timeline Estimate
- **Research/Design**: [Time estimate]
- **Implementation**: [Time estimate]
- **Testing/Polish**: [Time estimate]
- **Total**: [Total time estimate]

## Out of Scope
- [Explicitly excluded item 1]
- [Explicitly excluded item 2]

## Future Considerations
- [Future enhancement 1]
- [Future enhancement 2]

## Acceptance Criteria
- [ ] [Testable criterion 1]
- [ ] [Testable criterion 2]
- [ ] [Testable criterion 3]

---
*PRD Created: [Date]*
*Author: Development Team*
*Status: Draft*
```

### Step 4: File Management

**Determine Save Location** (unified dev/ structure):
1. **Project Context**: If in a project with `dev/` folder, save to `dev/planning/prd-[feature-name].md`
2. **Legacy Project**: If project has `tasks/prds/` but no `dev/`, use existing structure
3. **Standalone**: Save to `~/2_project-files/_shared/dev/planning/prd-[feature-name].md`
4. **Create directories if needed**

```bash
# Detect and create appropriate directory
if [ -d "dev" ] || [ -f "CLAUDE.md" ]; then
    mkdir -p dev/planning
    echo "dev/planning/prd-[feature-name].md"
elif [ -d "tasks/prds" ]; then
    echo "tasks/prds/prd-[feature-name].md"  # Legacy support
else
    mkdir -p ~/2_project-files/_shared/dev/planning
    echo "~/2_project-files/_shared/dev/planning/prd-[feature-name].md"
fi
```

**File Naming Convention**:
- Format: `prd-[feature-name-slug].md`
- Example: `prd-user-authentication.md`
- Slug: lowercase, hyphens for spaces, alphanumeric only

**Lifecycle**: PRD stays in `dev/planning/` during active work. After feature completion, move PRD and tasks together to `dev/completed/[feature-name]/`.

### Step 5: Next Steps Guidance

After PRD creation, provide clear next steps:

```markdown
## ✅ PRD Created Successfully

**File Location**: `dev/planning/prd-[feature-name].md`

### Next Steps:
1. **Review PRD**: Review the generated PRD for completeness and accuracy
2. **Stakeholder Review**: Share with stakeholders for feedback and approval
3. **Generate Tasks**: Run `/a-generate-tasks dev/planning/prd-[feature-name].md` to create task list
4. **Begin Implementation**: Use `/a-process-tasks dev/planning/tasks-[feature-name].md` for systematic implementation
5. **After Completion**: Move both PRD and tasks to `dev/completed/[feature-name]/`

### Commands:
```bash
# Generate implementation tasks from this PRD
/a-generate-tasks dev/planning/prd-[feature-name].md

# After task generation, begin implementation
/a-process-tasks dev/planning/tasks-[feature-name].md

# After feature complete, archive to completed
mkdir -p dev/completed/[feature-name]
mv dev/planning/prd-[feature-name].md dev/completed/[feature-name]/
mv dev/planning/tasks-[feature-name].md dev/completed/[feature-name]/
```

**Tip**: The PRD can be edited directly before proceeding to task generation.
```

## Error Handling

### Common Error Scenarios
1. **No Feature Name Provided**: Prompt user for feature name and description
2. **Invalid Directory**: Create necessary directories or guide to valid location
3. **File Already Exists**: Ask user whether to overwrite, append, or use different name
4. **Permission Issues**: Guide user to resolve file permission problems

### Validation Checks
- Ensure feature name is provided and valid
- Verify target directory is writable
- Check for existing PRD files with similar names
- Validate all required sections are completed

## Integration Notes
- Works independently of project Memory Banks
- Compatible with existing `/a-generate-tasks` and `/a-process-tasks` workflow
- Follows established `/a-` command naming convention
- Uses absolute paths for universal directory access