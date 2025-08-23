class CreateCourseSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :course_steps do |t|
      t.references :course_module, null: false, foreign_key: true
      t.string :title
      t.text :content
      t.string :step_type
      t.integer :duration_minutes
      t.integer :order_position
      t.text :resources

      t.timestamps
    end
  end
end
