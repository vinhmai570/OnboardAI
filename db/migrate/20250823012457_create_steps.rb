class CreateSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :steps do |t|
      t.references :course, null: false, foreign_key: true
      t.integer :order
      t.text :content
      t.json :quiz_questions

      t.timestamps
    end
  end
end
