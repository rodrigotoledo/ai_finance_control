# RCrewAI Integration Plan

## Current Architecture
- **AgentSession**: AASM state machine managing workflow (idle → processing → completed/failed)
- **AgentMessage**: Stores all messages with role, content, tool_name, metadata
- **AgentTool**: Registry of available tools

## Integration Strategy

### Phase 1: Setup ✅
- [x] Add rcrewai gem
- [x] Add openai gem
- [x] Configure rcrewai initializer
- [ ] Verify bundle install completes

### Phase 2: Create First Agent (POC)
**Goal**: Build expense analyzer agent
- Create `ExpenseAnalyzer` agent class
- Define tools (expense_summary, anomaly_detection)
- Test with rcrewai crew

### Phase 3: Persistence Layer
Create `AgentCrewService` to bridge rcrewai + DB:
```
AgentSession
  ↓
AgentCrewService (coordinator)
  ↓
RCrewAI::Crew (orchestrator)
  ↓
RCrewAI::Agent(s) + RCrewAI::Task(s)
  ↓
AgentMessage (persisted)
```

**Key mappings**:
- `Crew` → `AgentSession`
- `Agent` → record in agent_tools
- `Task` → implicit in messages_log
- `Messages` → AgentMessage rows

### Phase 4: Expand
Gradually add more agents:
- InvestmentAdvisor
- BudgetPlanner
- GoalTracker

## Design Decisions

### Why keep agent_sessions/messages?
1. Audit trail & compliance
2. User can review full history
3. Replay/debug capability
4. Analytics on agent behavior

### Separation of Concerns
- `RCrewAI::Crew` = task orchestration (in-memory)
- `AgentSession` = workflow state + persistence
- `AgentCrewService` = the adapter between them
