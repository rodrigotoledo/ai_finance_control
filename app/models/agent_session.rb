class AgentSession < ApplicationRecord
  include AASM

  belongs_to :user
  has_many :messages, class_name: "AgentMessage", dependent: :destroy

  aasm column: :status do
    state :idle, initial: true
    state :processing
    state :waiting_for_tool
    state :waiting_for_user_input
    state :completed
    state :failed

    event :process do
      transitions from: :idle, to: :processing
      transitions from: :waiting_for_tool, to: :processing
      transitions from: :waiting_for_user_input, to: :processing
    end

    event :pause_for_tool do
      transitions from: :processing, to: :waiting_for_tool
    end

    event :pause_for_input do
      transitions from: :processing, to: :waiting_for_user_input
    end

    event :complete do
      transitions from: :processing, to: :completed
    end

    event :fail do
      transitions from: [ :processing, :waiting_for_tool, :waiting_for_user_input ], to: :failed
    end

    event :reset do
      transitions from: [ :completed, :failed ], to: :idle
    end

    after_all_transitions do
      update(last_activity_at: Time.current)
    end
  end

  before_validation :generate_session_token, on: :create
  before_save :update_last_activity

  scope :active, -> { where(status: [ "idle", "processing", "waiting_for_tool" ]) }
  scope :stalled, -> { where("last_activity_at < ?", 30.minutes.ago).where(status: [ "processing", "waiting_for_tool" ]) }

  def add_message(role:, content:, metadata: {}, tool_name: nil)
    messages.create!(
      user: user,
      role: role,
      content: content,
      metadata: metadata,
      tool_name: tool_name
    )

    update!(
      messages_log: messages.order(:created_at).limit(50).map do |msg|
        {
          role: msg.role,
          content: msg.content.truncate(200),
          timestamp: msg.created_at,
          tool_name: msg.tool_name
        }
      end
    )
  end

  def lock_for_processing!(job_id)
    update!(
      locked_at: Time.current,
      locked_by: job_id
    )
    process!
  end

  def unlock!
    update!(locked_at: nil, locked_by: nil)
    reset! if completed? || failed?
  end

  private

  def generate_session_token
    self.session_token ||= SecureRandom.alphanumeric(24)
  end

  def update_last_activity
    self.last_activity_at = Time.current if status_changed?
  end
end
