class ExecutorAgentService
  def initialize(milestone)
    @milestone = milestone
    @goal = milestone.financial_goal
    @user = @goal.user
  end

  def execute_milestone
    context = build_context
    agent = ExecutorAgent.build(@user)

    task = RCrewAI::Task.new(
      name: "execute_milestone",
      description: create_task_description(context),
      agent: agent,
      expected_output: "Detailed execution plan with action items, timeline, and success metrics"
    )

    crew = RCrewAI::Crew.new("executor_crew_milestone_#{@milestone.id}")
    crew.add_agent(agent)
    crew.add_task(task)

    session = create_session
    session.lock_for_processing!("executor_crew")

    begin
      results = crew.execute
      execution_result = parse_execution(results)

      unless @milestone.reload.completed?
        @milestone.update!(
          status: "in_progress",
          current_amount: execution_result[:simulated_amount]
        )
      end

      session.add_message(
        role: "assistant",
        content: execution_result.to_json,
        metadata: { execution_type: "milestone_execution", milestone_id: @milestone.id, results: results }
      )

      session.complete!
      execution_result
    rescue => e
      session.add_message(
        role: "error",
        content: "Error executing milestone: #{e.message}",
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
      milestone_phase: @milestone.phase,
      target_amount: @milestone.target_amount,
      current_amount: @milestone.current_amount || 0,
      user_income: @user.monthly_income,
      user_savings: @user.current_savings,
      goal_deadline: @goal.target_date,
      milestone_deadline: calculate_milestone_deadline
    }
  end

  def create_task_description(context)
    <<~TEXT
      Execute the following financial milestone:

      Phase: #{context[:milestone_phase]}
      Target: R$ #{context[:target_amount]}
      Current Progress: R$ #{context[:current_amount]} (#{(context[:current_amount] / context[:target_amount] * 100).round}%)

      User Context:
      - Monthly Income: R$ #{context[:user_income]}
      - Current Savings: R$ #{context[:user_savings]}
      - Goal Deadline: #{context[:goal_deadline]}

      Create an execution plan that:
      1. Outlines concrete actions to take
      2. Specifies timing and frequency
      3. Includes success metrics
      4. Identifies potential obstacles
      5. Recommends monthly contribution amount
      6. Explains how this milestone fits the larger goal

      Be specific and provide actionable recommendations.
    TEXT
  end

  def parse_execution(results)
    simulated_progress = @milestone.target_amount * 0.33

    {
      milestone_id: @milestone.id,
      phase: @milestone.phase,
      target_amount: @milestone.target_amount,
      simulated_amount: @milestone.current_amount.to_f + simulated_progress,
      progress_percentage: ((@milestone.current_amount.to_f + simulated_progress) / @milestone.target_amount * 100).round(1),
      status: "in_progress",
      executed_at: Time.current,
      next_review: 1.month.from_now
    }
  end

  def create_session
    @user.agent_sessions.create!(
      conversation_title: "Executing: #{@milestone.phase} (#{@goal.name})"
    )
  end

  def calculate_milestone_deadline
    months_left = @goal.months_remaining
    total_milestones = @goal.milestones.count
    milestone_duration = (months_left / total_milestones).ceil

    (milestone_duration * @milestone.order_number).months.from_now
  end
end
