# Claude Code Project Context

## Project Overview
AI Finance Control — Goal-Oriented Multi-Agent Finance Planning System using rcrewai. Three phases: Planning → Execution → Monitoring. User can set financial goals, receive AI-generated plans with detailed phases, and track milestone progress.

## Architecture & Flow

### Planning Phase (✅ Implemented)
1. **User** → Creates goal via `/goals/new` or `/financial_goals/new`
2. **Controller** → Validates goal, saves to database
3. **AgentPlanningJob** → Enqueues automatically (Solid Queue)
4. **AgentPlanningService** → Calls PlannerAgent with detailed goal context
5. **PlannerAgent** → Analyzes goal using rcrewai + OpenAI GPT-4, returns structured JSON
6. **Service** → Parses phase details (description, key_actions, timeline, monthly_contribution, focus)
7. **Milestones** → Creates 1-5 milestone records with rich details in JSON field
8. **View** → Displays goal with plan status (✅ Plan Created or ⏳ Awaiting Plan) and detailed milestones

### Execution Phase (🚧 In Progress)
1. **User** → Clicks "Execute Milestone" on next pending phase
2. **Controller** → Validates sequential execution (locks out-of-order milestones)
3. **ExecutorAgentJob** → Enqueues to executors queue
4. **ExecutorAgentService** → Breaks milestone into actionable steps
5. **ExecutorAgent** → Creates detailed action plan (not yet integrated)
6. **View** → Shows step-by-step instructions for current phase

### Monitoring Phase (📋 Planned)
- **MonitorAgentJob** → Runs daily to check goal progress
- **MonitorAgent** → Analyzes progress vs. targets, suggests adjustments
- **Notifications** → Sends alerts if milestone is falling behind

## Key Files
- **Controllers**:
  - `app/controllers/goals_controller.rb` — Goal CRUD + create_plan, execute_milestone, complete_milestone
  - `app/controllers/financial_goals_controller.rb` — Same as above for financial goals
  - `app/controllers/profiles_controller.rb` — Edit monthly_income and current_savings

- **Services**:
  - `app/services/agent_planning_service.rb` — Calls PlannerAgent, parses phases, creates milestones with details
  - `app/services/executor_agent_service.rb` — (Planned) Breaks milestones into actions

- **Jobs**:
  - `app/jobs/agent_planning_job.rb` — Solid Queue async job for plan creation
  - `app/jobs/executor_agent_job.rb` — (Planned) Runs ExecutorAgent for milestone execution

- **Agents**:
  - `app/agents/planner_agent.rb` — Analyzes goal, returns phases with descriptions and actions
  - `app/agents/executor_agent.rb` — (Planned) Creates action steps from milestone
  - `app/agents/monitor_agent.rb` — (Planned) Tracks progress daily

- **Views**:
  - `app/views/goals/show.html.erb` — Goal detail with phases + detailed descriptions
  - `app/views/financial_goals/show.html.erb` — Same as above for financial goals
  - `app/views/profiles/show.html.erb` — Display user's monthly income and savings
  - `app/views/profiles/edit.html.erb` — Edit financial profile
  - `app/views/layouts/application.html.erb` — Navbar with Profile link

- **Routes**:
  - `config/routes.rb` — Member routes for goals, resource route for profile

## Styling & UI
- **Aesthetic**: Discord dark theme (zinc/slate colors)
- **Framework**: Tailwind CSS (imported via importmap)
- **Components**: Stimulus for interactivity (no Turbo real-time yet)
- **Sections**: 
  - Goals Index: List all goals with status badges
  - Goal Detail: Current State → Goal Target → Milestones with details → Full Plan JSON
  - Milestone Cards: Phase name, description, key actions, timeline, monthly contribution, focus area
  - Profile: View/edit monthly income and current savings

## rcrewai Integration

### PlannerAgent
- **Role**: Financial Planning Specialist
- **Input**: Goal (name, target amount, target date), User financial context (income, savings)
- **Process**: Analyzes feasibility, creates 1-5 phases with specific details
- **Output**: JSON with phases (each with description, 4-6 specific key_actions, timeline, monthly_contribution, focus)
- **Tools**: None currently (future: WebSearch for investment recommendations)

### ExecutorAgent
- **Role**: Financial Execution Specialist
- **Input**: Milestone details (phase, target amount, description)
- **Process**: Breaks phase into 5-8 actionable steps
- **Output**: Action plan with step-by-step instructions
- **Tools**: None currently (future: WebSearch for how-to guides)

### MonitorAgent
- **Role**: Financial Progress Monitor
- **Input**: Goal progress, milestone status, time elapsed
- **Process**: Analyzes progress vs. targets, identifies risks
- **Output**: Alerts and recommendations
- **Status**: Planned

### Task Descriptions
- **PlannerTask**: Enhanced prompt requesting DETAILED phases with SPECIFIC actions (not generic "track progress")
  - Examples: "Cut subscription services and save R$200/month", "Move R$300 to high-yield savings account"
  - Considers user's income level for realism
  - Suggests concrete ways to increase income or reduce expenses if goal is challenging

## Database & Persistence
- **Goals** table: `name`, `target_amount`, `target_date`, `priority`, `status`, `plan` (JSONB with phases array)
- **Milestones** table: `goal_id`, `phase`, `target_amount`, `order_number`, `status`, `current_amount`, `progress_percentage`, `details` (JSON)
  - **details** field contains: `description`, `key_actions` (array), `timeline`, `monthly_contribution`, `focus`
