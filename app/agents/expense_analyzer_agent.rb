class ExpenseAnalyzerAgent
  def self.build(_user)
    RCrewAI::Agent.new(
      name: "expense_analyzer",
      role: "Financial Analyst",
      goal: "Analyze user spending patterns and provide actionable insights",
      backstory: "Expert at identifying spending trends and recommending optimization strategies. Uses data to spot wasteful patterns.",
      tools: [ RCrewAI::Tools::WebSearch.new ],
      verbose: true
    )
  end
end

