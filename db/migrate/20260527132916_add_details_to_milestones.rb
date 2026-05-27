class AddDetailsToMilestones < ActiveRecord::Migration[8.1]
  def change
    add_column :milestones, :details, :json
  end
end
