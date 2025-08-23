class CreateQuizResponses < ActiveRecord::Migration[8.0]
  def change
    create_table :quiz_responses do |t|
      t.references :quiz_attempt, null: false, foreign_key: true
      t.references :quiz_question, null: false, foreign_key: true
      t.references :quiz_question_option, null: false, foreign_key: true
      t.text :response_text
      t.boolean :is_correct
      t.integer :points_earned

      t.timestamps
    end
  end
end
