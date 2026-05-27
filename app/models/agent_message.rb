class AgentMessage < ApplicationRecord
  belongs_to :agent_session
  belongs_to :user
end
