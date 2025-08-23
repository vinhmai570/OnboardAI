class AddConversationToCourses < ActiveRecord::Migration[8.0]
  def change
    add_reference :courses, :conversation, null: false, foreign_key: true
  end
end
