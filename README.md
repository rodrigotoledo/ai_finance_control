# AI Finance Control

Goal-Oriented Multi-Agent Finance Planning System powered by rcrewai and OpenAI.

Transform financial goals into achievable milestones with AI-powered planning, execution guidance, and progress monitoring.

## Features

### ✅ Planning Phase (Active)
- Create financial goals with target amounts and deadlines
- **PlannerAgent** analyzes goals and creates multi-phase plans using GPT-4
- Automatic breakdown into 1-5 milestones with realistic targets
- Store plans as structured JSON for reference

### 🚧 Execution Phase (In Development)
- **ExecutorAgent** converts milestones into actionable steps
- Step-by-step guidance for goal achievement
- Priority-based task ordering
- Risk mitigation strategies

### 📋 Monitoring Phase (Planned)
- **MonitorAgent** tracks progress and sends alerts
- Proactive recommendations if off-track
- Celebrate milestone completions
- Dashboard with progress visualization

## Quick Start

### Prerequisites
- Ruby 3.2+
- PostgreSQL 13+
- Node.js 16+
- OpenAI API key

### Setup (5 minutes)

```bash
# Clone and install
git clone https://github.com/yourusername/ai_finance_control.git
cd ai_finance_control
bundle install

# Configure environment
cp .env.example .env
# Edit .env and add your OPENAI_API_KEY

# Database setup
rails db:create db:migrate

# Start servers
rails s                    # Terminal 1: Rails server
bundle exec solidqueue start  # Terminal 2: Background jobs
```

Open http://localhost:3000 and create your first financial goal!

## How It Works

```
User creates goal
    ↓
AgentPlanningJob (background)
    ↓
PlannerAgent (rcrewai + GPT-4)
    Analyzes: target amount, deadline, income, savings
    Returns: structured plan with phases
    ↓
Service creates Milestones from plan
    ↓
View displays: Plan badge ✅ + Milestone list + Progress bar
    ↓
User can manually execute milestones
    ↓
ExecutorAgent (future)
    Breaks milestone into actionable steps
    ↓
MonitorAgent (future)
    Tracks progress, sends notifications
```

## Architecture

- **Stack**: Rails 7 + PostgreSQL + Tailwind CSS + Stimulus
- **Background Jobs**: Solid Queue (database-backed)
- **AI Orchestration**: rcrewai (Ruby wrapper for CrewAI)
- **LLM**: OpenAI GPT-4
- **UI Theme**: Discord dark mode

See [docs/architecture.md](docs/architecture.md) for detailed system design.

## Documentation

- **[docs/setup.md](docs/setup.md)** — Installation & configuration
- **[docs/architecture.md](docs/architecture.md)** — System design & data flow
- **[docs/agents.md](docs/agents.md)** — PlannerAgent, ExecutorAgent, MonitorAgent
- **[docs/rcrewai.md](docs/rcrewai.md)** — rcrewai integration guide
- **[docs/tasks.md](docs/tasks.md)** — Background job system (Solid Queue)
- **[CLAUDE.md](CLAUDE.md)** — Claude Code project context
- **[.cursorrules](.cursorrules)** — Cursor IDE configuration
- **[.openclaude](.openclaude)** — OpenClaude configuration

## Usage Example

### Create a Financial Goal
1. Sign up or log in
2. Click "Create New Goal"
3. Fill in:
   - **Goal Name**: "Emergency Fund"
   - **Target Amount**: R$ 5,000
   - **Target Date**: 6 months from now
   - **Priority**: 4 (out of 5)
4. Click "Create Goal"

### What Happens Next
- `AgentPlanningJob` enqueues automatically
- PlannerAgent analyzes your goal in the background
- Milestones are created (e.g., "Month 1-2: Foundation", "Month 3-4: Momentum", etc.)
- Page shows plan status badge: ✅ **Plan Created**
- View breakdown of phases with target amounts
- Click "Execute Milestone" to get step-by-step guidance

## File Structure

```
app/
├── controllers/     # Goals, FinancialGoals, Agent chat
├── models/          # Goal, Milestone, User, AgentSession
├── services/        # AgentPlanningService, ExecutorAgentService
├── jobs/            # AgentPlanningJob, ExecutorAgentJob
├── views/           # goals, financial_goals, agent interface
└── assets/          # Tailwind CSS, Stimulus

config/
├── routes.rb        # RESTful routes + member actions
├── initializers/    # Devise, Solid Queue, rcrewai

db/
├── migrations/      # Schema changes

docs/
├── architecture.md  # System design
├── agents.md        # Agent documentation
├── rcrewai.md       # Integration guide
├── setup.md         # Installation
└── tasks.md         # Background jobs

CLAUDE.md            # Claude Code context
.cursorrules         # Cursor IDE rules
.openclaude          # OpenClaude context
.env.example         # Environment template
```

