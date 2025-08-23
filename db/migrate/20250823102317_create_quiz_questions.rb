class CreateQuizQuestions < ActiveRecord::Migration[8.0]
  def change
    create_table :quiz_questions do |t|
      t.references :quiz, null: false, foreign_key: true
      t.text :question_text
      t.string :question_type
      t.integer :points
      t.integer :order_position
      t.text :explanation

      t.timestamps
    end
  end
end
