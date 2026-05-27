class SpendingAnalyzer
  def initialize(user)
    @user = user
  end

  def call(months: 3)
    transactions = @user.transactions
      .where("date > ?", months.months.ago)
      .group(:category)
      .sum(:amount)

    insights = []
    total = transactions.values.map(&:to_f).sum

    transactions.each do |category, amount|
      amount_f = amount.to_f
      percentage = (amount_f / total * 100).round(1)

      if percentage > 30
        insights << {
          category: category,
          percentage: percentage,
          suggestion: "Seus gastos com #{category} estão altos (#{percentage}% do total). Considere reduzir."
        }
      elsif percentage < 5
        insights << {
          category: category,
          percentage: percentage,
          suggestion: "Você gasta pouco com #{category} (#{percentage}%). Está equilibrado?"
        }
      end
    end

    insights
  end
end
