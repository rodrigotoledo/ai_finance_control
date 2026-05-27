class FinancialGoalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_goal, only: [ :show, :edit, :update, :destroy ]

  def index
    @financial_goals = current_user.financial_goals.order(created_at: :desc)
  end

  def show
    @milestones = @goal.milestones.ordered
  end

  def new
    @goal = current_user.financial_goals.build
  end

  def create
    @goal = current_user.financial_goals.build(goal_params)

    if @goal.save
      # Trigger PlannerAgent to create plan and milestones
      AgentPlanningJob.perform_later(@goal.id)
      redirect_to financial_goal_path(@goal), notice: "Goal created! PlannerAgent is analyzing your objective..."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @goal.update(goal_params)
      redirect_to financial_goal_path(@goal), notice: "Goal updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @goal.destroy
    redirect_to financial_goals_url, notice: "Goal deleted successfully"
  end

  def create_plan
    if @goal.plan.present?
      redirect_to financial_goal_path(@goal), alert: "This goal already has a plan"
      return
    end

    AgentPlanningJob.perform_later(@goal.id)
    redirect_to financial_goal_path(@goal), notice: "PlannerAgent is creating your plan... Please refresh in a moment"
  end

  private

  def set_goal
    @goal = current_user.financial_goals.find(params[:id])
  end

  def goal_params
    params.require(:financial_goal).permit(:name, :target_amount, :target_date, :priority, :status)
  end
end
