class CreateQuizzes < ActiveRecord::Migration[8.0]
  def change
    create_table :quizzes do |t|
      t.references :course_step, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.integer :total_points
      t.integer :time_limit_minutes

      t.timestamps
    end
  end
end
