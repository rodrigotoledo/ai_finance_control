# Setup Instructions

## Prerequisites

- **Ruby**: 3.2+ (check with `ruby -v`)
- **Rails**: 7.0+ (check with `rails -v`)
- **PostgreSQL**: 13+ (check with `psql --version`)
- **Node.js**: 16+ (for Yarn/Importmap)
- **Bundler**: (check with `bundle -v`)

## Clone & Install

```bash
# Clone the repository
git clone https://github.com/yourusername/ai_finance_control.git
cd ai_finance_control

# Install dependencies
bundle install

# Install Node dependencies
yarn install
# or
npm install
```

## Database Setup

```bash
# Create databases (development + test)
rails db:create

# Run migrations
rails db:migrate

# Seed initial data (optional)
rails db:seed
```

### Check Database
```bash
# List all tables
rails db:schema:dump

# Or via Rails console
rails c
> Goal.all
> User.all
```

## Environment Variables

### Create .env file
```bash
cp .env.example .env
```

### Edit .env with your values
```bash
# OpenAI Configuration
OPENAI_API_KEY=sk-your-actual-api-key-here

# Database (optional, defaults to localhost)
DATABASE_URL=postgresql://user:password@localhost:5432/ai_finance_control_development

# Rails
RAILS_ENV=development
RAILS_MASTER_KEY=your-master-key-here  # Use rails credentials:edit

# Devise (email for password resets)
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
```

### Or use Rails Credentials
```bash
# Generate master key (if doesn't exist)
rails credentials:setup

# Edit encrypted credentials
rails credentials:edit

# Structure:
openai:
  api_key: sk-...

smtp:
  address: smtp.gmail.com
  port: 587
  username: your-email@gmail.com
  password: your-app-password
```

## Get OpenAI API Key

1. Go to https://platform.openai.com/account/api-keys
2. Sign up or log in
3. Click "Create new secret key"
4. Copy the key to your `.env` or `credentials.yml.enc`
5. Keep it secret! Don't commit to version control

## Start the Application

### Terminal 1: Rails Server
```bash
rails s
# Opens on http://localhost:3000
```

### Terminal 2: Solid Queue Worker (Background Jobs)
```bash
bundle exec solidqueue start
# Or in development, jobs process immediately with async_job flag
```

### Terminal 3: Tailwind CSS Compiler (if using CLI)
```bash
./bin/dev
# Or manually:
./bin/rails tailwindcss:watch
```

## Create User Account

1. Go to http://localhost:3000
2. Click "Sign Up"
3. Enter email and password
4. Click "Create Account"
5. Log in with your credentials

## Test the Flow

### Create First Goal
1. Click "Create New Goal" or navigate to `/goals/new`
2. Fill in:
   - **Goal Name**: "Save for house down payment"
   - **Target Amount**: 15000
   - **Target Date**: 8 months from now
   - **Priority**: 4 (out of 5)
3. Click "Create Goal"
4. Wait for PlannerAgent to create plan (check browser console for logs)

### Check Background Job Processing
```bash
# In another terminal, check logs
tail -f log/development.log

# You should see:
# "AgentPlanningJob started"
# "Calling PlannerAgent..."
# "Creating milestones from plan..."
# "AgentPlanningJob completed"
```

### Verify Milestones
1. Refresh the goal page (browser back or `/goals/:id`)
2. You should see:
   - Plan status badge: "✅ Plan Created"
   - List of milestones with phases (Phase 1, Phase 2, etc.)
   - Progress bar showing 0% complete
   - "Execute Milestone" buttons on pending milestones

## Development Workflow

### Rails Console
```bash
rails c

# Create a goal manually
goal = Goal.create(
  name: "Test Goal",
  target_amount: 10000,
  target_date: 3.months.from_now,
  priority: 3,
  user: User.first
)

# Trigger planning
AgentPlanningJob.perform_now(goal.id)

# Check result
goal.reload.plan
goal.milestones
```

### Database Inspection
```bash
# View schema
rails db:schema:dump

# Or via psql
psql ai_finance_control_development
> \dt  # list tables
> SELECT * FROM goals;
> SELECT * FROM milestones;
```

### View Logs
```bash
# Development logs
tail -f log/development.log

# Filter for specific component
tail -f log/development.log | grep "AgentPlanningJob"
tail -f log/development.log | grep "PlannerAgent"
```

## Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/controllers/goals_controller_spec.rb

# Run with coverage
bundle exec rspec --format coverage

# Run only specific test
bundle exec rspec spec/controllers/goals_controller_spec.rb:42
```

## Styling & Assets

### Tailwind CSS
```bash
# Tailwind is configured via importmap
# CSS classes are in: app/assets/tailwind/application.css

# Watch for changes
./bin/rails tailwindcss:watch
```

### Stimulus Controllers
```bash
# Stimulus is installed via importmap
# Controllers are in: app/javascript/controllers/

# Example: app/javascript/controllers/goal_form_controller.js
```

### Images & Static Files
```bash
# Static files are in: public/
# Asset pipeline files are in: app/assets/

# Precompile assets for production:
rails assets:precompile
```

## Common Issues

### "Could not find gem 'rcrewai'"
```bash
# Add to Gemfile and install
bundle install
```

### "OPENAI_API_KEY not found"
```bash
# Make sure .env file is created and loaded
# Check if gem 'dotenv-rails' is in Gemfile
bundle install

# Or use Rails credentials
rails credentials:edit  # Add openai: { api_key: ... }
```

### "Unexpected error: 429 Rate limit exceeded"
- You've hit OpenAI API rate limits
- Wait a minute and retry
- Or use a cheaper/faster model (gpt-3.5-turbo)

### "Solid Queue jobs not processing"
```bash
# Make sure worker is running
bundle exec solidqueue start

# Or check job status
rails c
> SolidQueue::Job.all  # list all jobs
> SolidQueue::Job.last.error  # check last error
```

### "Template missing" error
- Ensure view file exists in correct path
- Restart Rails server after creating new views
- Check file permissions

## Production Deployment

### Environment Setup
```bash
RAILS_ENV=production
SECRET_KEY_BASE=$(bundle exec rails secret)
OPENAI_API_KEY=sk-...
DATABASE_URL=postgresql://user:pass@host:5432/db
```

### Database Migrations
```bash
rails db:migrate RAILS_ENV=production
```

### Precompile Assets
```bash
rails assets:precompile RAILS_ENV=production
```

### Start Server
```bash
bundle exec puma -p 80
# or with systemd/systemctl
```

### Background Jobs
```bash
# Run Solid Queue worker in background
bundle exec solidqueue start &
```

## Monitoring

### Check Application Health
```bash
curl http://localhost:3000/up
# Returns 200 OK if healthy
```

### Monitor Background Jobs
```bash
rails c

# Check job queue
SolidQueue::Job.where(finished_at: nil).count

# Check failed jobs
SolidQueue::Job.where(failed_at: (Time.now - 24.hours)..Time.now)

# Check specific job
job = SolidQueue::Job.find(1)
job.error  # view error message
```

### View Application Logs
```bash
# Development
tail -f log/development.log

# Production
tail -f log/production.log | grep "ERROR"
```

## Next Steps

1. **Explore the code**: Open `app/` directory to understand structure
2. **Read the docs**:
   - [architecture.md](architecture.md) — System design
   - [agents.md](agents.md) — AI agents documentation
   - [rcrewai.md](rcrewai.md) — rcrewai integration
3. **Modify and extend**: Update agent prompts, add tools, build features
4. **Test in browser**: Create goals, verify PlannerAgent works, execute milestones
5. **Deploy**: Follow production deployment steps above

## Support

- **Issues**: Report bugs at [GitHub Issues](https://github.com/yourusername/ai_finance_control/issues)
- **Docs**: See [README.md](../README.md) and docs/ folder
- **Community**: Discuss on [Discord](https://discord.gg/yourserver) (if applicable)

---

## Quick Reference

| Task | Command |
|------|---------|
| Start server | `rails s` |
| Run migrations | `rails db:migrate` |
| Rails console | `rails c` |
| Run tests | `bundle exec rspec` |
| View logs | `tail -f log/development.log` |
| Start background worker | `bundle exec solidqueue start` |
| Edit credentials | `rails credentials:edit` |
| Precompile assets | `rails assets:precompile` |
| Create migration | `rails g migration MigrationName` |
| Reset database | `rails db:drop db:create db:migrate` |
