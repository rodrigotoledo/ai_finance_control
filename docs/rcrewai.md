# rcrewai Integration Guide

## What is rcrewai?

rcrewai is a Ruby wrapper for CrewAI, a framework for building multi-agent AI systems. It enables orchestration of multiple AI agents (powered by OpenAI's LLM) that can collaborate on complex tasks.

**Repository**: https://github.com/gkosmo/rcrewai  
**Gem**: `rcrewai`  
**License**: MIT

## Why rcrewai?

- **Multi-Agent Orchestration**: Coordinate multiple AI agents with different roles
- **Structured Workflows**: Tasks are organized and executed in sequence
- **Tool Integration**: Agents can use custom tools (APIs, calculations, etc.)
- **LLM Flexibility**: Supports OpenAI, Anthropic, and other LLM providers
- **Ruby Native**: Seamless integration with Rails applications

## Installation

```ruby
# Gemfile
gem 'rcrewai'

# Then run
bundle install
```

## Configuration

### OpenAI Setup
```ruby
# config/initializers/rcrewai.rb
require 'rcrewai'

# Set OpenAI API key
ENV['OPENAI_API_KEY'] = Rails.application.credentials.dig(:openai, :api_key)

# Or directly (not recommended for production)
# OpenAI.configure do |config|
#   config.api_key = "sk-..."
# end
```

### Environment Variables
```bash
# .env
OPENAI_API_KEY=sk-your-api-key-here

# In Rails app
Rails.application.credentials.dig(:openai, :api_key)
```

## Core Concepts

### Agent
An agent is an AI-powered worker with a specific role, goal, and backstory.

```ruby
agent = RCrewAI::Agent.new(
  name: "PlannerAgent",
  role: "Senior Financial Planner",
  goal: "Analyze financial goals and create achievable plans",
  backstory: "You are an experienced financial planner...",
  llm_model: "gpt-4",
  tools: [calculator_tool, search_tool],
  verbose: true
)
```

**Agent Properties**:
- `name`: Unique identifier
- `role`: What the agent does
- `goal`: What the agent aims to achieve
- `backstory`: Provides context and personality
- `llm_model`: OpenAI model (gpt-4, gpt-3.5-turbo, etc.)
- `tools`: List of custom tools the agent can use
- `verbose`: Enable detailed logging

### Task
A task is a specific assignment for an agent to accomplish.

```ruby
task = RCrewAI::Task.new(
  description: "Analyze the financial goal and create a step-by-step plan",
  expected_output: "JSON plan with phases, timelines, and actions",
  agent: agent,
  tools: [calculator_tool],
  async_execution: false
)
```

**Task Properties**:
- `description`: What needs to be done
- `expected_output`: Format/content expected from agent
- `agent`: Which agent performs the task
- `tools`: Tools available for this task (override agent tools)
- `async_execution`: Run task asynchronously
- `human_input`: Require human approval before proceeding

### Crew
A crew is a collection of agents and tasks orchestrated to work together.

```ruby
crew = RCrewAI::Crew.new(
  agents: [planner_agent, executor_agent],
  tasks: [planning_task, execution_task],
  verbose: true,
  manager_llm: OpenAI::Client.new(model: "gpt-4"),
  process: :sequential  # or :hierarchical
)

result = crew.kickoff(inputs: { goal_data: goal_json })
```

**Crew Properties**:
- `agents`: List of agents in the crew
- `tasks`: List of tasks (executed in order)
- `verbose`: Enable detailed logging
- `manager_llm`: LLM for manager agent (coordinates agents)
- `process`: Execution strategy (sequential, hierarchical)

### Tool
A tool is a custom function an agent can call.

```ruby
class SavingsCalculator
  include RCrewAI::Tool
  
  def initialize
    @name = "Savings Calculator"
    @description = "Calculate total savings after monthly contributions"
  end
  
  def execute(initial_amount, monthly_contribution, months)
    initial_amount + (monthly_contribution * months)
  end
end

calculator = SavingsCalculator.new
agent.tools << calculator
```

## Usage in Project

### PlannerAgent Implementation

```ruby
# app/lib/agents/planner_agent.rb
class Agents::PlannerAgent
  def self.create_plan(goal)
    agent = RCrewAI::Agent.new(
      name: "PlannerAgent",
      role: "Senior Financial Planner",
      goal: "Create detailed financial plans with specific phases",
      backstory: "10+ years of financial planning experience...",
      llm_model: "gpt-4",
      tools: [],
      verbose: true
    )
    
    task = RCrewAI::Task.new(
      description: build_prompt(goal),
      expected_output: "JSON plan with phases array",
      agent: agent
    )
    
    crew = RCrewAI::Crew.new(
      agents: [agent],
      tasks: [task],
      verbose: true
    )
    
    result = crew.kickoff(inputs: { goal_data: goal_json })
    JSON.parse(result.output)
  end
  
  private
  
  def self.build_prompt(goal)
    <<~PROMPT
      Analyze this financial goal and create a detailed plan:
      
      Goal: #{goal.name}
      Target: R$ #{goal.target_amount}
      Deadline: #{goal.target_date}
      Current Savings: R$ #{goal.user.current_savings}
      Monthly Income: R$ #{goal.user.monthly_income}
      
      Create 1-5 phases with specific targets and timelines.
      Return as JSON with "phases" array.
    PROMPT
  end
end
```

### Service Integration

```ruby
# app/services/agent_planning_service.rb
class AgentPlanningService
  def call(goal)
    # Log session start
    session = AgentSession.create(
      user_id: goal.user_id,
      agent_type: 'PlannerAgent',
      goal_id: goal.id,
      state: 'processing',
      input_data: { goal_id: goal.id }
    )
    
    # Call agent
    plan_data = Agents::PlannerAgent.create_plan(goal)
    
    # Update goal with plan
    goal.update(plan: plan_data)
    
    # Create milestones from phases
    create_milestones_from_context(goal, plan_data)
    
    # Log completion
    session.update(
      state: 'completed',
      output_data: plan_data
    )
  end
  
  private
  
  def create_milestones_from_context(goal, plan_data)
    phases = plan_data['phases'] || []
    
    phases.each_with_index do |phase, index|
      goal.milestones.create(
        phase: phase['name'],
        target_amount: phase['target_amount'],
        order_number: index + 1,
        status: 'pending'
      )
    end
  end
end
```

### Background Job Integration

```ruby
# app/jobs/agent_planning_job.rb
class AgentPlanningJob < ApplicationJob
  queue_as :default
  
  def perform(goal_id)
    goal = Goal.find(goal_id)
    AgentPlanningService.new.call(goal)
  rescue StandardError => e
    Rails.logger.error("AgentPlanningJob failed: #{e.message}")
    # Retry logic handled by Solid Queue
  end
end
```

### Controller Integration

```ruby
# app/controllers/goals_controller.rb
class GoalsController < ApplicationController
  def create
    @goal = current_user.financial_goals.build(goal_params)
    
    if @goal.save
      # Async: triggers PlannerAgent in background
      AgentPlanningJob.perform_later(@goal.id)
      
      redirect_to @goal, notice: "Goal created! PlannerAgent is analyzing..."
    else
      render :new
    end
  end
  
  def create_plan
    if @goal.plan.present?
      redirect_to goal_path(@goal), alert: "Plan already exists"
      return
    end
    
    # Manual trigger: user clicks "Create Plan with AI" button
    AgentPlanningJob.perform_later(@goal.id)
    
    redirect_to goal_path(@goal), notice: "PlannerAgent is creating your plan..."
  end
end
```

## LLM Models Available

### OpenAI
- `gpt-4` — Most capable, best for complex reasoning (⚠️ More expensive)
- `gpt-4-turbo-preview` — Faster than gpt-4, good for production
- `gpt-3.5-turbo` — Fast and cheap, good for simple tasks
- `gpt-3.5-turbo-16k` — Longer context window

### Configuration
```ruby
# Use specific model for agent
agent = RCrewAI::Agent.new(
  llm_model: "gpt-4-turbo-preview",
  # ...
)

# Or default for all agents
ENV['OPENAI_MODEL_NAME'] = 'gpt-4'
```

## Error Handling

### Common Errors

**Invalid API Key**
```
OpenAI::APIError: Invalid API key
```
Fix: Ensure `OPENAI_API_KEY` is set correctly in environment.

**Rate Limiting**
```
OpenAI::RateLimitError: Rate limit exceeded
```
Fix: Implement retry logic in background job (Solid Queue handles this).

**Invalid JSON Response**
```
JSON::ParserError: unexpected token
```
Fix: Agent didn't return valid JSON. Improve prompt instructions.

**Timeout**
```
OpenAI::TimeoutError: Request timed out
```
Fix: Increase timeout, simplify prompt, or use faster model.

### Retry Strategy
```ruby
# config/initializers/solid_queue.rb
SolidQueue.configure do
  job_class_config SomeJob do
    # Retry up to 3 times with exponential backoff
    max_attempts 3
    wait :exponentially_longer
  end
end
```

## Performance & Cost Optimization

### Token Usage
- **gpt-4**: ~$0.03 per 1K input tokens, ~$0.06 per 1K output tokens
- **gpt-3.5-turbo**: ~$0.001 per 1K input tokens, ~$0.002 per 1K output tokens

### Cost-Saving Strategies
1. **Use gpt-3.5-turbo for simple tasks** (milestone tracking, notifications)
2. **Cache prompts** to avoid redundant API calls
3. **Batch operations** (process multiple goals in one crew)
4. **Set max_tokens** to prevent runaway responses
5. **Use cheaper model for tasks that don't need reasoning** (validation, formatting)

### Performance Tips
1. **Async execution**: All agent calls in background jobs (non-blocking)
2. **Parallel crews**: Multiple agents process in parallel
3. **Tool optimization**: Make custom tools fast and lightweight
4. **Prompt engineering**: Clear, concise prompts reduce token usage

## Testing

### Unit Test with Mock
```ruby
RSpec.describe AgentPlanningService do
  it "creates milestones from plan" do
    goal = Goal.create(name: "Test Goal", target_amount: 10000)
    
    # Mock agent response
    mock_plan = {
      "phases" => [
        { "name" => "Phase 1", "target_amount" => 5000 },
        { "name" => "Phase 2", "target_amount" => 5000 }
      ]
    }
    
    allow(Agents::PlannerAgent).to receive(:create_plan).and_return(mock_plan)
    
    # Test service
    service = AgentPlanningService.new
    service.call(goal)
    
    expect(goal.milestones.count).to eq(2)
    expect(goal.plan).to eq(mock_plan)
  end
end
```

### Integration Test (Live API)
```ruby
# config/rails_helper.rb - skip live tests in CI
if ENV['LIVE_API_TEST']
  RSpec.describe "PlannerAgent Live", :integration do
    it "creates realistic financial plan" do
      goal = Goal.create(
        name: "Emergency Fund",
        target_amount: 3000,
        target_date: 3.months.from_now
      )
      
      plan = Agents::PlannerAgent.create_plan(goal)
      
      expect(plan['phases']).not_to be_empty
      expect(plan['phases'].sum { |p| p['target_amount'] }).to eq(3000)
    end
  end
end

# Run with: LIVE_API_TEST=true bundle exec rspec
```

## Debugging

### Enable Verbose Logging
```ruby
agent = RCrewAI::Agent.new(
  verbose: true,  # Logs all agent reasoning
  # ...
)

crew = RCrewAI::Crew.new(
  verbose: true,  # Logs crew coordination
  # ...
)
```

### Check Rails Logs
```bash
# Follow development logs
tail -f log/development.log | grep "PlannerAgent"
```

### Inspect Agent Response
```ruby
# In rails c
goal = Goal.find(1)
plan = Agents::PlannerAgent.create_plan(goal)
puts JSON.pretty_generate(plan)
```

## Resources

- **CrewAI Docs**: https://docs.crewai.com/
- **rcrewai GitHub**: https://github.com/gkosmo/rcrewai
- **OpenAI API Docs**: https://platform.openai.com/docs/api-reference
- **Ruby OpenAI Gem**: https://github.com/alexrudall/ruby-openai

## Roadmap

### Phase 1: Planning ✅
- [x] PlannerAgent creates goals → milestones
- [x] Async job processing via Solid Queue
- [x] JSONB storage of plans

### Phase 2: Execution 🚧
- [ ] ExecutorAgent breaks milestones into actions
- [ ] Action tracking and completion
- [ ] Progress percentage calculations

### Phase 3: Monitoring 📋
- [ ] MonitorAgent tracks progress
- [ ] Proactive alerts and recommendations
- [ ] Dashboard with progress visualization

### Phase 4+: Advanced Features 🔮
- [ ] Tools: Bank API integration, investment calculators
- [ ] Multi-agent conversations (agents debating strategies)
- [ ] Custom LLM fine-tuning on financial data
- [ ] PDF export of plans
- [ ] Real-time notifications (email, push, SMS)
