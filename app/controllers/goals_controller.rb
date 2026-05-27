class GoalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_goal, only: [ :show, :edit, :update, :destroy, :execute_milestone, :complete_milestone, :create_plan ]

  def index
    @goals = current_user.financial_goals.order(created_at: :desc)
  end

  def show
    @milestones = @goal.milestones.ordered
    @goal_progress_amount = calculate_goal_progress_amount
    @progress_percentage = calculate_goal_progress_percentage
    @active_milestone = @milestones.find(&:in_progress?)
    @next_pending_milestone = @active_milestone.present? ? nil : @milestones.find(&:pending?)
  end

  def new
    @goal = current_user.financial_goals.build
  end

  def create
    @goal = current_user.financial_goals.build(goal_params)

    if @goal.save
      # Trigger PlannerAgent to create plan and milestones
      AgentPlanningJob.perform_later(@goal.id)
      redirect_to @goal, notice: "Goal created! PlannerAgent is analyzing your objective..."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @goal.update(goal_params)
      redirect_to @goal, notice: "Goal updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @goal.destroy
    redirect_to goals_url, notice: "Goal deleted successfully"
  end

  def create_plan
    if @goal.plan.present?
      redirect_to goal_path(@goal), alert: "This goal already has a plan"
      return
    end

    AgentPlanningJob.perform_later(@goal.id)
    redirect_to goal_path(@goal), notice: "PlannerAgent is creating your plan... Please refresh in a moment"
  end

  def execute_milestone
    milestone = @goal.milestones.find(params[:milestone_id])
    active_milestone = @goal.milestones.ordered.find(&:in_progress?)
    next_pending_milestone = @goal.milestones.ordered.find(&:pending?)

    if active_milestone.present?
      redirect_to goal_path(@goal), alert: "Finish #{active_milestone.phase} before starting another milestone"
      return
    end

    unless milestone == next_pending_milestone
      redirect_to goal_path(@goal), alert: "Milestones must be executed in order"
      return
    end

    if milestone.pending?
      milestone.update!(status: "in_progress")
      ExecutorAgentJob.perform_later(milestone.id)
      redirect_to goal_path(@goal), notice: "Execution started for #{milestone.phase}"
    else
      redirect_to goal_path(@goal), alert: "Milestone already in progress or completed"
    end
  end

  def complete_milestone
    milestone = @goal.milestones.find(params[:milestone_id])

    unless milestone.in_progress?
      redirect_to goal_path(@goal), alert: "Only an in-progress milestone can be completed"
      return
    end

    ActiveRecord::Base.transaction do
      milestone.update!(
        status: "completed",
        current_amount: milestone.target_amount
      )

      if @goal.milestones.reload.all?(&:completed?)
        @goal.update!(status: "completed")
      elsif @goal.status == "planned"
        @goal.update!(status: "in_progress")
      end
    end

    redirect_to goal_path(@goal), notice: "#{milestone.phase} completed. The next milestone is now available."
  end

  private

  def set_goal
    @goal = current_user.financial_goals.find(params[:id])
  end

  def goal_params
    params.require(:goal).permit(:name, :target_amount, :target_date, :priority, :status)
  end

  def calculate_goal_progress_amount
    progress = @goal.milestones.sum { |milestone| milestone.current_amount.to_f }

    [ progress, @goal.target_amount.to_f ].min
  end

  def calculate_goal_progress_percentage
    return 0 if @goal.target_amount.to_f.zero?

    ((@goal_progress_amount / @goal.target_amount.to_f) * 100).round(1)
  end
end
