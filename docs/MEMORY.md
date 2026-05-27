# Project Memory Index

This file indexes project context for future Claude Code sessions.

## Documentation Files
- [architecture.md](architecture.md) — System design & data flow
- [agents.md](agents.md) — AI agents: PlannerAgent, ExecutorAgent, MonitorAgent
- [rcrewai.md](rcrewai.md) — rcrewai integration guide & usage patterns
- [setup.md](setup.md) — Installation & development environment setup
- [tasks.md](tasks.md) — Background job system (Solid Queue)

## Configuration Files
- [CLAUDE.md](../CLAUDE.md) — Claude Code project context
- [.cursorrules](../.cursorrules) — Cursor IDE rules
- [.openclaude](../.openclaude) — OpenClaude context
- [.env.example](../.env.example) — Environment variables template

## Project Structure

### Controllers
- `app/controllers/goals_controller.rb` — CRUD + `create_plan` action
- `app/controllers/financial_goals_controller.rb` — CRUD + `create_plan` action

### Services
- `app/services/agent_planning_service.rb` — Calls PlannerAgent, creates milestones

### Jobs
- `app/jobs/agent_planning_job.rb` — Solid Queue async job for PlannerAgent

### Views
- `app/views/goals/show.html.erb` — Goal detail page (Tailwind CSS)
- `app/views/financial_goals/show.html.erb` — Financial goal detail page

### Models (via migrations)
- `goals` table — name, target_amount, target_date, priority, status, plan (JSONB)
- `milestones` table — phase, target_amount, order_number, status, current_amount, progress_percentage
- `users` table — email, password (Devise), current_savings, monthly_income
- `agent_sessions` table — agent_type, goal_id, milestone_id, state (AASM), input_data, output_data
- `agent_messages` table — agent_session_id, role, content

## Critical Concepts

### Plan Flow
1. User creates goal → GoalsController#create
2. AgentPlanningJob.perform_later(@goal.id) enqueues
3. Service calls Agents::PlannerAgent via rcrewai
4. Plan JSON returned → goal.plan = plan_data
5. Milestones created from plan.phases
6. View displays plan status badge + milestone list

### Route Helpers (IMPORTANT)
- Goals: `create_plan_goal_path(@goal)` (NOT goal_create_plan_path)
- Financial Goals: `create_plan_financial_goal_path(@goal)` (NOT financial_goal_create_plan_path)

### Styling
- Framework: Tailwind CSS (importmap, no build step)
- Theme: Discord dark mode (zinc colors)
- Components: Stimulus controllers
- Responsive: Mobile-first with md:/lg: breakpoints

## Next Phases

### Phase 2: Execution
- [ ] ExecutorAgent implementation
- [ ] ExecutorAgentJob & ExecutorAgentService
- [ ] Action step creation & tracking
- [ ] "Execute Milestone" button functionality

### Phase 3: Monitoring
- [ ] MonitorAgent implementation
- [ ] Daily cron job for progress tracking
- [ ] Email notifications on milestones
- [ ] Dashboard with progress visualization

### Phase 4+: Advanced
- Tools (bank APIs, investment calculators)
- Multi-agent conversations
- Custom LLM fine-tuning
- PDF exports
- Real-time notifications

## Known Issues & Fixes
- View templates require Rails server restart after creation
- route helpers follow Rails conventions (method_resource_path, not resource_method_path)
- Plan JSON stored in JSONB: use JSON.pretty_generate() for display
- Milestone targets divided evenly: target / num_phases

## Testing Commands
```bash
# Start server
rails s

# Start background worker
bundle exec solidqueue start

# Rails console
rails c
> Goal.last.milestones
> AgentPlanningJob.perform_now(goal_id)

# Run tests
bundle exec rspec

# Monitor jobs
SolidQueue::Job.where(finished_at: nil).count
```

## Resources
- rcrewai: https://github.com/gkosmo/rcrewai
- CrewAI: https://docs.crewai.com/
- OpenAI API: https://platform.openai.com/docs/
- Rails: https://guides.rubyonrails.org/
- Tailwind: https://tailwindcss.com/docs/

