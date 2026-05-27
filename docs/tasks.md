# Background Tasks & Workflows

## Overview

This document describes the background job system using Solid Queue. All long-running operations (agent calls, data processing) happen asynchronously to keep the web interface responsive.

## Solid Queue

**What**: Rails 8+ background job processing system (replaces Sidekiq/Resque)  
**Why**: Simple, database-backed, no external dependencies  
**How**: Jobs stored in database, worker processes them

### Configuration

```ruby
# config/solid_queue.yml
development:
  workers:
    - queues:
        - default
        - mailers
        - executors
      threads: 5
      processes: 1

production:
  workers:
    - queues:
        - default
        - mailers
      threads: 10
      processes: 3
    - queues:
        - executors
      threads: 5
      processes: 1
```

### Start Worker

```bash
# Development (watch and auto-reload)
bundle exec solidqueue start

# Production (daemonize)
bundle exec solidqueue start --daemonize --pidfile=tmp/pids/solid_queue.pid
```

---

## AgentPlanningJob ✅

**Purpose**: Asynchronously call PlannerAgent to create financial plans

**Queue**: `default`  
**Priority**: Normal  
**Retry**: 3 attempts (exponential backoff)

### Trigger Points

1. **Automatic** (on goal creation)
```ruby
# app/controllers/goals_controller.rb
def create
  @goal = current_user.financial_goals.build(goal_params)
  if @goal.save
    AgentPlanningJob.perform_later(@goal.id)  # ← enqueues here
    redirect_to @goal, notice: "PlannerAgent is analyzing..."
  end
end
```

2. **Manual** (via button click)
```ruby
# app/controllers/goals_controller.rb
def create_plan
  if @goal.plan.present?
    redirect_to goal_path(@goal), alert: "Plan already exists"
    return
  end
  AgentPlanningJob.perform_later(@goal.id)  # ← enqueues here
  redirect_to goal_path(@goal), notice: "Creating plan..."
end
```

### Implementation

```ruby
# app/jobs/agent_planning_job.rb
class AgentPlanningJob < ApplicationJob
  queue_as :default
  
  # Retry up to 3 times with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  def perform(goal_id)
    goal = Goal.find(goal_id)
    
    # Call the service
    AgentPlanningService.new.call(goal)
  rescue => e
    Rails.logger.error("AgentPlanningJob failed: #{e.message}")
    raise e  # Solid Queue will retry
  end
end
```

### Service Logic

```ruby
# app/services/agent_planning_service.rb
class AgentPlanningService
  def call(goal)
    # 1. Log session start
    session = AgentSession.create(
      user_id: goal.user_id,
      agent_type: 'PlannerAgent',
      goal_id: goal.id,
      state: 'processing',
      input_data: { goal_id: goal.id, target_amount: goal.target_amount }
    )
    
    # 2. Call PlannerAgent
    plan_data = call_planner_agent(goal)
    
    # 3. Update goal with plan (JSON)
    goal.update(plan: plan_data)
    
    # 4. Create Milestone records from plan
    create_milestones_from_context(goal, plan_data)
    
    # 5. Log completion
    session.update(
      state: 'completed',
      output_data: plan_data
    )
    
    # 6. Optionally send notification
    UserMailer.plan_created(goal).deliver_later
  rescue => e
    # Log failure
    session&.update(state: 'failed', error_message: e.message)
    raise e
  end
  
  private
  
  def call_planner_agent(goal)
    prompt = <<~PROMPT
      Financial Goal: #{goal.name}
      Target Amount: R$ #{goal.target_amount}
      Deadline: #{goal.target_date.strftime('%B %d, %Y')}
      Current Savings: R$ #{goal.user.current_savings}
      Monthly Income: R$ #{goal.user.monthly_income}
      Priority: #{goal.priority}/5
      
      Create a detailed plan with 1-5 phases.
      Return JSON: { "phases": [...] }
    PROMPT
    
    # Call rcrewai agent
    Agents::PlannerAgent.create_plan(goal)
  end
  
  def create_milestones_from_context(goal, plan_data)
    phases = plan_data['phases'] || []
    num_phases = phases.count
    
    phases.each_with_index do |phase, index|
      goal.milestones.create!(
        phase: phase['name'],
        target_amount: phase['target_amount'] || (goal.target_amount / num_phases),
        order_number: index + 1,
        status: 'pending'
      )
    end
  end
end
```

