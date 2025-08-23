class CreateUserCourseAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :user_course_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true
      t.datetime :assigned_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.references :assigned_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    # Add indexes for performance
    add_index :user_course_assignments, [:user_id, :course_id], unique: true
  end
end
