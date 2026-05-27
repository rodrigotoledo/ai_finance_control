class ExecutorAgent
  def self.build(_user)
    RCrewAI::Agent.new(
      name: "financial_executor",
      role: "Financial Execution Specialist",
      goal: "Execute financial plans and track milestone progress with precision",
      backstory: "Disciplined operations expert who breaks down financial plans into actionable steps and monitors execution against targets.",
      tools: [RCrewAI::Tools::WebSearch.new],
      verbose: true
    )
  end
end