### Workflow Diagram

```
User submits goal form
         ↓
GoalsController#create
    - validates
    - saves goal
         ↓
AgentPlanningJob.perform_later(@goal.id)
    (returns immediately to user)
         ↓
[Solid Queue Worker]
         ↓
AgentPlanningJob#perform
         ↓
AgentPlanningService#call
         ↓
Agents::PlannerAgent.create_plan(goal)
    (calls OpenAI GPT-4)
         ↓
Update goal.plan (JSONB)
Create Milestone records
Update AgentSession (completed)
         ↓
[Job done]
         ↓
User refreshes page
GoalsController#show
Displays: Plan badge ✅ + Milestones
```

---

## ExecutorAgentJob 🚧

**Purpose**: Break milestone down into actionable steps

**Queue**: `executors` (separate for priority handling)  
**Priority**: Normal  
**Retry**: 3 attempts

### Trigger

```ruby
# app/controllers/goals_controller.rb
def execute_milestone
  milestone = @goal.milestones.find(params[:milestone_id])
  
  if milestone.pending?
    ExecutorAgentJob.perform_later(milestone.id)
    redirect_to goal_path(@goal), notice: "Execution started..."
  end
end
```

### Implementation (Target)

```ruby
# app/jobs/executor_agent_job.rb
class ExecutorAgentJob < ApplicationJob
  queue_as :executors  # High-priority queue
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  def perform(milestone_id)
    milestone = Milestone.find(milestone_id)
    ExecutorAgentService.new.call(milestone)
  end
end
```

### Service Logic (Target)

```ruby
# app/services/executor_agent_service.rb
class ExecutorAgentService
  def call(milestone)
    goal = milestone.goal
    
    # 1. Log session
    session = AgentSession.create(
      user_id: goal.user_id,
      agent_type: 'ExecutorAgent',
      milestone_id: milestone.id,
      state: 'processing'
    )
    
    # 2. Call ExecutorAgent
    action_plan = call_executor_agent(milestone, goal)
    
    # 3. Update milestone status
    milestone.update(
      status: 'in_progress',
      execution_plan: action_plan
    )
    
    # 4. Create Action records
    create_actions_from_plan(milestone, action_plan)
    
    # 5. Log completion
    session.update(state: 'completed', output_data: action_plan)
  end
  
  private
  
  def call_executor_agent(milestone, goal)
    prompt = <<~PROMPT
      Milestone: #{milestone.phase}
      Target: R$ #{milestone.target_amount}
      User's Savings: R$ #{goal.user.current_savings}
      Monthly Income: R$ #{goal.user.monthly_income}
      
      Create 5-8 specific, actionable steps.
      Return JSON: { "steps": [...] }
    PROMPT
    
    Agents::ExecutorAgent.create_action_plan(milestone)
  end
  
  def create_actions_from_plan(milestone, plan_data)
    steps = plan_data['steps'] || []
    
    steps.each do |step|
      milestone.actions.create!(
        action: step['action'],
        timeline: step['timeline'],
        priority: step['priority'],
        status: 'pending'
      )
    end
  end
end
```

---

## MonitorAgentJob 📋

**Purpose**: Daily check milestone progress, send alerts/recommendations

**Queue**: `default`  
**Frequency**: Daily (cron job)  
**Retry**: 2 attempts

### Configuration (Target)

```ruby
# config/solid_queue.yml
recurring:
  - class: MonitorAgentJob
    schedule: "every day at 9:00 am"
    key: monitor_goals_daily
```

### Implementation (Target)

```ruby
# app/jobs/monitor_agent_job.rb
class MonitorAgentJob < ApplicationJob
  queue_as :default
  
  def perform
    # For each goal without completed status
    Goal.where(status: [:planned, :in_progress]).find_each do |goal|
      MonitorAgentService.new.call(goal)
    end
  end
end
```

---

## Job Status & Monitoring

### View Job Queue

```ruby
rails c

# All jobs
SolidQueue::Job.all

# Pending jobs
SolidQueue::Job.where(finished_at: nil)

# Failed jobs (last 24 hours)
SolidQueue::Job.where(failed_at: (24.hours.ago..Time.now))

# Check specific job error
job = SolidQueue::Job.last
job.error_message
job.error_backtrace
```

