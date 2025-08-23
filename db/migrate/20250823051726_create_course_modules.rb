class CreateCourseModules < ActiveRecord::Migration[8.0]
  def change
    create_table :course_modules do |t|
      t.references :course, null: false, foreign_key: true
      t.string :title
      t.integer :duration_hours
      t.text :description
      t.integer :order_position

      t.timestamps
    end
  end
end
