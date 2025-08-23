class AddDetailedFieldsToCourseSteps < ActiveRecord::Migration[8.0]
  def change
    add_column :course_steps, :detailed_content, :text
    add_column :course_steps, :content_generated, :boolean
  end
end
