class CreateQuizAttempts < ActiveRecord::Migration[8.0]
  def change
    create_table :quiz_attempts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :quiz, null: false, foreign_key: true
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :score
      t.integer :total_points
      t.integer :time_spent_minutes
      t.string :status

      t.timestamps
    end
  end
end