### Monitor in Production

```bash
# Check job queue size
rails c -e production
> SolidQueue::Job.where(finished_at: nil).count

# Tail worker logs
tail -f log/production.log | grep "AgentPlanningJob"

# Monitor Solid Queue table
rails db:sql:execute "SELECT COUNT(*) FROM solid_queue_jobs WHERE finished_at IS NULL"
```

### Retry Failed Job

```ruby
rails c

# Find failed job
job = SolidQueue::Job.where(status: 'failed').last

# Retry
job.ready!  # Mark as ready to retry
SolidQueue::JobRunner.new(job).perform  # Or let worker pick it up
```

---

## Job Lifecycle

```
1. CREATED (enqueued)
   - Job stored in database
   - Status: scheduled

2. READY (waiting)
   - Scheduled time reached
   - Status: ready
   - Worker picks it up

3. RUNNING (processing)
   - Worker executing job
   - Status: running
   - Timestamp: started_at

4. COMPLETED ✅
   - Job finished successfully
   - Status: completed
   - Timestamp: finished_at

5. FAILED ❌ (optional)
   - Job raised exception
   - Status: failed
   - Timestamp: failed_at
   - Error: error_message
   
   If retry_on configured:
   → Retry 1 (wait 1s)
   → Retry 2 (wait 4s)
   → Retry 3 (wait 16s)
   → Failed (no more retries)
```

---

## Email Notifications (Future)

```ruby
# app/jobs/notification_job.rb
class NotificationJob < ApplicationJob
  queue_as :mailers
  
  def perform(user_id, event)
    user = User.find(user_id)
    
    case event
    when 'plan_created'
      UserMailer.plan_created(user).deliver_now
    when 'milestone_completed'
      UserMailer.milestone_completed(user).deliver_now
    when 'goal_achieved'
      UserMailer.goal_achieved(user).deliver_now
    end
  end
end
```

---

## Error Handling & Retries

### Automatic Retries

```ruby
# Default: 3 retries with exponential backoff
class MyJob < ApplicationJob
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
end

# Custom: 5 retries, longer wait
class MyJob < ApplicationJob
  retry_on StandardError, wait: 10.minutes, attempts: 5
end

# No retry
class MyJob < ApplicationJob
  discard_on StandardError
end
```

### Manual Error Handling

```ruby
class AgentPlanningJob < ApplicationJob
  def perform(goal_id)
    goal = Goal.find(goal_id)
    
    begin
      AgentPlanningService.new.call(goal)
    rescue OpenAI::RateLimitError
      # Retry later (Solid Queue will handle)
      raise
    rescue OpenAI::AuthenticationError
      # Don't retry, just log
      Rails.logger.error("OpenAI auth failed for goal #{goal_id}")
      # or notify user
    rescue JSON::ParserError
      # Log and save error to AgentSession
      AgentSession.find_by(goal_id: goal_id)&.update(
        state: 'failed',
        error_message: "Invalid JSON response from agent"
      )
    end
  end
end
```

---

## Best Practices

✅ **Do**:
- Use appropriate queue for job priority (default vs. executors)
- Log all agent interactions in AgentSession
- Notify user of long-running operations
- Retry transient failures (rate limits, timeouts)
- Store input/output for debugging
- Use `perform_later` (async) not `perform_now` (sync) in controllers

❌ **Don't**:
- Block user responses waiting for agent calls
- Store huge objects in job parameters (use IDs instead)
- Forget to handle API rate limits
- Leave failed jobs without error messages
- Use same queue for fast and slow jobs
- Retry on permanent failures (auth, validation errors)

---

## Monitoring Tools

```bash
# Monitor queue depth
watch -n 1 'rails c -e production -e "puts SolidQueue::Job.where(finished_at: nil).count"'

# Check worker health
ps aux | grep solidqueue

# Recent job timeline
rails c
> SolidQueue::Job.order(created_at: :desc).limit(10).map { |j| [j.class_name, j.status, j.finished_at] }
```

---

## References

- [Solid Queue Docs](https://github.com/rails/solid_queue)
- [Rails ActiveJob Guide](https://guides.rubyonrails.org/active_job_basics.html)
- [Error Handling Patterns](https://thoughtbot.com/blog/rails-job-exception-handling)
