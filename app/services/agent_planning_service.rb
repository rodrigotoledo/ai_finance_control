class AgentPlanningService
  def initialize(goal)
    @goal = goal
    @user = goal.user
  end

  def create_plan
    context = build_context
    agent = PlannerAgent.build(@user)

    task = RCrewAI::Task.new(
      name: "create_goal_plan",
      description: create_task_description(context),
      agent: agent,
      expected_output: "A detailed financial plan with steps, timeline, required monthly contribution, and risk assessment"
    )

    crew = RCrewAI::Crew.new("planning_crew_goal_#{@goal.id}")
    crew.add_agent(agent)
    crew.add_task(task)

    session = create_session
    session.lock_for_processing!("planning_crew")

    begin
      results = crew.execute
      plan = parse_plan(results)

      @goal.update!(
        plan: plan,
        status: "planned",
        reasoning: plan[:reasoning]
      )

      session.add_message(
        role: "assistant",
        content: plan.to_json,
        metadata: { plan_type: "goal_plan", goal_id: @goal.id, results: results }
      )

      # Create milestones automatically after plan is created
      create_milestones_from_context(context)

      session.complete!
      plan
    rescue => e
      session.add_message(
        role: "error",
        content: "Error creating plan: #{e.message}",
        metadata: { error: e.class.name }
      )
      session.fail!
      raise
    ensure
      session.unlock!
    end
  end

  private

  def build_context
    {
      goal_name: @goal.name,
      target_amount: @goal.target_amount,
      target_date: @goal.target_date,
      months_available: @goal.months_remaining,
      user_income: @user.monthly_income || 0,
      current_savings: @user.current_savings || 0,
      monthly_need: @goal.calculate_monthly_need,
      is_achievable: @goal.is_achievable?
    }
  end

  def create_task_description(context)
    <<~TEXT
      Create a DETAILED and SPECIFIC financial plan for achieving this goal:

      GOAL DETAILS:
      - Goal: #{context[:goal_name]}
      - Target Amount: R$ #{context[:target_amount].round(2)}
      - Target Date: #{context[:target_date]}
      - Time Available: #{context[:months_available]} months

      USER FINANCIAL SITUATION:
      - Monthly Income: R$ #{context[:user_income]}
      - Current Savings: R$ #{context[:current_savings]}
      - Monthly contribution needed: R$ #{context[:monthly_need]}
      - Status: #{context[:is_achievable] ? "ACHIEVABLE with current income" : "CHALLENGING - will require budget adjustments"}

      REQUIREMENTS FOR EACH PHASE:
      For EACH phase, provide extremely detailed information:
      1. Description: Write 2-3 sentences explaining WHAT will be done and WHY in this phase
      2. Key Actions: List 4-6 SPECIFIC, CONCRETE actions (not generic like "track progress")
         Examples of GOOD actions:
         - "Cut subscription services and save R$200/month"
         - "Move R$300 to high-yield savings account (5.5% APY)"
         - "Negotiate salary increase or seek side income of R$500/month"
         - "Reduce dining out from 15x to 8x per month, save R$250"
         - "Automate monthly transfer of R$400 to investment account"
      3. Focus: Real focus areas like "Emergency Fund Building", "Debt Paydown", "Investment Growth"
      4. Monthly Contribution: Real number that's achievable with user's income
      5. Realistic Timeline: Month X-Y based on actual time available

      IMPORTANT: Return your response ONLY as valid JSON with this exact structure:
      {
        "phases": [
          {
            "name": "Phase name that describes the goal of this phase",
            "description": "Detailed explanation of what will be accomplished (2-3 sentences)",
            "key_actions": ["Specific action 1", "Specific action 2", "Specific action 3", "Specific action 4"],
            "monthly_contribution": numeric_value_in_reais,
            "estimated_savings": numeric_value_for_entire_phase,
            "timeline": "Month X-Y",
            "focus": "Clear focus area description"
          }
        ],
        "overall_strategy": "Detailed explanation of the overall approach",
        "risks": ["Specific risk 1", "Specific risk 2", "Specific risk 3"],
        "success_factors": ["What needs to happen for success 1", "What needs to happen for success 2"]
      }

      CRITICAL INSTRUCTIONS:
      - Be EXTREMELY SPECIFIC with actions - avoid generic phrases like "track progress" or "set up savings"
      - Each action should be something the user can immediately understand and act on
      - Consider the user's income level (#{context[:user_income]}) when suggesting actions
      - If goal is challenging, suggest concrete ways to increase income or reduce expenses
      - Create #{ [ 1, [ context[:months_available] / 3.0, 5 ].min ].max.ceil } phases (1-5 total)
      - Make sure all phases together equal the target amount of R$ #{context[:target_amount].round(2)}
      - Each phase should have realistic, achievable milestones
    TEXT
  end

  def parse_plan(results)
    {
      goal_id: @goal.id,
      goal_name: @goal.name,
      target_amount: @goal.target_amount,
      target_date: @goal.target_date,
      months_available: @goal.months_remaining,
      monthly_contribution_needed: @goal.calculate_monthly_need,
      is_achievable: @goal.is_achievable?,
      reasoning: "Plan created by AI Financial Planner. #{Time.current}",
      created_at: Time.current
    }
  end

  def create_session
    @user.agent_sessions.create!(
      conversation_title: "Planning: #{@goal.name}"
    )
  end

  def create_milestones_from_context(context)
    # Try to get plan data from the goal
    plan_data = @goal.plan || {}
    phases = plan_data["phases"] || []

    # Clear existing milestones
    @goal.milestones.destroy_all

    if phases.any?
      # Create milestones from agent response
      phases.each_with_index do |phase, index|
        @goal.milestones.create!(
          phase: phase["name"],
          target_amount: phase["estimated_savings"] || (context[:target_amount] / phases.count).round(2),
          order_number: index + 1,
          status: "pending",
          details: {
            description: phase["description"],
            key_actions: phase["key_actions"] || [],
            monthly_contribution: phase["monthly_contribution"],
            timeline: phase["timeline"],
            focus: phase["focus"]
          }
        )
      end

      puts "📍 Created #{phases.count} milestones for #{@goal.name}"
    else
      # Fallback: create generic phases if no plan data
      months = context[:months_available]
      target = context[:target_amount]

      num_phases = (months / 3.0).ceil
      num_phases = [ 1, [ num_phases, 5 ].min ].max # Between 1 and 5 phases

      phase_amount = (target / num_phases).round(2)
      phase_names = [
        "Initial Foundation",
        "Building Momentum",
        "Acceleration Phase",
        "Final Stretch",
        "Buffer & Reserve"
      ]

      num_phases.times do |i|
        @goal.milestones.create!(
          phase: phase_names[i],
          target_amount: phase_amount,
          order_number: i + 1,
          status: "pending",
          details: {
            description: "Phase #{i + 1} of your financial goal",
            key_actions: [ "Set up savings plan", "Track progress" ],
            timeline: "Quarter #{i + 1}"
          }
        )
      end

      puts "📍 Created #{num_phases} generic milestones for #{@goal.name}"
    end
  end
end