## Key Concepts

### Goals
Financial objectives with target amounts and deadlines. Store user's aspirations and current progress.

### Milestones
Phases within a goal. Created by PlannerAgent from the structured plan. Each milestone represents a step toward the goal.

### Agents
AI workers powered by rcrewai + OpenAI GPT-4:
- **PlannerAgent**: ✅ Creates multi-phase plans from goals
- **ExecutorAgent**: 🚧 Converts milestones into actionable steps
- **MonitorAgent**: 📋 Tracks progress & sends recommendations

### Agent Sessions
Logs all agent executions for auditoria. Tracks input, output, errors, and execution time.

## Development

### Run Tests
```bash
bundle exec rspec
```

### Rails Console
```bash
rails c

# Create goal manually
goal = Goal.create(
  name: "Teste",
  target_amount: 10000,
  target_date: 3.months.from_now,
  user: User.first
)

# Trigger planning
AgentPlanningJob.perform_now(goal.id)

# Check result
goal.reload.milestones
```

### Monitor Jobs
```bash
rails c
SolidQueue::Job.where(finished_at: nil).count  # Pending jobs
SolidQueue::Job.last.error_message             # Last job error
```

## Configuration

### OpenAI API Key
Get your free API key: https://platform.openai.com/account/api-keys

```bash
# Add to .env
OPENAI_API_KEY=sk-your-key-here

# Or use Rails credentials
rails credentials:edit
# Add: openai: { api_key: sk-... }
```

### Background Jobs
Jobs are processed by Solid Queue workers. Start with:

```bash
bundle exec solidqueue start
```

In development, jobs process immediately with background queue.

## Deployment

### Heroku
```bash
git push heroku main
heroku run rails db:migrate
heroku run rails db:seed  # optional
```

### Docker
```bash
docker build -t ai-finance-control .
docker run -p 3000:3000 ai-finance-control
```

### Self-Hosted
See [docs/setup.md](docs/setup.md) for production deployment instructions.

## Roadmap

### Phase 1: Planning ✅
- [x] PlannerAgent implementation
- [x] Milestone creation from plans
- [x] Plan status in UI
- [x] Manual plan trigger

### Phase 2: Execution 🚧
- [ ] ExecutorAgent implementation
- [ ] Action step creation
- [ ] Progress tracking
- [ ] Dashboard view

### Phase 3: Monitoring 📋
- [ ] MonitorAgent implementation
- [ ] Daily progress checks
- [ ] Alerts & recommendations
- [ ] Email notifications

### Phase 4+: Advanced
- [ ] Tool integration (bank APIs, investment data)
- [ ] Multi-agent conversations
- [ ] Custom LLM fine-tuning
- [ ] PDF export of plans
- [ ] Real-time notifications (SMS, push)
- [ ] Social sharing & community goals

## Technologies

- **Rails 7** — Web framework
- **PostgreSQL** — Database with JSONB support
- **Tailwind CSS** — Styling (via importmap)
- **Stimulus** — Interactive components
- **rcrewai** — Multi-agent AI orchestration
- **OpenAI GPT-4** — Language model
- **Solid Queue** — Background job processing
- **Devise** — User authentication

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Support

- **Documentation**: See `docs/` folder
- **Issues**: [GitHub Issues](https://github.com/yourusername/ai_finance_control/issues)
- **Discussion**: [GitHub Discussions](https://github.com/yourusername/ai_finance_control/discussions)

## License

This project is licensed under the MIT License — see LICENSE file for details.

## Acknowledgments

- [rcrewai](https://github.com/gkosmo/rcrewai) — Ruby wrapper for CrewAI
- [CrewAI](https://crewai.com) — Multi-agent AI framework
- [OpenAI](https://openai.com) — GPT-4 LLM
- [Rails](https://rubyonrails.org) — Web framework
- [Tailwind CSS](https://tailwindcss.com) — CSS framework

---

**Status**: 🚀 In Active Development  
**Last Updated**: May 2026  
**Maintainer**: [Your Name](https://github.com/yourusername)