- **Users** table: `email`, `monthly_income`, `current_savings` (for feasibility calculation)
- **AgentSessions** table: Logs all agent interactions for audit trail
- **AgentMessages** table: Stores conversation history between agents and AI

## State Management
- **Goals**: `planned`, `in_progress`, `completed`
- **Milestones**: `pending`, `in_progress`, `completed`
  - Only next pending milestone is executable (sequential locking)
  - Completing all milestones marks goal as `completed`
- **AgentSessions**: `idle`, `processing`, `completed`, `failed`

## Development Notes
- **Restart Rails** after creating new view templates
- **Route helpers**: Rails conventions use `method_resource_path` (e.g., `create_plan_goal_path(@goal)` not `goal_create_plan_path`)
- **Plans stored as JSONB**: Use `JSON.pretty_generate(@goal.plan)` to display
- **Milestone details**: Stored as JSON in `details` column — supports flexible structure without schema changes
- **Sequential execution**: Milestones locked until previous one is completed (see GoalsController#execute_milestone)
- **Agent prompts**: Enhanced with specific examples and user context for detailed, realistic phases

## Testing the Flow
1. **Setup**: Edit Profile to set Monthly Income (e.g., R$ 5,000)
2. **Create Goal**: `/goals/new` → name, target amount, target date, priority
3. **Plan Auto-Generated**: AgentPlanningJob runs, creates detailed phases (check Solid Queue worker)
4. **View Plan**: Click goal → see milestone phases with descriptions, actions, timeline
5. **Execute Milestone**: Click "Execute Milestone" on next pending phase
6. **Track Progress**: Mark milestone as completed when done
7. **Monitor**: Refresh to see progress bar and next available phase

## Testing with RSpec

### Setup

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/services/agent_planning_service_spec.rb

# Run with verbose output
bundle exec rspec --verbose

# Run with coverage
bundle exec rspec --require coverage
```

### Test Structure

```
spec/
├── controllers/          # Controller action tests
├── services/             # Service business logic tests
├── models/               # Model validation and method tests
├── jobs/                 # Background job tests
├── agents/               # Agent behavior tests
└── support/              # Test helpers and shared examples
```

### Key Test Files to Create

1. **Services** (`spec/services/agent_planning_service_spec.rb`):
   - Test plan creation with detailed phases
   - Verify milestone details are parsed correctly
   - Test with achievable vs. challenging goals

2. **Controllers** (`spec/controllers/goals_controller_spec.rb`):
   - Test CRUD actions
   - Test `create_plan` action enqueues job
   - Test sequential milestone execution
   - Test authorization (current_user)

3. **Models** (`spec/models/goal_spec.rb`):
   - Test `is_achievable?` logic
   - Test `months_remaining` calculation
   - Test `calculate_monthly_need` method
   - Test associations (milestones, user)

4. **Jobs** (`spec/jobs/agent_planning_job_spec.rb`):
   - Test job enqueues successfully
   - Test job calls AgentPlanningService
   - Test error handling and retries

5. **Agents** (`spec/agents/planner_agent_spec.rb`):
   - Test agent builds with correct role/goal
   - Test crew orchestration

### Example Test Pattern

```ruby
# spec/services/agent_planning_service_spec.rb
require 'rails_helper'

describe AgentPlanningService do
  let(:user) { create(:user, monthly_income: 5000, current_savings: 2000) }
  let(:goal) { create(:goal, user: user, target_amount: 10000, target_date: 3.months.from_now) }
  
  describe '#create_plan' do
    it 'creates milestones with detailed descriptions' do
      service = AgentPlanningService.new(goal)
      plan = service.create_plan
      
      expect(goal.milestones.count).to be_between(1, 5)
      expect(goal.milestones.first.details['description']).to be_present
      expect(goal.milestones.first.details['key_actions']).to be_an(Array)
      expect(goal.milestones.first.details['timeline']).to be_present
    end
    
    it 'updates goal status to planned' do
      service = AgentPlanningService.new(goal)
      service.create_plan
      
      expect(goal.reload.status).to eq('planned')
    end
    
    it 'creates agent session for audit' do
      service = AgentPlanningService.new(goal)
      service.create_plan
      
      session = AgentSession.last
      expect(session.user).to eq(user)
      expect(session.state).to eq('completed')
    end
  end
end
```

### Testing Best Practices

- **Use factories**: `create(:goal)` not `Goal.new`
- **Test behavior**: Test what the service/controller does, not how it does it
- **Mock external calls**: Mock OpenAI API calls to avoid costs and delays
- **Isolate units**: Test services separately from controllers
- **Test edge cases**: Achievable goals, challenging goals, zero income, etc.
- **Verify side effects**: Check database state after operations

## User Preferences

- **Language**: Portuguese documentation preferred
- **Styling**: Discord dark aesthetic with Tailwind CSS
- **UX**: Clear visual progression (Current State → Goal Target → Milestones → Full Plan)
- **Agents**: Expect detailed, specific recommendations (not generic advice)
- **Tools**: Interest in adding WebSearch and custom tools for real data integration
- **Testing**: RSpec for all new code (services, controllers, jobs, models)
