class PlannerAgent
  def self.build(_user)
    RCrewAI::Agent.new(
      name: "financial_planner",
      role: "Financial Planner",
      goal: "Create detailed, actionable financial plans to achieve user goals",
      backstory: "Expert financial planner with 20+ years experience. Creates realistic, step-by-step plans considering risk, timeline, and income constraints.",
      tools: [ RCrewAI::Tools::WebSearch.new ],
      verbose: true
    )
  end
end
