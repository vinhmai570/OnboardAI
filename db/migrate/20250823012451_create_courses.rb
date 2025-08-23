class CreateCourses < ActiveRecord::Migration[8.0]
  def change
    create_table :courses do |t|
      t.string :title
      t.text :prompt
      t.json :task_list
      t.json :structure
      t.references :admin, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
