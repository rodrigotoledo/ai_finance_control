class ExecutorAgentJob < ApplicationJob
  queue_as :default

  def perform(milestone_id)
    milestone = Milestone.find(milestone_id)
    ExecutorAgentService.new(milestone).execute_milestone
  rescue => e
    Rails.logger.error("ExecutorAgentJob failed for milestone #{milestone_id}: #{e.message}")
    raise
  end
end
