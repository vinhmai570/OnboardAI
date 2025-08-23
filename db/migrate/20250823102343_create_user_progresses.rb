class CreateUserProgresses < ActiveRecord::Migration[8.0]
  def change
    create_table :user_progresses do |t|
      t.references :user, null: false, foreign_key: true
      t.references :course_step, null: false, foreign_key: true
      t.string :status
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :score

      t.timestamps
    end
  end
end
