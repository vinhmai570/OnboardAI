class Conversation < ApplicationRecord
  belongs_to :user
  has_many :chat_messages, dependent: :destroy
  has_many :courses, dependent: :destroy

  validates :title, presence: true
  validates :session_id, presence: true

  scope :recent, -> { order(updated_at: :desc) }

  def last_message_at
    chat_messages.maximum(:created_at) || created_at
  end

  def message_count
    chat_messages.count
  end

  def generate_title_from_prompt(prompt)
    # Generate a title from the first user prompt
    title = prompt.strip.truncate(50, omission: '...')
    title = title.gsub(/@\w+/, '').strip # Remove document references
    title.present? ? title : "Course Generation #{Time.current.strftime('%m/%d %H:%M')}"
  end
end
