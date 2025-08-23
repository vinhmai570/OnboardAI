class AddFullContentFieldsToCourses < ActiveRecord::Migration[8.0]
  def change
    add_column :courses, :full_content_generated, :boolean
    add_column :courses, :full_content_generated_at, :datetime
  end
end
