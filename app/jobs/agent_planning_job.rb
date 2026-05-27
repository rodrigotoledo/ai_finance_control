class AgentPlanningJob < ApplicationJob
  queue_as :default

  def perform(goal_id)
    goal = FinancialGoal.find(goal_id)
    puts "🤖 Starting PlannerAgent for: #{goal.name}"

    service = AgentPlanningService.new(goal)
    plan = service.create_plan

    puts "✅ PlannerAgent completed planning"
    puts "   Plan saved: #{plan[:monthly_contribution_needed]}/month needed"
  rescue => e
    Rails.logger.error("AgentPlanningJob failed for goal #{goal_id}: #{e.message}")
    raise
  end
end
