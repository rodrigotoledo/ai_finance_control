# AI Finance Control - Setup & Usage Guide

A Goal-Oriented Multi-Agent Finance Planning system using rcrewai with three phases: **Planning → Execution → Monitoring**

## Architecture Overview

```
Views (Goals UI)
    ↓
Jobs (ExecutorAgentJob)
    ↓
Services (ExecutorAgentService, AgentPlanningService)
    ↓
Agents (PlannerAgent, ExecutorAgent via rcrewai)
    ↓
Database (Persistence: AgentSessions, AgentMessages, Milestones)
```

## The Three Phases

### 1. Planning Phase (Planejamento)
- User creates a financial goal with target amount and deadline
- PlannerAgent analyzes user's income, savings, and timeline
- System creates milestones (quarterly phases) to break down the goal
- Plan is stored in database for reference and audit trail

### 2. Execution Phase (Execução)
- User can execute individual milestones from the UI
- ExecutorAgent creates detailed action plans for each milestone
- System simulates progress (adds 33% of milestone amount)
- Milestone status updates to "in_progress"
- All execution results stored in AgentSession messages

### 3. Monitoring Phase (Monitoramento)
- View milestone progress and completion percentages
- Track current state vs goal state with visual progress bars
- Review execution history in database
- (Future) MonitorAgent will provide adjustment recommendations

## Quick Start

### 1. Create Test User & Goal
```bash
rails goals:setup_test
```
This creates:
- User: `planner_test@test.com` (R$5000/month income, R$50k savings)
- Goal: "Comprar um carro" (R$100,000 target, 2 years deadline)

### 2. Create Milestones
```bash
rails goals:create_milestones
```
Creates 4 quarterly phases for the goal

### 3. Access the Web UI
Start the Rails server:
```bash
rails s
```

Navigate to:
- **Goals Dashboard**: `http://localhost:3000/goals`
- **Goal Detail**: `http://localhost:3000/goals/1` (view milestones)
- **Execute Milestone**: Click "Execute Milestone" button on the goal detail page

## File Structure

```
app/
├── agents/
│   ├── expense_analyzer_agent.rb    # Analyzes spending patterns
│   ├── planner_agent.rb             # Creates financial plans
│   └── executor_agent.rb            # Executes milestone actions
├── controllers/
│   └── goals_controller.rb          # Goals UI controller (NEW)
├── services/
│   ├── executor_agent_service.rb    # Orchestrates ExecutorAgent (NEW)
│   ├── agent_planning_service.rb    # Orchestrates PlannerAgent
│   ├── spending_analyzer.rb         # Spending analysis logic
│   └── financial_engine.rb          # Financial calculations
├── jobs/
│   └── executor_agent_job.rb        # Background job for execution (NEW)
├── models/
│   ├── milestone.rb                 # Goal phases (NEW)
│   ├── financial_goal.rb            # User goals
│   ├── agent_session.rb             # Agent conversation sessions
│   ├── agent_message.rb             # Session messages
│   ├── user.rb                      # User with goals
│   └── transaction.rb               # User transactions
└── views/
    ├── goals/
    │   ├── index.html.erb           # Goals list (NEW)
    │   └── show.html.erb            # Goal detail with milestones (NEW)
    └── layouts/
        └── application.html.erb     # Discord-styled layout (UPDATED)

lib/tasks/
└── agents.rake                      # Rake tasks for testing (UPDATED)

config/
├── routes.rb                        # Goals resources (UPDATED)
└── initializers/
    └── rcrewai.rb                   # rcrewai configuration

db/
└── migrate/
    ├── 20260527121715_create_milestones.rb
    └── 20260527121148_fix_financial_goals_foreign_key.rb
```

## Database Schema

### Milestones Table
```sql
CREATE TABLE milestones (
  id INTEGER PRIMARY KEY,
  financial_goal_id INTEGER,
  phase VARCHAR (target phase name),
  target_amount DECIMAL (target amount for this phase),
  current_amount DECIMAL (current progress),
  status VARCHAR (pending/in_progress/completed),
  order_number INTEGER (1-4 for quarterly phases),
  created_at TIMESTAMP,
  updated_at TIMESTAMP
)
```

