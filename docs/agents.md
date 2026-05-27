# Agent Documentation

## Overview

Agents are AI-powered decision makers orchestrated by rcrewai. Each agent has a specific role, goal, and set of tasks. Agents interact with OpenAI's GPT-4 LLM to analyze data and produce structured outputs.

## PlannerAgent ✅ Implemented

**Purpose**: Analyze a financial goal and create a structured multi-phase plan.

**Role**: Senior Financial Planner
**Goal**: Analyze financial goals and create achievable, step-by-step plans with specific phases

### Input
```json
{
  "goal_name": "Save for house down payment",
  "target_amount": 15000.00,
  "target_date": "2025-12-31",
  "priority": 4,
  "user_savings": 5000.00,
  "user_monthly_income": 3000.00,
  "months_until_deadline": 8
}
```

### Task: "Create Financial Plan"
**Description**: 
Analyze the provided financial goal and create a detailed, achievable plan. Consider the user's current savings, monthly income, and timeline. Break the goal into 1-5 distinct phases with realistic targets for each phase. Each phase should have a clear name, target amount, and timeline.

**Expected Output**: JSON with `phases` array containing phase objects with `name` and `target_amount`.

### Agent Configuration
```ruby
# app/lib/agents/planner_agent.rb (pseudocode)
PlannerAgent = RCrewAI::Agent.new(
  name: "PlannerAgent",
  role: "Senior Financial Planner",
  goal: "Analyze financial goals and create achievable, step-by-step plans with specific phases",
  backstory: "You are an experienced financial planner with 10+ years of experience helping people achieve their financial goals. You excel at breaking down complex financial objectives into manageable phases and creating realistic timelines.",
  model: "gpt-4",
  tools: []  # Future: add bank API tools
)
```

### Example Output
```json
{
  "phases": [
    {
      "name": "Initial Foundation",
      "description": "Build emergency fund and start consistent savings",
      "target_amount": 5000,
      "timeline": "Months 1-3",
      "key_actions": ["Open savings account", "Set up automatic transfers"]
    },
    {
      "name": "Building Momentum",
      "description": "Accelerate savings with additional side income",
      "target_amount": 5000,
      "timeline": "Months 4-6",
      "key_actions": ["Increase monthly contribution", "Reduce discretionary spending"]
    },
    {
      "name": "Final Push",
      "description": "Close remaining gap with focused savings",
      "target_amount": 5000,
      "timeline": "Months 7-8",
      "key_actions": ["Maximize savings rate", "Verify funds are available"]
    }
  ],
  "summary": "Your goal is achievable with disciplined savings. Focus on consistent monthly contributions.",
  "is_achievable": true
}
```

### Integration
1. **Trigger**: `AgentPlanningJob` (auto-enqueued on goal creation or manual button click)
2. **Service**: `AgentPlanningService#call(goal)` → builds prompt → calls PlannerAgent
3. **Storage**: Plan JSON stored in `goal.plan` (JSONB)
4. **Milestones**: Service converts phases into `Milestone` records
5. **Display**: View renders plan status badge + milestone list

### Response Processing
```ruby
# app/services/agent_planning_service.rb
def call(goal)
  prompt = build_prompt_from_goal(goal)
  response = PlannerAgent.run(prompt)
  plan_data = JSON.parse(response)
  
  goal.update(plan: plan_data)
  create_milestones_from_context(goal, plan_data)
  
  AgentSession.create(
    agent_type: 'PlannerAgent',
    goal_id: goal.id,
    input_data: { goal_id: goal.id },
    output_data: plan_data,
    state: 'completed'
  )
end
```

---

## ExecutorAgent 🚧 In Development

**Purpose**: Break down a milestone into concrete, actionable steps.

**Role**: Action Planning Specialist
**Goal**: Create detailed action plans for financial milestones

### Input
```json
{
  "milestone_phase": "Initial Foundation",
  "milestone_target": 5000.00,
  "user_current_savings": 5000.00,
  "user_monthly_income": 3000.00,
  "timeline": "Months 1-3",
  "user_location": "Brazil"
}
```

### Task: "Create Action Plan"
**Description**:
Break down the milestone into specific, actionable steps. Each step should be concrete, measurable, and time-bound. Consider the user's constraints and provide alternatives where applicable. Include risk mitigation strategies.

**Expected Output**: JSON with `steps` array containing action objects with `action`, `timeline`, `priority`, `tools_needed`.

### Example Output (Target)
```json
{
  "steps": [
    {
      "order": 1,
      "action": "Open high-yield savings account",
      "timeline": "Week 1",
      "priority": "critical",
      "tools_needed": ["Bank account opening form"],
      "success_criteria": "Account created and verified"
    },
    {
      "order": 2,
      "action": "Set up automatic transfer of R$ 625 on paydays",
      "timeline": "Week 2",
      "priority": "critical",
      "tools_needed": ["Online banking portal"],
      "success_criteria": "First automatic transfer completed"
    },
    {
      "order": 3,
      "action": "Track spending and identify areas to cut",
      "timeline": "Week 3-4",
      "priority": "high",
      "tools_needed": ["Expense tracker app", "Budget spreadsheet"],
      "success_criteria": "Documented spending patterns and cut R$ 200/month"
    }
  ],
  "risks": [
    "Job loss → Recommended: Keep emergency fund separate",
    "Unexpected expenses → Recommended: Build 1-month buffer first"
  ],
  "total_estimated_time": "12 weeks",
  "success_rate": "85% based on similar goals"
}
```

