class FinancialGoal < ApplicationRecord
  belongs_to :user
  has_many :milestones, dependent: :destroy

  validates :name, presence: true
  validates :target_amount, presence: true, numericality: { greater_than: 0 }
  validates :target_date, presence: true
  validates :status, inclusion: { in: %w[ planned in_progress completed ] }, allow_nil: true

  scope :active, -> { where(status: [ "planned", "in_progress" ]) }
  scope :completed, -> { where(status: "completed") }

  def calculate_monthly_need
    return 0 if user.blank? || user.current_savings.blank?

    months_remaining = ((target_date - Date.today) / 30).ceil
    return 0 if months_remaining <= 0

    needed = target_amount - (user.current_savings || 0)
    (needed / months_remaining).round(2)
  end

  def is_achievable?
    return false if user.blank? || user.monthly_income.blank?

    monthly_need = calculate_monthly_need
    monthly_need <= user.monthly_income * 0.5
  end

  def months_remaining
    ((target_date - Date.today) / 30).ceil
  end
end
