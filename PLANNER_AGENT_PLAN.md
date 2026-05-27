# PlannerAgent Implementation Plan

## 1. Database: Enhance FinancialGoal
```ruby
add_column :financial_goals, :user_id, :references  # Link to user
add_column :financial_goals, :status, :string, default: "planned"  # planned → in_progress → completed
add_column :financial_goals, :plan, :json  # Structured plan from agent
add_column :financial_goals, :reasoning, :text  # Why this plan works
```

Status flow: planned → in_progress → completed

## 2. Create PlannerAgent
**Input**: FinancialGoal + User financial context
**Output**: Detailed plan with:
- Breakdown of steps
- Monthly contribution needed
- Timeline
- Risk assessment
- Reasoning

**Uses**: FinancialEngine for calculations

## 3. Create AgentPlanningService
Coordinates:
- Load goal + user context
- Create PlannerAgent
- Create planning task (RCrewAI)
- Save results to DB
- Create AgentSession record

## 4. Test with Rake Task
```bash
rails goals:plan_expense[goal_id]
```

## Example Flow:
```
Goal: "Buy a house"
Amount: R$ 500,000
Timeline: Dec 2027 (20 months)
User Income: R$ 5,000/month
Current Savings: R$ 50,000

↓ PlannerAgent analyzes

Plan:
- Step 1: Emergency fund (3 months) → R$ 15,000
- Step 2: Aggressive saving → R$ 22,500/month
- Step 3: Investment in conservative assets
- Timeline: achievable in 19 months
- Monthly commitment: R$ 22,500
```
