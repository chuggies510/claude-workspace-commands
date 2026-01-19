# MEAP - Modular Engineering Analysis Platform

## Command: meap
## Version: v1.2.0 (see /mnt/NFSS/2_project-files/projects/active-projects/meap-cli-cc/VERSION.md)

When a user types "meap" or "/meap", display this message and handle their requests based on current directory context.

### Context Detection
First, check the current working directory to determine appropriate actions:
1. If in `/mnt/NFSS/2_project-files` or subdirectories (but NOT in a specific project): Show main menu
2. If inside a `client-projects/[project-name]` directory: Auto-continue that project's workflow
3. If in any other location: Show guidance to navigate to project-files

### Welcome Message (Context-Aware)

#### From project-files directory:
```
MEAP - Modular Engineering Analysis Platform v1.2.0

📍 Current location: Project Files Directory

You can:
- "Start a new MEP assessment for [building name]" 
- "Show my MEP projects"
- "meap new [project-name]" - Start new assessment
- "meap list" - Show all projects

After creating a project, you'll need to:
1. Exit Claude (type /exit)
2. Navigate to: cd projects/client-projects/[your-project-name]
3. Run claude again
4. Type /meap to continue the workflow
```

#### From inside a project directory:
```
Welcome to MEAP - Continuing [project-name] Assessment

📍 Current project: [project-name]
📊 Current stage: [workflow-stage]

Continue MEP workflow from current stage.
Type "continue" or describe next action.
```

#### From other locations:
```
MEAP - Modular Engineering Analysis Platform

⚠️ You're not in the MEAP workspace.
Please navigate to the project files directory:

cd /mnt/NFSS/2_project-files
claude
/meap

Or go directly to an existing project:
cd /mnt/NFSS/2_project-files/projects/client-projects/[project-name]
claude
/meap
```

### Natural Language Handlers

#### When in project-files directory:
- "Start a new MEP assessment for [building]" → Execute start_new command
- "Show my MEP projects" → List projects in client-projects
- "meap new [name]" → Execute start_new command
- "meap list" → List active projects

#### When inside a project:
- "continue" → Execute continue_workflow for current project
- "status" → Show current workflow stage and next steps
- "meap continue" → Execute continue_workflow for current project
- Any workflow-related request → Continue from current stage

### Implementation Details
- Start new: Read `/mnt/NFSS/2_project-files/projects/active-projects/meap-cli-cc/src/commands/start_new.md`
- Continue: Read `/mnt/NFSS/2_project-files/projects/active-projects/meap-cli-cc/src/commands/continue_workflow.md`
- List: Show directories in `/mnt/NFSS/2_project-files/projects/client-projects/`
- Status: Read project's `config/workflow-state.yaml` to show current progress

### Project Detection
When /meap is run, check:
1. Is current path inside `/mnt/NFSS/2_project-files/projects/client-projects/*`?
   - YES: Extract project name from path, show project-specific menu
   - NO: Show general MEAP menu

### Project Locations
- All projects created in: `/mnt/NFSS/2_project-files/projects/client-projects/`
- Each project has: `config/`, `inputs/`, `processing/`, `outputs/`, `logs/`
- Workflow state tracked in: `[project]/config/workflow-state.yaml`