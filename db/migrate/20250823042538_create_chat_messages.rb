class CreateChatMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :message_type
      t.text :content
      t.text :user_prompt
      t.text :ai_response

      t.timestamps
    end
  end
end
