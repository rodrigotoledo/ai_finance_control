# app/tools/goal_tool.rb
class GoalTool
  def self.calculate_needed(params)
    target_amount = params[:target_amount].to_f
    current_savings = params[:current_savings].to_f
    years = params[:years].to_i
    expected_return = params[:expected_return].to_f || 8.0
    
    result = FinancialEngine.monthly_contribution_needed(
      target_amount: target_amount,
      current_savings: current_savings,
      years: years,
      rate_yearly: expected_return
    )
    
    {
      tool: "goal_calculator",
      result: result,
      message: result[:message] || "Você precisa economizar R$#{result[:monthly_contribution]}/mês para atingir sua meta."
    }
  end
end