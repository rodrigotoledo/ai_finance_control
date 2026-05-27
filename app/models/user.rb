class User < ApplicationRecord
  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable
  has_many :transactions, dependent: :destroy
  has_many :financial_goals, dependent: :destroy
  has_many :agent_sessions, dependent: :destroy
  has_many :agent_messages, through: :agent_sessions
  
  # Validações
  validates :monthly_income, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :current_savings, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  
  # Métodos para o agente financeiro
  
  # Retorna a sessão ativa do agente (ou cria uma nova)
  def active_agent_session
    agent_sessions.where(status: ['idle', 'processing', 'waiting_for_tool'])
                  .order(created_at: :desc)
                  .first || agent_sessions.create
  end
  
  # Cria uma nova sessão e encerra as antigas (opcional)
  def start_new_agent_session
    agent_sessions.where(status: 'processing').each(&:complete!)
    agent_sessions.create
  end
  
  # Histórico completo de conversas
  def agent_conversation_history(limit = 10)
    agent_sessions.includes(:messages)
                  .order(created_at: :desc)
                  .limit(limit)
  end
  
  # Resumo financeiro para contexto do agente
  def financial_context
    {
      monthly_income: monthly_income || 0,
      current_savings: current_savings || 0,
      total_transactions_last_3_months: transactions.where('date > ?', 3.months.ago).sum(:amount),
      active_goals: financial_goals.active.map { |g| { name: g.name, target: g.target_amount } }
    }
  end
  
  # Estatísticas rápidas
  def financial_summary
    {
      income: monthly_income,
      savings: current_savings,
      monthly_expenses_avg: transactions.where('date > ?', 3.months.ago)
                                        .group_by_month(:date)
                                        .sum(:amount)
                                        .values
                                        .average,
      savings_rate: monthly_income.present? && monthly_income > 0 ? 
                    (current_savings / monthly_income * 100).round(2) : 0
    }
  end
end
