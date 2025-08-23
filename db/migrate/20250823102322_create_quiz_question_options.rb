class CreateQuizQuestionOptions < ActiveRecord::Migration[8.0]
  def change
    create_table :quiz_question_options do |t|
      t.references :quiz_question, null: false, foreign_key: true
      t.text :option_text
      t.boolean :is_correct
      t.integer :order_position

      t.timestamps
    end
  end
end
