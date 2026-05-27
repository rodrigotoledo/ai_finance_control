# app/services/financial_engine.rb
class FinancialEngine
  def self.compound_interest(principal:, monthly_contribution:, rate_yearly:, years:)
    monthly_rate = rate_yearly / 12 / 100
    months = years * 12
    
    future_value = principal
    
    months.times do
      future_value = future_value * (1 + monthly_rate) + monthly_contribution
    end
    
    {
      final_amount: future_value.round(2),
      total_contributed: (principal + monthly_contribution * months).round(2),
      total_interest: (future_value - principal - monthly_contribution * months).round(2)
    }
  end
  
  def self.retirement_projection(current_age:, retirement_age:, current_savings:, monthly_contribution:, rate_yearly:)
    years_to_retirement = retirement_age - current_age
    
    compound_interest(
      principal: current_savings,
      monthly_contribution: monthly_contribution,
      rate_yearly: rate_yearly,
      years: years_to_retirement
    )
  end
  
  def self.monthly_contribution_needed(target_amount:, current_savings:, years:, rate_yearly:)
    monthly_rate = rate_yearly / 12 / 100
    months = years * 12
    
    # Fórmula do valor futuro: FV = PV*(1+r)^n + PMT*((1+r)^n - 1)/r
    future_value_factor = (1 + monthly_rate) ** months
    pv_component = current_savings * future_value_factor
    
    needed_from_contributions = target_amount - pv_component
    
    if needed_from_contributions <= 0
      { monthly_contribution: 0, message: "Você já atingiu seu objetivo!" }
    else
      # PMT = FV * r / ((1+r)^n - 1)
      pmt = needed_from_contributions * monthly_rate / (future_value_factor - 1)
      { monthly_contribution: pmt.round(2), message: nil }
    end
  end
end