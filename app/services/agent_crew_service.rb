class AgentCrewService
  def initialize(user, session_type = "expense_analysis")
    @user = user
    @session_type = session_type
    @session = create_or_reuse_session
  end

  def execute_expense_analysis
    spending_analyzer = SpendingAnalyzer.new(@user)
    insights = spending_analyzer.call(months: 3)

    agent = ExpenseAnalyzerAgent.build(@user)

    # Create task
    task = RCrewAI::Task.new(
      name: "analyze_spending",
      description: "Analyze the user's spending patterns: #{format_insights(insights)}. Provide actionable recommendations to reduce unnecessary spending.",
      agent: agent,
      expected_output: "A detailed analysis with spending insights and concrete recommendations"
    )

    # Create and execute crew
    crew = RCrewAI::Crew.new("expense_analysis_crew_#{@session.id}")
    crew.add_agent(agent)
    crew.add_task(task)

    @session.lock_for_processing!("expense_crew")

    begin
      results = crew.execute

      # Save results to session
      @session.add_message(
        role: "assistant",
        content: results.to_s,
        metadata: { crew_type: "expense_analysis", results: results }
      )

      @session.complete!
      results
    rescue => e
      @session.add_message(
        role: "error",
        content: "Error during expense analysis: #{e.message}",
        metadata: { error: e.class.name }
      )
      @session.fail!
      raise
    ensure
      @session.unlock!
    end
  end

  private

  def create_or_reuse_session
    existing = @user.agent_sessions.where(status: [ "idle", "processing" ]).first
    return existing if existing

    @user.agent_sessions.create!(
      conversation_title: "Expense Analysis"
    )
  end

  def format_insights(insights)
    insights.map { |i| "#{i[:category]}: #{i[:percentage]}% - #{i[:suggestion]}" }.join("\n")
  end
end
