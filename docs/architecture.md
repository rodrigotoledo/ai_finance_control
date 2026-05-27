# System Architecture

## High-Level Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER INTERFACE                            │
│                 (Tailwind CSS + Stimulus)                       │
└──┬──────────────────────────────────────────────────────────────┘
   │
   ├─ POST /goals → GoalsController#create
   ├─ GET  /goals/:id → GoalsController#show
   ├─ POST /goals/:id/create_plan → GoalsController#create_plan
   └─ POST /goals/:id/execute_milestone → GoalsController#execute_milestone
   
   ├─ POST /financial_goals → FinancialGoalsController#create
   ├─ GET  /financial_goals/:id → FinancialGoalsController#show
   └─ POST /financial_goals/:id/create_plan → FinancialGoalsController#create_plan
```

## Request Flow: Goal Creation

```
1. User submits goal form
   ↓
2. GoalsController#create
   - Validates params with goal_params whitelist
   - Creates Goal record (name, target_amount, target_date, priority, status)
   - Saves to database
   ↓
3. AgentPlanningJob.perform_later(@goal.id)
   - Enqueues async job to Solid Queue
   - Job processes in background (not blocking response)
   ↓
4. AgentPlanningJob executes (via Solid Queue worker)
   - Calls AgentPlanningService.call(goal)
   ↓
5. AgentPlanningService#call
   - Builds prompt from goal data
   - Calls rcrewai PlannerAgent crew
   ↓
6. PlannerAgent (rcrewai crew)
   - Agent: PlannerAgent (role: "Financial Planner")
   - Task: Analyze goal + create phases
   - LLM: OpenAI GPT-4
   - Output: Structured JSON plan
   {
     "phases": [
       {"name": "Initial Foundation", "target_amount": 5000},
       {"name": "Building Momentum", "target_amount": 5000},
       {"name": "Final Push", "target_amount": 5000}
     ]
   }
   ↓
7. AgentPlanningService#create_milestones_from_context
   - Parses agent response
   - Creates Milestone records (1-5 phases)
   - Each milestone: target_amount, phase name, order_number, status='pending'
   - Stores plan JSON in goal.plan (JSONB column)
   ↓
8. View renders
   - GET /goals/:id → GoalsController#show
   - Sets @goal, @milestones, @progress_percentage
   - Renders goals/show.html.erb
   - Displays: Plan status badge + Milestone list + Progress bar
```

## Request Flow: Manual Plan Trigger

```
1. User on /goals/:id sees "⏳ Awaiting Plan" badge
2. Clicks "Create Plan with AI" button
   ↓
3. POST /goals/:id/create_plan → GoalsController#create_plan
   - Checks if goal.plan.blank? (if plan exists, redirect with alert)
   - Enqueues AgentPlanningJob.perform_later(@goal.id)
   - Redirects with notice message
   ↓
4. [Same flow as Goal Creation, steps 4-8]
```

## Request Flow: Execute Milestone

```
1. User on /goals/:id sees pending milestone
2. Clicks "Execute Milestone" button
   ↓
3. POST /goals/:id/execute_milestone
   - Finds milestone by params[:milestone_id]
   - Checks milestone.pending? status
   - Enqueues ExecutorAgentJob.perform_later(milestone.id)
   ↓
4. ExecutorAgentJob executes (via Solid Queue worker)
   - Calls ExecutorAgentService.call(milestone)
   ↓
