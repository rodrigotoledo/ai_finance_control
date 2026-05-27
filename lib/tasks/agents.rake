namespace :agents do
  desc "Test ExpenseAnalyzer agent with first user"
  task test_expense_analyzer: :environment do
    user = User.first
    if user.nil?
      puts "❌ No users found. Create a user first."
      exit 1
    end

    puts "🚀 Starting ExpenseAnalyzer for user: #{user.email}"

    service = AgentCrewService.new(user)
    results = service.execute_expense_analysis

    puts "✅ Analysis complete!"
    puts results
  end

  desc "List all agent sessions for a user"
  task list_sessions: :environment do
    user = User.first
    if user.nil?
      puts "❌ No users found."
      exit 1
    end

    sessions = user.agent_sessions
    puts "📋 Agent Sessions for #{user.email}:"
    sessions.each do |session|
      puts "  - #{session.conversation_title} (#{session.status}) - #{session.created_at}"
      puts "    Messages: #{session.messages.count}"
    end
  end
end

namespace :goals do
  desc "Create a test user and goal for planning"
  task setup_test: :environment do
    user = User.find_or_create_by!(email: "planner_test@test.com") do |u|
      u.name = "Planner Test User"
      u.monthly_income = 5000.0
      u.current_savings = 50000.0
      u.password = "password123"
      u.password_confirmation = "password123"
    end

    goal = user.financial_goals.create!(
      name: "Comprar um carro",
      target_amount: 100000.0,
      target_date: 2.years.from_now,
      priority: 1,
      status: "planned"
    )

    puts "✅ Test setup complete!"
    puts "  User: #{user.email} (Income: R$ #{user.monthly_income}, Savings: R$ #{user.current_savings})"
    puts "  Goal: #{goal.name} (R$ #{goal.target_amount}, due: #{goal.target_date})"
  end

  desc "Plan a financial goal"
  task :plan, [ :goal_id ] => :environment do |_task, args|
    goal_id = args[:goal_id] || FinancialGoal.first&.id

    if goal_id.nil?
      puts "❌ No goal found. Run 'rails goals:setup_test' first."
      exit 1
    end

    goal = FinancialGoal.find(goal_id)
    puts "📊 Planning goal: #{goal.name}"
    puts "   Target: R$ #{goal.target_amount} by #{goal.target_date}"

    service = AgentPlanningService.new(goal)
    plan = service.create_plan

    puts "✅ Plan created!"
    puts "\n📋 Plan Details:"
    plan.each do |key, value|
      puts "  #{key}: #{value}"
    end
  end

  desc "Create demo milestones for a goal"
  task :create_milestones, [ :goal_id ] => :environment do |_task, args|
    goal_id = args[:goal_id] || FinancialGoal.first&.id

    if goal_id.nil?
      puts "❌ No goal found."
      exit 1
    end

    goal = FinancialGoal.find(goal_id)
    puts "📍 Creating milestones for: #{goal.name}"

    # Clear existing milestones
    goal.milestones.destroy_all

    # Create demo milestones (quarterly phases)
    milestones = [
      { phase: "Initial Savings", target_amount: goal.target_amount * 0.25 },
      { phase: "Accumulation", target_amount: goal.target_amount * 0.25 },
      { phase: "Growth Phase", target_amount: goal.target_amount * 0.25 },
      { phase: "Final Push", target_amount: goal.target_amount * 0.25 }
    ]

    milestones.each_with_index do |attrs, index|
      milestone = goal.milestones.create!(
        phase: attrs[:phase],
        target_amount: attrs[:target_amount],
        order_number: index + 1,
        status: "pending"
      )
      puts "  ✅ Created: #{milestone.phase} (R$ #{milestone.target_amount})"
    end

    puts "✅ Milestones created successfully!"
  end

  desc "List all goals and their plans"
  task list_plans: :environment do
    goals = FinancialGoal.includes(:user).all
    puts "📋 All Financial Goals:"
    goals.each do |goal|
      puts "\n  Goal: #{goal.name}"
      puts "    User: #{goal.user&.email}"
      puts "    Target: R$ #{goal.target_amount} by #{goal.target_date}"
      puts "    Status: #{goal.status}"
      puts "    Has plan: #{goal.plan.present? ? '✅' : '❌'}"
    end
  end
end
