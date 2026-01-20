---
allowed-tools: [Read, Write, Edit, MultiEdit, Glob, Grep, Bash, Task, TodoWrite]
description: Systematically implement tasks from task files with dependency tracking and user approval
thinking: true
---

# /a-process-tasks: Systematic Task Implementation Engine

## Purpose
Execute task lists systematically with dependency tracking, parallel execution optimization, and user approval workflow. Implements tasks one-by-one or in parallel groups while maintaining progress tracking and quality control.

## Usage
```
/a-process-tasks [task-file-path]
/a-process-tasks [task-file-path] --parallel
/a-process-tasks [task-file-path] --resume [task-id]
/a-process-tasks [task-file-path] --status
```

## Process Overview
1. **Task File Analysis**: Parse task file and build dependency graph
2. **Execution Planning**: Identify ready tasks and parallel opportunities
3. **Task Implementation**: Execute tasks individually with user approval
4. **Progress Tracking**: Update task completion status in real-time
5. **Quality Control**: Verify task completion before proceeding
6. **Workflow Management**: Handle errors, retries, and workflow continuation

## Implementation

### Step 1: Task File Analysis and Validation
```thinking
I need to:
1. Parse the task file and extract all tasks with their dependencies
2. Build a dependency graph to understand execution order
3. Identify which tasks are ready to execute (no pending dependencies)
4. Plan execution strategy (sequential vs parallel)
5. Execute tasks systematically with user approval
6. Update task completion status and track progress
7. Handle errors and provide workflow continuation options
```

**Validate Task File**:
```bash
# Check if task file exists and is readable
if [ ! -f "$TASK_FILE" ]; then
    echo "Error: Task file not found: $TASK_FILE"
    echo "Generate tasks first: /a-generate-tasks [prd-file]"
    exit 1
fi

# Verify task file format
grep -q "# Implementation Tasks:" "$TASK_FILE" || echo "Warning: File may not be a standard task file format"
```

**Parse Task Structure**:
- Extract all tasks with IDs (1.1, 1.2, 2.1, etc.)
- Parse dependencies for each task
- Identify task status ([ ], [x], [pending], etc.)
- Build dependency graph for execution planning
- Calculate completion statistics

### Step 2: Dependency Graph and Execution Planning

**Dependency Analysis**:
```
Task Dependency Types:
- [no dependencies] - Can execute immediately
- [depends on: X.Y] - Must wait for task X.Y completion
- [depends on: X.Y, Z.A] - Must wait for multiple tasks
- [parallel with: X.Y] - Can run simultaneously with task X.Y
```

**Ready Task Identification**:
- Tasks with no dependencies
- Tasks whose dependencies are all complete
- Tasks that can run in parallel with currently executing tasks

**Execution Strategy**:
- **Sequential Mode**: Execute one task at a time (default, safer)
- **Parallel Mode**: Execute independent tasks simultaneously
- **Mixed Mode**: Use parallel for safe tasks, sequential for complex ones

### Step 3: Task Implementation Workflow

**Task Execution Process**:
1. **Select Next Task**: Choose ready task based on dependencies
2. **Display Task Details**: Show task description and acceptance criteria
3. **User Approval**: Confirm task implementation should proceed
4. **Execute Task**: Implement the task using available tools
5. **Verify Completion**: Check acceptance criteria fulfillment
6. **Update Status**: Mark task complete and update file
7. **Continue**: Move to next ready task

**Task Selection Algorithm**:
```
Priority Order:
1. Tasks blocking other tasks (on critical path)
2. Tasks with highest dependency fan-out
3. Tasks in earliest phase
4. Tasks with shortest estimated time
5. Tasks in original sequence order
```

### Step 4: Task Implementation Engine

**Individual Task Execution**:
```markdown
## 🔄 Executing Task [X.Y]: [Task Name]

**Description**: [Task description from file]

**Acceptance Criteria**:
- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

**Dependencies**: [dependency status]
**Estimated Time**: [X] hours
**Phase**: [Phase name]

---

### Implementation:
[Actual implementation work happens here using available tools]

### Verification:
[Check each acceptance criterion]
✅ [Criterion 1] - Completed
✅ [Criterion 2] - Completed
✅ [Criterion 3] - Completed

### Result:
Task [X.Y] completed successfully.
```

**Parallel Execution Management**:
When `--parallel` mode is enabled:
- Identify groups of independent tasks
- Execute multiple tasks simultaneously using Task tool
- Coordinate completion and status updates
- Handle parallel task failures gracefully

### Step 5: Progress Tracking and Status Updates

**Real-time Progress Display**:
```markdown
## 📊 Implementation Progress

**Overall**: [X]/[Y] tasks complete ([Z]%)
**Current Phase**: Phase [N] - [Phase Name]
**Phase Progress**: [A]/[B] tasks complete ([C]%)

### Phase Status:
✅ **Phase 1**: [Phase Name] (5/5 complete)
🔄 **Phase 2**: [Phase Name] (3/7 in progress)
⏳ **Phase 3**: [Phase Name] (0/6 pending)
⏳ **Phase 4**: [Phase Name] (0/4 pending)
⏳ **Phase 5**: [Phase Name] (0/3 pending)

### Current Ready Tasks:
- [ ] 2.4 [Task name] [no dependencies]
- [ ] 2.5 [Task name] [depends on: 2.3] ✅
- [ ] 3.1 [Task name] [depends on: 2.x] ⏳

### Recently Completed:
- [x] 2.3 [Task name] ✅ (just completed)
- [x] 2.2 [Task name] ✅
- [x] 2.1 [Task name] ✅
```

