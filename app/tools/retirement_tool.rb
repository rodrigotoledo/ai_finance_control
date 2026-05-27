# app/tools/retirement_tool.rb
class RetirementTool
  def self.calculate(params)
    current_age = params[:current_age].to_i
    retirement_age = params[:retirement_age].to_i || 65
    current_savings = params[:current_savings].to_f
    monthly_contribution = params[:monthly_contribution].to_f
    expected_return = params[:expected_return].to_f || 8.0 # 8% ao ano
    
    projection = FinancialEngine.retirement_projection(
      current_age: current_age,
      retirement_age: retirement_age,
      current_savings: current_savings,
      monthly_contribution: monthly_contribution,
      rate_yearly: expected_return
    )
    
    {
      tool: "retirement_calculator",
      result: projection,
      message: "Com aportes de R$#{monthly_contribution}/mês, você terá R$#{projection[:final_amount]} aos #{retirement_age} anos."
    }
  end
end