# Claude, Cursor, Antigravity, GPT, OMC - Definitions

This project can be extended to support multiple LLM providers and agent frameworks. Below are suggested .md definition templates for each:

## Claude (Anthropic)
- **Provider:** Anthropic
- **Use:** Substitute for GPT-4 in agent orchestration (Planner, Executor, Monitor)
- **Integration:** Via API key and Anthropic SDK
- **Strengths:** Long context, safe outputs, good for reasoning
- **Example:**
  - `ClaudeAgent` can be used as a drop-in for PlannerAgent or ExecutorAgent

## Cursor
- **Provider:** Cursor (AI code assistant)
- **Use:** Code generation, refactoring, and code review tasks
- **Integration:** Via API or VS Code extension
- **Strengths:** Fast code suggestions, context-aware
- **Example:**
  - `CursorAgent` can be used for codebase refactoring tasks

## Antigravity
- **Provider:** Hypothetical/Custom LLM
- **Use:** Experimental agent for creative or out-of-the-box financial strategies
- **Integration:** Custom API
- **Strengths:** Creative, non-traditional solutions
- **Example:**
  - `AntigravityAgent` for brainstorming unconventional savings plans

## GPT (OpenAI)
- **Provider:** OpenAI
- **Use:** Main LLM for PlannerAgent, ExecutorAgent, MonitorAgent
- **Integration:** OpenAI API key, rcrewai gem
- **Strengths:** High accuracy, reliable, widely supported
- **Example:**
  - `PlannerAgent` and `ExecutorAgent` use GPT-4 by default

## OMC (Open Model Context)
- **Provider:** Open Model Context (open-source LLM orchestration)
- **Use:** Plug-and-play for any open-source LLM
- **Integration:** OMC API or local deployment
- **Strengths:** Customizable, privacy, cost-effective
- **Example:**
  - `OMCAgent` for on-premise or private deployments

---

# Agents, Tasks, and Plans

## Agents
- **Definition:** Autonomous entities specialized in a domain (planning, execution, monitoring)
- **Examples:** PlannerAgent, ExecutorAgent, ExpenseAnalyzerAgent, MonitorAgent
- **Location:** app/agents/

## Tasks
- **Definition:** Discrete units of work assigned to agents (e.g., "create plan", "execute milestone")
- **Examples:** CreatePlanTask, ExecuteMilestoneTask
- **Location:** app/services/ or app/jobs/

## Plans
- **Definition:** Structured output from agents, usually in JSON, representing a financial roadmap
- **Examples:** Goal plan (with milestones, actions, timelines)
- **Location:** Stored in DB (goal.plan), can be documented in PLANNER_AGENT_PLAN.md

---

# VS Code Integration
- Use these .md files to document and improve agent orchestration, LLM selection, and task definitions.
- Place each definition in its own .md file for clarity if needed.
- Example: `AGENTS.md`, `TASKS.md`, `PLANS.md`, `LLM_PROVIDERS.md`
