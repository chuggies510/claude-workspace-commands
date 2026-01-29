---
allowed-tools: [Read, Write, Glob, Grep, Bash]
description: Generate comprehensive task lists from PRDs with dependency tracking and phase organization
thinking: true
---

# /a-generate-tasks: Task List Generator from PRDs

## Purpose
Break down Product Requirement Documents (PRDs) into detailed, actionable task lists with dependency tracking, phase organization, and systematic implementation planning.

## Usage
```
/a-generate-tasks [prd-file-path]
/a-generate-tasks [prd-file-path] --phases [number]
```

## Process Overview
1. **PRD Analysis**: Parse and understand the PRD requirements
2. **Phase Planning**: Organize work into logical implementation phases
3. **Task Breakdown**: Generate detailed subtasks with clear acceptance criteria
4. **Dependency Mapping**: Establish task dependencies and sequencing
5. **File Generation**: Create comprehensive task list file with session breaks
6. **User Review**: Present task structure for approval and refinement

**Note**: Each phase ends with a session break marker (🔚) and commit message template. This supports multi-session implementation with clear checkpoints.

## Implementation

### Step 1: PRD Analysis and Validation
```thinking
I need to:
1. Read and parse the provided PRD file
2. Extract key requirements, features, and technical specifications
3. Identify major work areas and complexity levels
4. Plan logical implementation phases
5. Generate detailed tasks with dependencies
6. Create a comprehensive task file for systematic implementation
```

**Validate PRD File**:
```bash
# Check if PRD file exists and is readable
if [ ! -f "$PRD_FILE" ]; then
    echo "Error: PRD file not found: $PRD_FILE"
    exit 1
fi

# Verify PRD file format
grep -q "# PRD:" "$PRD_FILE" || echo "Warning: File may not be a standard PRD format"
```

**Extract PRD Components**:
- Parse feature name and description
- Extract functional and non-functional requirements
- Identify user stories and acceptance criteria
- Note technical specifications and dependencies
- Analyze complexity indicators and risk factors

### Step 2: Phase Planning Strategy

**Default Phase Structure**:
1. **Phase 1: Foundation & Setup** (Infrastructure, core setup, dependencies)
2. **Phase 2: Core Implementation** (Primary functionality, main features)
3. **Phase 3: Integration & Enhancement** (System integration, advanced features)
4. **Phase 4: Testing & Validation** (Testing, edge cases, performance)
5. **Phase 5: Documentation & Polish** (Documentation, cleanup, deployment)

**Custom Phase Planning**:
- Allow user to specify number of phases (3-7 phases recommended)
- Automatically organize tasks based on complexity and dependencies
- Balance phase workload and logical progression

### Step 3: Task Breakdown Methodology

**Task Categories**:
- **Infrastructure**: Setup, configuration, dependencies
- **Core Development**: Primary feature implementation
- **Integration**: System integration and API connections
- **Testing**: Unit tests, integration tests, validation
- **Documentation**: User docs, technical docs, guides
- **Deployment**: Release preparation, deployment scripts

**Task Detail Level**:
- **High-Level Tasks**: Major feature areas (2-8 hours each)
- **Detailed Subtasks**: Specific implementation steps (15 minutes - 2 hours each)
- **Acceptance Criteria**: Clear completion requirements for each task
- **Dependencies**: Explicit task sequencing and prerequisites

### Step 4: Dependency Mapping System

**Dependency Notation**:
```
[depends on: X.Y] - Task depends on completion of task X.Y
[depends on: X.Y, Z.A] - Task depends on multiple tasks
[no dependencies] - Task can be started immediately
[parallel with: X.Y] - Task can run in parallel with task X.Y
```

**Dependency Types**:
- **Sequential**: Task B cannot start until Task A completes
- **Parallel**: Tasks can run simultaneously
- **Conditional**: Task depends on specific outcome of previous task
- **Resource**: Tasks share resources and cannot run simultaneously

### Step 5: Task File Generation

**File Naming Convention**:
- Location: Same directory as PRD file
- Format: `tasks-[prd-name].md`
- Example: `tasks-prd-user-authentication.md`

**Task File Structure**:
```markdown
# Implementation Tasks: [Feature Name]

## Source PRD
**File**: `[path-to-prd-file]`
**Generated**: [date and time]
**Total Tasks**: [number] tasks across [number] phases

## Phase Overview & Session Breaks
- **Phase 1**: [Name] ([X] tasks, ~[Y] hours) → **SESSION 1 END** (commit after [last-task])
- **Phase 2**: [Name] ([X] tasks, ~[Y] hours) → **SESSION 2 END** (commit after [last-task])
- **Phase 3**: [Name] ([X] tasks, ~[Y] hours) → **SESSION 3 END** (commit after [last-task])
- **Phase 4**: [Name] ([X] tasks, ~[Y] hours) → **SESSION 4 END** (commit after [last-task])
- **Phase 5**: [Name] ([X] tasks, ~[Y] hours) → **SESSION 5 END** (commit after [last-task], RELEASE)

**Total Estimated Time**: ~[X] hours across [Y] sessions

## Dependencies Map
```
Phase 1: 1.1 → 1.2 → 1.3 ← 1.4
         ↓       ↓     ↓
Phase 2: 2.1 → 2.2 → 2.3
         ↓             ↓