5. ExecutorAgentService#call
   - Builds prompt from milestone data (phase name, target amount, user's current savings)
   - Calls rcrewai ExecutorAgent crew
   ↓
6. ExecutorAgent (rcrewai crew)
   - Agent: ExecutorAgent (role: "Financial Executor")
   - Task: Create action plan for milestone
   - LLM: OpenAI GPT-4
   - Output: Structured action plan JSON
   ↓
7. ExecutorAgentService#update_milestone
   - Updates milestone.status = 'in_progress'
   - Stores action plan in milestone metadata
   ↓
8. View renders
   - GET /goals/:id refreshes
   - Milestone now shows status "In Progress"
   - Button changes to "In Progress" badge
```

## Data Model

```
┌─────────────────────────────────┐
│          USER (Devise)          │
├─────────────────────────────────┤
│ id, email, password_digest      │
│ current_savings (decimal)       │
│ monthly_income (decimal)        │
└────────┬────────────────────────┘
         │ has_many
         ↓
┌─────────────────────────────────┐
│          GOAL                   │
├─────────────────────────────────┤
│ id, user_id                     │
│ name (string)                   │
│ target_amount (decimal)         │
│ target_date (datetime)          │
│ priority (integer 1-5)          │
│ status (planned/in_progress...) │
│ plan (jsonb)                    │  ← Stores PlannerAgent output
│ created_at, updated_at          │
└────────┬────────────────────────┘
         │ has_many
         ↓
┌─────────────────────────────────┐
│        MILESTONE                │
├─────────────────────────────────┤
│ id, goal_id                     │
│ phase (string)                  │
│ target_amount (decimal)         │
│ order_number (integer)          │
│ status (pending/in_progress...) │
│ current_amount (decimal)        │
│ progress_percentage (computed)  │
│ completion_percentage (display) │
│ created_at, updated_at          │
└─────────────────────────────────┘
```

## Agent Sessions (Auditoria)

```
┌──────────────────────────────────┐
│      AGENT_SESSION (AASM)        │
├──────────────────────────────────┤
│ id, user_id                      │
│ agent_type (PlannerAgent, etc.)  │
│ goal_id (nullable)               │
│ milestone_id (nullable)          │
│ state (idle→processing→complete) │
│ input_data (jsonb)               │
│ output_data (jsonb)              │
│ error_message (text, if failed)  │
│ created_at, updated_at           │
└──────────┬───────────────────────┘
           │ has_many
           ↓
┌──────────────────────────────────┐
│      AGENT_MESSAGE               │
├──────────────────────────────────┤
│ id, agent_session_id             │
│ role (user/assistant)            │
│ content (text)                   │
│ created_at                       │
└──────────────────────────────────┘
```

## Background Job Processing (Solid Queue)

```
┌──────────────────────┐
│   USER ACTION        │  POST /goals/:id/create_plan
│   in Browser         │
└──────┬───────────────┘
       │
       ↓
┌──────────────────────┐
│   CONTROLLER         │  GoalsController#create_plan
│   (Synchronous)      │  - Validates
│                      │  - Enqueues job
│                      │  - Returns immediately (redirect)
└──────┬───────────────┘
       │
       ↓
┌──────────────────────────────────┐
│   SOLID QUEUE                    │  Job persisted in DB
│   (Job Storage)                  │
└──────┬───────────────────────────┘
       │
       ↓
┌──────────────────────────────────┐
│   SOLID QUEUE WORKER             │  Processes async
│   (Background Process)           │  - Fetches AgentPlanningJob
│                                  │  - Calls AgentPlanningService
│                                  │  - Updates Goal + Milestones
│                                  │  - Logs to AgentSession
└──────────────────────────────────┘
       │
       ↓
┌──────────────────────────────────┐
│   USER REFRESH                   │  GET /goals/:id
│   (Manual in Browser)            │  Sees updated milestones
│                                  │  Plan status badge changes
└──────────────────────────────────┘
```

## Service Layer

```
AgentPlanningService
├─ call(goal)
│  ├─ Build prompt from goal attributes
│  ├─ Call PlannerAgent.run(prompt)
│  ├─ Parse JSON response
│  └─ create_milestones_from_context(plan_data)
│     ├─ Determine num_phases (1-5)
│     ├─ Create Milestone for each phase
│     └─ Set target_amount = goal.target_amount / num_phases
└─ Store plan in goal.plan JSONB

ExecutorAgentService (In Progress)
├─ call(milestone)
│  ├─ Build prompt from milestone attributes
│  ├─ Call ExecutorAgent.run(prompt)
│  ├─ Parse JSON response
│  └─ update_milestone(action_plan)
│     └─ Change status to 'in_progress'
└─ Store action plan in milestone metadata

MonitorAgentService (Future)
├─ call(goal)
│  ├─ Fetch all milestones
│  ├─ Call MonitorAgent.run(goal_state)
│  ├─ Parse recommendations
│  └─ Send notifications
```

## View Rendering Pipeline

```
1. User navigates to /goals/:id
   ↓
2. GoalsController#show
   - @goal = current_user.financial_goals.find(params[:id])
   - @milestones = @goal.milestones.ordered
   - @progress_percentage = calculate_goal_progress
   ↓
3. goals/show.html.erb renders
   ├─ Goal header (name, target_date, plan status badge)
   ├─ Current State section (savings, income, months remaining)
   ├─ Goal State section (target amount, progress bar)
   ├─ Milestones section
   │  ├─ If milestones.any?
   │  │  └─ Iterate @milestones.each
   │  │     ├─ Phase number + name
   │  │     ├─ Status badge
   │  │     ├─ Target amount + current progress
   │  │     ├─ Progress bar
   │  │     └─ Execute button (if pending)
   │  └─ Else: "No milestones created yet"
   └─ Detailed Plan section (if goal.plan.present?)
      └─ JSON.pretty_generate(goal.plan)
```

## Styling Strategy

- **Theme**: Discord dark mode (zinc color palette)
- **Framework**: Tailwind CSS (utility-first, no component library)
- **Colors**:
  - Background: `bg-zinc-900` (darkest)
  - Cards: `bg-zinc-800`
  - Borders: `border-zinc-700`
  - Text primary: `text-white`
  - Text secondary: `text-zinc-400`
  - Accents: `text-indigo-600` (primary), `text-emerald-600` (success), `text-rose-600` (danger)
- **Responsive**: Mobile-first (`md:` and `lg:` breakpoints)
- **Components**: Stimulus controllers for form interactions

## Error Handling

- **Controller level**: Validate params, rescue exceptions, redirect with alert
- **Service level**: Catch API errors, raise custom exceptions, log to AgentSession
- **View level**: Conditional rendering (if plan.present?, if milestones.any?)
- **Background job**: Retry logic via Solid Queue, store error_message in AgentSession

## Testing Strategy

1. **Unit**: Test models (Goal validations, Milestone calculations)
2. **Integration**: Test AgentPlanningService with mock responses
3. **Feature**: Manual browser testing (create goal, verify milestones appear, click Execute)
4. **Background jobs**: Check Solid Queue worker logs, verify database updates

## Deployment

- **Database**: PostgreSQL with JSONB support
- **Queue**: Solid Queue (persisted in database)
- **LLM**: OpenAI API (GPT-4, requires OPENAI_API_KEY env var)
- **Hosting**: Rails server (Puma) + background worker (Solid Queue)
