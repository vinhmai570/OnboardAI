class AddDetailedFieldsToCourseModules < ActiveRecord::Migration[8.0]
  def change
    add_column :course_modules, :detailed_description, :text
    add_column :course_modules, :content_generated, :boolean
  end
end