### Related Tables
- `financial_goals`: Goals with target_amount, target_date, user_id
- `agent_sessions`: Conversations tracking planning/execution
- `agent_messages`: Messages with role, content, metadata (AI responses)
- `users`: Email, monthly_income, current_savings

## Testing the Flow

### Manual Test via Rails Runner
```bash
rails runner '
milestone = Milestone.first
puts "Executing milestone: #{milestone.phase}"
result = ExecutorAgentService.new(milestone).execute_milestone
puts "Status: #{result[:status]}"
puts "Progress: #{result[:progress_percentage]}%"
'
```

### Via Web UI
1. Navigate to `http://localhost:3000/goals`
2. Click "View Plan" on the goal card
3. See Current State (user savings), Goal State (target), Milestones
4. Click "Execute Milestone" on a pending milestone
5. Refresh to see status updated to "In Progress"

### Rake Tasks
```bash
# List all agent sessions
rails agents:list_sessions

# List all goals and plans
rails goals:list_plans

# Plan a goal (create milestones from agent planning)
rails goals:plan[1]
```

## Key Features Implemented

### ✅ Architecture
- **Orchestrated Jobs**: Views → Jobs → Services → Agents
- **Database Persistence**: All agent executions stored in AgentSession/AgentMessages
- **No Real-time Updates**: Uses standard page refresh (no Turbo polling)
- **Stimulus Components**: Ready for future interactions

### ✅ UI/UX
- **Discord Aesthetic**: Dark theme (#36393f background), cards, clean typography
- **Clear Visualizations**:
  - Current State: User's savings and monthly income
  - Goal State: Target amount with progress bar
  - Milestones: Phase breakdown with individual progress tracking
- **Responsive Layout**: Max-width containers, mobile-friendly grid

### ✅ Agent Integration
- **rcrewai**: Ruby wrapper for CrewAI with OpenAI GPT-4
- **ExecutorAgent**: Creates detailed action plans for milestones
- **PlannerAgent**: Creates overall financial plans
- **ExpenseAnalyzerAgent**: Analyzes spending patterns

### ✅ State Management
- **AASM State Machine**: AgentSession states (idle → processing → completed/failed)
- **Locking**: Prevents concurrent execution with session.lock_for_processing!
- **Error Handling**: Graceful fallbacks with error logging

## Configuration

### Environment Variables (.env)
```
OPENAI_API_KEY=sk-...
```

### rcrewai Configuration (config/initializers/rcrewai.rb)
```ruby
RCrewAI.configure do |config|
  config.logger = Rails.logger
  config.provider = :openai
  config.temperature = 0.1
end
```

### Database
```bash
rails db:create
rails db:migrate
```

## Next Steps / Future Enhancements

1. **MonitorAgent**: Track milestone progress and suggest adjustments
2. **Real-time Updates**: Add WebSockets via Solid Cable when needed
3. **Tool Integration**: Give agents access to external APIs
   - Bank account APIs for real transaction data
   - Investment/savings platform integrations
4. **Advanced Planning**: Multi-agent coordination for complex scenarios
5. **Mobile App**: React Native with same agent backend

## Troubleshooting

### Error: "undefined method 'milestones' for FinancialGoal"
→ Ensure `has_many :milestones` is in FinancialGoal model

### Error: "no such column: milestones.status"
→ Run `rails db:migrate`

### Error: "ExecutorAgent not executing"
→ Check OPENAI_API_KEY is set and API quota available

### Views not showing Discord styling
→ Ensure you're not using simple.css overlay. Check `app/views/layouts/application.html.erb`

## Learning Resources

- [rcrewai GitHub](https://github.com/gkosmo/rcrewai)
- [CrewAI Documentation](https://docs.crewai.com)
- [Rails Guide to Jobs](https://guides.rubyonrails.org/active_job_basics.html)
- [AASM State Machine](https://github.com/aasm/aasm)

## Support

For issues or questions:
1. Check the database is properly migrated: `rails db:migrate:status`
2. Verify OpenAI API key is set
3. Review agent session messages: `rails runner "puts User.first.agent_sessions.last.messages.last.content"`
4. Check Rails logs: `tail -f log/development.log`