### Agent Configuration (Target)
```ruby
# app/lib/agents/executor_agent.rb (pseudocode)
ExecutorAgent = RCrewAI::Agent.new(
  name: "ExecutorAgent",
  role: "Action Planning Specialist",
  goal: "Create detailed, achievable action plans for financial milestones",
  backstory: "You are a project manager with expertise in breaking down complex tasks into manageable steps. You understand human psychology and design plans that are realistic and motivating.",
  model: "gpt-4",
  tools: []  # Future: add investment calculator, tax tools
)
```

### Integration (Target)
1. **Trigger**: `ExecutorAgentJob` (enqueued when user clicks "Execute Milestone")
2. **Service**: `ExecutorAgentService#call(milestone)` → builds prompt → calls ExecutorAgent
3. **Storage**: Action plan stored in milestone metadata or separate `MilestoneAction` records
4. **Display**: New section in goal view shows action steps with checkboxes
5. **Tracking**: User marks steps complete manually (future: auto-tracking)

---

## MonitorAgent 📋 Planned

**Purpose**: Track milestone progress and provide proactive recommendations.

**Role**: Financial Progress Monitor
**Goal**: Monitor goal progress and provide timely recommendations and alerts

### Responsibilities
- **Tracking**: Check milestone completion percentage periodically
- **Alerts**: Notify user if progress is lagging behind target
- **Recommendations**: Suggest adjustments if goal is off-track
- **Celebration**: Congratulate user on milestone completion
- **Trending**: Identify patterns (e.g., savings accelerating, expenses increasing)

### Input
```json
{
  "goal_id": 1,
  "milestone_phases": [...],
  "current_progress": 45,
  "target_progress": 60,
  "days_remaining": 45,
  "user_monthly_savings": 750
}
```

### Output
```json
{
  "status": "on_track" | "lagging" | "ahead",
  "progress_vs_target": -15,
  "recommendations": [
    "You're 15% behind target. To catch up, increase monthly savings by R$ 100.",
    "Consider freelance work to boost income by R$ 500/month."
  ],
  "alerts": [],
  "achievements": ["Completed Initial Foundation phase!"],
  "next_milestone_eta": "2025-09-15"
}
```

### Integration (Target)
1. **Trigger**: Scheduled job daily (Solid Queue with cron)
2. **Service**: `MonitorAgentService#call(goal)` → builds prompt → calls MonitorAgent
3. **Storage**: Progress data stored in AgentSession for auditoria
4. **Notifications**: Email or push notification to user
5. **Display**: Dashboard shows progress status and recommendations

---

## Agent Crew Configuration

Each agent is part of a crew that coordinates multiple agents and tasks:

```ruby
# Pseudocode structure
PlannerCrew = RCrewAI::Crew.new(
  agents: [PlannerAgent],
  tasks: [
    RCrewAI::Task.new(
      description: "Analyze financial goal and create phases",
      expected_output: "JSON plan with phases",
      agent: PlannerAgent
    )
  ],
  verbose: true,
  manager_llm: OpenAI::Client.new(model: "gpt-4")
)

response = PlannerCrew.kickoff(inputs: { goal_data: goal_json })
```

---

## LLM Configuration

- **Model**: OpenAI GPT-4 (superior reasoning for financial planning)
- **Temperature**: 0.3 (low randomness, consistent output)
- **Max Tokens**: 2000 (enough for detailed plans)
- **Retry Logic**: Exponential backoff on rate limit / timeout

---

## Tools (Future)

### Planned Tools for Agents
- **Investment Calculator**: Compare savings vs. investment returns
- **Tax Calculator**: Estimate tax impact on savings
- **Bank API Integration**: Real-time account balance, transaction history
- **Currency Converter**: Handle multi-currency goals
- **Economic Data**: Inflation rates, interest rates, cost of living adjustments

Example:
```ruby
class SavingsCalculator < RCrewAI::Tool
  def execute(amount, monthly_contribution, months)
    amount + (monthly_contribution * months)
  end
end

PlannerAgent.tools << SavingsCalculator
```

---

## Error Handling & Retries

- **Agent Timeout**: Retry up to 3 times with exponential backoff
- **API Rate Limit**: Queue job and retry after 60 seconds
- **Invalid JSON**: Log error in AgentSession, notify user
- **Network Error**: Store in database, retry on next background job cycle

---

## Monitoring & Auditoria

All agent executions logged in AgentSession:
- Input data (goal/milestone details)
- Agent response (plan/actions)
- Execution time
- Errors (if any)
- User who triggered it

```ruby
AgentSession.create(
  user_id: goal.user_id,
  agent_type: 'PlannerAgent',
  goal_id: goal.id,
  state: 'completed',
  input_data: { goal_id: goal.id, target_amount: goal.target_amount },
  output_data: { phases: [...] },
  created_at: Time.current
)
```

---

## Testing Agents

### Local Testing (rails c)
```ruby
goal = Goal.find(1)
service = AgentPlanningService.new
service.call(goal)
# Check goal.plan and goal.milestones
```

### Mock Testing (Unit Tests)
```ruby
mock_response = { phases: [...] }.to_json
allow(PlannerAgent).to receive(:run).and_return(mock_response)
service.call(goal)
expect(goal.milestones.count).to eq(3)
```

### Integration Testing (Feature Tests)
1. Navigate to /goals/new
2. Fill form and submit
3. Background job processes
4. Refresh page
5. Verify milestones appear with correct phases