**Task File Updates**:
- Mark completed tasks with `[x]`
- Add completion timestamps
- Update progress statistics
- Maintain detailed completion log

### Step 6: Error Handling and Recovery

**Error Scenarios**:
1. **Task Implementation Failure**: Offer retry, skip, or abort options
2. **Acceptance Criteria Not Met**: Allow rework or mark as blocked
3. **Dependency Issues**: Resolve dependency conflicts or mark tasks as blocked
4. **Tool Failures**: Provide fallback options or manual completion
5. **User Cancellation**: Save progress and provide resume options

**Recovery Options**:
```markdown
## ⚠️ Task Implementation Issue

**Task**: [X.Y] [Task name]
**Issue**: [Description of problem]

### Options:
1. **Retry**: Attempt task implementation again
2. **Manual**: Mark as complete (you handled it manually)
3. **Skip**: Skip this task for now (mark as blocked)
4. **Abort**: Stop implementation and save progress
5. **Help**: Get suggestions for resolving the issue

### Resume Command:
```bash
# Resume from where you left off
/a-process-tasks [task-file] --resume [X.Y]
```
```

### Step 7: Workflow Management Features

**Resume Capability**:
- Save execution state after each task
- Allow resuming from specific task ID
- Preserve parallel execution context
- Handle partially completed phases

**Status Reporting**:
```markdown
## 📈 Implementation Status Report

**File**: `[task-file-path]`
**Started**: [timestamp]
**Last Update**: [timestamp]
**Total Runtime**: [duration]

### Completion Stats:
- **Total Tasks**: [X] tasks
- **Completed**: [Y] tasks ([Z]%)
- **In Progress**: [A] tasks
- **Blocked**: [B] tasks
- **Remaining**: [C] tasks

### Phase Breakdown:
| Phase | Name | Tasks | Complete | Progress |
|-------|------|-------|----------|----------|
| 1 | [Name] | 5 | 5 | 100% ✅ |
| 2 | [Name] | 7 | 3 | 43% 🔄 |
| 3 | [Name] | 6 | 0 | 0% ⏳ |

### Next Ready Tasks:
1. [Task ID] [Task name] - [Phase]
2. [Task ID] [Task name] - [Phase]

### Estimated Completion:
- **Remaining Time**: ~[X] hours
- **Current Pace**: [Y] tasks/hour
- **Projected Completion**: [date/time]
```

**Quality Control Features**:
- Automatic verification of acceptance criteria
- User confirmation for complex tasks
- Quality gates between phases
- Rollback capability for failed implementations

## Advanced Features

### Parallel Execution Engine
**Smart Parallelization**:
- Analyze task dependencies to identify safe parallel groups
- Use Task tool for concurrent execution of independent tasks
- Monitor resource usage and adjust parallelization
- Handle parallel task failures without affecting others

**Parallel Group Examples**:
```
Group A (can run together): 1.1, 1.3, 2.1
Group B (depends on Group A): 1.2, 2.2, 2.3
Group C (depends on Groups A+B): 3.1, 3.2
```

### Intelligent Task Execution
**Context-Aware Implementation**:
- Detect project patterns and follow established conventions
- Use appropriate tools based on task type (code, docs, config)
- Apply project-specific quality standards
- Integrate with existing development workflows

**Adaptive Execution**:
- Learn from task completion patterns
- Adjust time estimates based on actual completion times
- Suggest workflow improvements
- Optimize task sequencing for efficiency

### Integration Intelligence
**TodoWrite Integration**:
- Automatically create TodoWrite tracking for complex tasks
- Break down large tasks into sub-todos when helpful
- Maintain high-level progress visibility
- Coordinate with existing todo workflows

**Tool Selection Logic**:
- Choose optimal tools based on task requirements
- Prefer MultiEdit for multiple file changes
- Use Task tool for complex sub-workflows
- Leverage Bash for system operations

## Command Line Options

### Basic Usage
```bash
# Standard sequential execution
/a-process-tasks tasks/tasks-prd-feature.md

# Parallel execution mode
/a-process-tasks tasks/tasks-prd-feature.md --parallel

# Resume from specific task
/a-process-tasks tasks/tasks-prd-feature.md --resume 2.3

# Check status without execution
/a-process-tasks tasks/tasks-prd-feature.md --status
```

### Advanced Options
```bash
# Dry run (show execution plan without implementing)
/a-process-tasks tasks/tasks-prd-feature.md --dry-run

# Execute specific phase only
/a-process-tasks tasks/tasks-prd-feature.md --phase 2

# Automatic mode (minimal user intervention)
/a-process-tasks tasks/tasks-prd-feature.md --auto

# Quality gates only (verify completed tasks)
/a-process-tasks tasks/tasks-prd-feature.md --verify
```

## Error Handling

### Common Error Scenarios
1. **Task File Not Found**: Guide user to generate tasks or provide correct path
2. **Malformed Task File**: Parse what's available and report issues
3. **Circular Dependencies**: Detect and report dependency cycles
4. **Tool Failures**: Provide fallback options and manual completion paths
5. **User Interruption**: Save state and provide clean resume options

### Validation Checks
- Verify task file format and structure
- Check for circular dependencies
- Validate all dependencies reference existing tasks
- Ensure required tools are available
- Check file permissions for updates

## Integration Notes
- Works with task files generated by `/a-generate-tasks`
- Compatible with manually created task files following the standard format
- Integrates with TodoWrite for high-level progress tracking
- Uses all available Claude Code tools for task implementation
- Maintains detailed audit trail of all implementations
- Supports both project-specific and standalone task execution