# Claude Code Project Context

## Project Overview
AI Finance Control — Goal-Oriented Multi-Agent Finance Planning System using rcrewai. Three phases: Planning → Execution → Monitoring.

## Architecture & Flow
- **Controller** → `button_to "Create Plan with AI"` triggers route
- **Route** → POST to `create_plan_goal_path(@goal)` or `create_plan_financial_goal_path(@goal)`
- **Controller Action** → Enqueues `AgentPlanningJob.perform_later(@goal.id)`
- **Background Job** → Calls `AgentPlanningService` via Solid Queue
- **Service** → Calls rcrewai `PlannerAgent` with OpenAI GPT-4
- **Agent** → Analyzes goal, returns structured plan JSON
- **Service** → Converts plan into `Milestone` records (1-5 phases)
- **Database** → Stores milestones with `target_amount`, `phase`, `status`
- **View** → Displays plan status (✅ Plan Created or ⏳ Awaiting Plan) and milestones

## Key Files
- `app/controllers/goals_controller.rb` — CRUD + `create_plan` action
- `app/controllers/financial_goals_controller.rb` — Same as above for financial goals
- `app/services/agent_planning_service.rb` — Calls PlannerAgent, creates milestones
- `app/jobs/agent_planning_job.rb` — Solid Queue async job
- `app/views/goals/show.html.erb` — Displays goal with plan status + milestones
- `app/views/financial_goals/show.html.erb` — Same for financial goals
- `config/routes.rb` — Member routes for `post :create_plan`

## Styling & UI
- **Aesthetic**: Discord dark theme (zinc/slate colors)
- **Framework**: Tailwind CSS (imported via importmap)
- **Components**: Stimulus components for interactivity (no Turbo real-time yet)
- **Sections**: Current State, Goal State, Milestones, Detailed Plan

## rcrewai Integration
- **PlannerAgent**: Analyzes financial goal, creates structured plan with phases
- **ExecutorAgent**: Takes milestone, creates action plan (not yet integrated)
- **MonitorAgent**: Future — will track progress and send updates
- **Crews**: Each agent orchestrated as an RCrewAI::Crew with tasks and tools
- **Tasks**: Structured prompts for agents (e.g., "Analyze goal and create phases")
- **Tools**: Future — integrate real bank APIs, investment data

## Database & Persistence
- **Goals** table: `name`, `target_amount`, `target_date`, `priority`, `status`, `plan` (JSONB)
- **Milestones** table: `goal_id`, `phase`, `target_amount`, `order_number`, `status`, `current_amount`, `progress_percentage`
- **AgentSessions** table: Logs all agent interactions for auditoria
- **AgentMessages** table: Stores conversation history between agents and AI

## State Management
- Goals: `planned`, `in_progress`, `completed`
- Milestones: `pending`, `in_progress`, `completed`
- AgentSessions: `idle`, `processing`, `completed`, `failed` (AASM)

## Development Notes
- Restart Rails server after creating new view templates
- Route helpers use Rails conventions: `create_plan_goal_path(@goal)` not `goal_create_plan_path`
- Plan stored as JSONB — use `JSON.pretty_generate()` to display
- Milestone creation divides target evenly: `milestone.target_amount = goal.target_amount / num_phases`

## Testing the Flow
1. Create a financial goal via `/goals/new` or `/financial_goals/new`
2. AgentPlanningJob enqueues automatically after save
3. Check if milestones were created (view milestone count badge)
4. If no plan yet, click "Create Plan with AI" button manually
5. Refresh to see plan status update and milestones appear
6. Each milestone shows phase name, target amount, progress bar, Execute button

## User Preferences
- Portuguese documentation preferred for context/flow
- Discord dark aesthetic for styling
- Clear visual indicators for goal state (Current → Goal → Milestones progression)
- No real-time Turbo updates (async jobs + manual refresh OK for now)