Phase 3: 3.1 -----→ 3.2
```

## Task Breakdown

### Phase 1: [Phase Name] ([X] tasks)
**Objective**: [Phase description and goals]
**Dependencies**: [Any external dependencies]
**Estimated Time**: ~[X] hours

- [ ] 1.1 [Task name]
  - **Description**: [Detailed task description]
  - **Acceptance Criteria**:
    - [ ] [Specific criterion 1]
    - [ ] [Specific criterion 2]
  - **Dependencies**: [no dependencies]
  - **Estimated Time**: [X] hours
  - **Notes**: [Any additional context]

- [ ] 1.2 [Task name]
  - **Description**: [Detailed task description]
  - **Acceptance Criteria**:
    - [ ] [Specific criterion 1]
    - [ ] [Specific criterion 2]
  - **Dependencies**: [depends on: 1.1]
  - **Estimated Time**: [X] hours

**🔚 SESSION 1 END**: Commit Phase 1 completion - "feat([feature]): Phase 1 - [phase name] complete"

---

### Phase 2: [Phase Name] ([X] tasks)
[Repeat structure for each phase]

**🔚 SESSION 2 END**: Commit Phase 2 completion - "feat([feature]): Phase 2 - [phase name] complete"

---

## Parallel Execution Opportunities
**Independent Task Groups** (can run in parallel):
- Group A: Tasks 1.1, 1.3, 2.2 (no shared dependencies)
- Group B: Tasks 1.4, 2.1, 3.1 (no shared dependencies)
- Group C: Tasks 2.3, 3.2 (can run after Phase 1 completion)

## Risk Assessment
**High-Risk Tasks** (may require additional planning):
- Task X.Y: [Risk description and mitigation strategy]
- Task Z.A: [Risk description and mitigation strategy]

**Critical Path** (tasks that cannot be delayed):
Path: 1.1 → 1.2 → 2.1 → 2.3 → 3.2 → 4.1 → 5.1

## Quality Gates
**Phase Completion Criteria**:
- **Phase 1**: [All infrastructure tasks complete and tested]
- **Phase 2**: [Core functionality working and demonstrated]
- **Phase 3**: [Integration complete and edge cases handled]
- **Phase 4**: [All tests passing and performance validated]
- **Phase 5**: [Documentation complete and feature deployed]

## Next Steps
1. **Review Tasks**: Review generated task list for completeness
2. **Modify if Needed**: Edit tasks, add details, adjust phases
3. **Begin Implementation**: Run `/a-process-tasks [this-file]` to start systematic implementation
4. **Track Progress**: Use task checkboxes to track completion
5. **Session Management**: Commit after each phase completion (session breaks marked with 🔚)
6. **After Completion**: Move PRD + tasks to `dev/completed/[feature-name]/`

---
*Tasks Generated: [Date]*
*Based on PRD: [PRD filename]*
*Ready for /a-process-tasks implementation*
```

### Step 6: User Review and Refinement

**Present Task Summary**:
```markdown
## 📋 Task Generation Complete

**Source PRD**: `[prd-file-path]`
**Task File**: `[task-file-path]`
**Total Tasks**: [X] tasks across [Y] phases
**Estimated Time**: ~[Z] hours

### Phase Breakdown:
1. **[Phase 1 Name]**: [X] tasks (~[Y] hours)
2. **[Phase 2 Name]**: [X] tasks (~[Y] hours)
3. **[Phase 3 Name]**: [X] tasks (~[Y] hours)
4. **[Phase 4 Name]**: [X] tasks (~[Y] hours)
5. **[Phase 5 Name]**: [X] tasks (~[Y] hours)

### Ready for Implementation:
```bash
# Begin systematic task implementation
/a-process-tasks [task-file-path]

# Or review/edit the task file first
```

**Modification Options**:
- Edit task file directly before implementation
- Regenerate with different phase count
- Add custom tasks or modify acceptance criteria
- Adjust time estimates based on team capacity
```

## Advanced Features

### Smart Task Generation
**Complexity Analysis**:
- Parse PRD for complexity indicators (new technology, integrations, performance requirements)
- Adjust task granularity based on complexity level
- Add extra testing/validation tasks for high-risk areas

**Dependency Detection**:
- Automatically identify dependencies from PRD requirements
- Suggest parallel execution opportunities
- Highlight critical path tasks that cannot be delayed

### Integration Intelligence
**Project Context Awareness**:
- Detect existing project patterns and follow established conventions
- Suggest integration points with existing systems
- Recommend code patterns based on project architecture

## Error Handling

### Common Error Scenarios
1. **PRD File Not Found**: Guide user to correct file path or generate PRD first
2. **Invalid PRD Format**: Parse what's available and warn about missing sections
3. **Empty or Minimal PRD**: Generate basic task structure and prompt for more detail
4. **Permission Issues**: Guide user to resolve file access problems

### Validation Checks
- Verify PRD file exists and is readable
- Check for required PRD sections (requirements, specifications)
- Validate task file output location is writable
- Ensure task dependencies are logical and don't create cycles

## Integration Notes
- Works with PRDs created by `/a-create-prd` or manual PRDs
- Output compatible with `/a-process-tasks` for systematic implementation
- Follows established project task patterns (like blog system implementation)
- Uses absolute paths for universal directory access
- Maintains task completion state for progress tracking