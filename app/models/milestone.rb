class Milestone < ApplicationRecord
  belongs_to :financial_goal

  validates :phase, presence: true
  validates :target_amount, presence: true, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: %w[ pending in_progress completed ] }, allow_nil: true
  validates :order_number, presence: true

  scope :ordered, -> { order(:order_number) }
  scope :pending, -> { where(status: "pending") }
  scope :completed, -> { where(status: "completed") }

  def progress_percentage
    return 0 if target_amount.zero?

    ((current_amount || 0) / target_amount * 100).round(1)
  end

  def remaining_amount
    target_amount - (current_amount || 0)
  end

  def completion_percentage
    "#{progress_percentage.round}%"
  end

  def pending?
    status.nil? || status == "pending"
  end

  def in_progress?
    status == "in_progress"
  end

  def completed?
    status == "completed"
  end
end
